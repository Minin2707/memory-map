import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/map/config/map_source_configuration.dart';
import 'package:memory_map/features/map/domain/map_camera.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';
import 'package:memory_map/features/map/presentation/widgets/maplibre_marker_map.dart';
import 'package:memory_map/features/memory/application/story_map_notifier.dart';
import 'package:memory_map/features/memory/application/story_map_state.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_state.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/presentation/memory_failure_message.dart';
import 'package:memory_map/features/memory/presentation/story_map_camera.dart';
import 'package:memory_map/features/memory/presentation/story_map_selected_memory.dart';
import 'package:memory_map/features/memory/presentation/widgets/memory_map_preview_card.dart';
import 'package:memory_map/l10n/app_localizations.dart';

typedef StoryMapBuilder = Widget Function(
  BuildContext context,
  StoryMapViewConfiguration configuration,
);

class StoryMapScreen extends ConsumerStatefulWidget {
  const StoryMapScreen({
    required this.storyId,
    this.onBack,
    this.onMemorySelected,
    this.sourceConfiguration = MapSources.openFreeMapLiberty,
    this.mapBuilder = _defaultStoryMapBuilder,
    super.key,
  });

  final String storyId;
  final VoidCallback? onBack;
  final ValueChanged<Memory>? onMemorySelected;
  final MapSourceConfiguration sourceConfiguration;
  final StoryMapBuilder mapBuilder;

  @override
  ConsumerState<StoryMapScreen> createState() => _StoryMapScreenState();
}

class _StoryMapScreenState extends ConsumerState<StoryMapScreen> {
  bool _initialCameraApplied = false;
  int _cameraRevision = 0;
  MapCameraCommand? _cameraCommand;

  @override
  void didUpdateWidget(StoryMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storyId != widget.storyId) {
      _initialCameraApplied = false;
      _cameraCommand = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapValue = ref.watch(storyMapProvider(widget.storyId));
    final memoriesValue = ref.watch(storyMemoriesProvider(widget.storyId));
    final usableState = _usableState(mapValue);
    final selectedMemory = _selectedMemory(memoriesValue, usableState);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          widget.onBack?.call();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _StoryMapAppBar(
                  isRefreshing: usableState?.isRefreshing ?? false,
                  onBack: widget.onBack,
                  onShowAll: usableState == null
                      ? null
                      : () {
                          _showAll(usableState.markers);
                        },
                  onRefresh: usableState == null || usableState.isRefreshing
                      ? null
                      : _refreshMemories,
                ),
              ),
              Expanded(
                child: _StoryMapBody(
                  mapValue: mapValue,
                  sourceConfiguration: widget.sourceConfiguration,
                  mapBuilder: widget.mapBuilder,
                  cameraCommand: _cameraCommandFor(usableState),
                  selectedMemory: selectedMemory,
                  onMemorySelected: widget.onMemorySelected,
                  onPreviewClose: _clearSelection,
                  onMarkerSelected: _selectMarker,
                  onRetryLoad: _retryLoad,
                  onRetryRefresh: _refreshMemories,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  StoryMapState? _usableState(AsyncValue<StoryMapState> value) {
    final state = value.asData?.value;
    if (state == null || state.hasLoadFailure) {
      return null;
    }

    return state;
  }

  Memory? _selectedMemory(
    AsyncValue<StoryMemoriesState> memoriesValue,
    StoryMapState? state,
  ) {
    if (state == null) {
      return null;
    }

    return findSelectedStoryMapMemory(
      memoriesValue.asData?.value.memories ?? const <Memory>[],
      state.selectedMarkerId,
    );
  }

  MapCameraCommand? _cameraCommandFor(StoryMapState? state) {
    if (state == null) {
      return _cameraCommand;
    }

    if (!_initialCameraApplied) {
      _initialCameraApplied = true;
      _cameraCommand = _newCameraCommandFor(state.markers);
    }

    return _cameraCommand;
  }

  MapCameraCommand _newCameraCommandFor(List<MapMarker> markers) {
    _cameraRevision += 1;
    return MapCameraCommand(
      revision: _cameraRevision,
      target: storyMapCameraTargetForMarkers(markers),
    );
  }

  void _showAll(List<MapMarker> markers) {
    setState(() {
      _initialCameraApplied = true;
      _cameraCommand = _newCameraCommandFor(markers);
    });
  }

  void _selectMarker(String markerId) {
    ref
        .read(storyMapSelectionProvider(widget.storyId).notifier)
        .selectMarker(markerId);
  }

  void _clearSelection() {
    ref
        .read(storyMapSelectionProvider(widget.storyId).notifier)
        .clearSelection();
  }

  void _retryLoad() {
    unawaited(
      ref.read(storyMemoriesProvider(widget.storyId).notifier).retryLoad(),
    );
  }

  void _refreshMemories() {
    unawaited(
      ref
          .read(storyMemoriesProvider(widget.storyId).notifier)
          .refreshMemories(),
    );
  }
}

final class StoryMapViewConfiguration {
  StoryMapViewConfiguration({
    required List<MapMarker> markers,
    required this.sourceConfiguration,
    required this.onMarkerSelected,
    this.selectedMarkerId,
    this.cameraCommand,
  }) : markers = List<MapMarker>.unmodifiable(markers);

  final List<MapMarker> markers;
  final MapSourceConfiguration sourceConfiguration;
  final String? selectedMarkerId;
  final ValueChanged<String> onMarkerSelected;
  final MapCameraCommand? cameraCommand;

  @override
  String toString() {
    return 'StoryMapViewConfiguration(markerCount: ${markers.length}, '
        'hasSelection: ${selectedMarkerId != null}, '
        'hasCameraCommand: ${cameraCommand != null})';
  }
}

class _StoryMapBody extends StatelessWidget {
  const _StoryMapBody({
    required this.mapValue,
    required this.sourceConfiguration,
    required this.mapBuilder,
    required this.cameraCommand,
    required this.selectedMemory,
    required this.onMemorySelected,
    required this.onPreviewClose,
    required this.onMarkerSelected,
    required this.onRetryLoad,
    required this.onRetryRefresh,
  });

  final AsyncValue<StoryMapState> mapValue;
  final MapSourceConfiguration sourceConfiguration;
  final StoryMapBuilder mapBuilder;
  final MapCameraCommand? cameraCommand;
  final Memory? selectedMemory;
  final ValueChanged<Memory>? onMemorySelected;
  final VoidCallback onPreviewClose;
  final ValueChanged<String> onMarkerSelected;
  final VoidCallback onRetryLoad;
  final VoidCallback onRetryRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (mapValue.isLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: _StoryMapLoadingView(),
      );
    }

    if (mapValue.hasError) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Center(
          child: _StoryMapErrorView(
            title: l10n.unexpectedErrorTitle,
            message: l10n.memoryFailureUnknown,
            onRetry: onRetryLoad,
          ),
        ),
      );
    }

    final state = mapValue.asData?.value;
    if (state == null) {
      return const SizedBox.shrink();
    }

    final loadFailure = state.loadFailure;
    if (loadFailure != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Center(
          child: _StoryMapErrorView(
            title: l10n.storyMapLoadFailureTitle,
            message: memoryFailureMessage(l10n, loadFailure),
            onRetry: onRetryLoad,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFEFF3F7)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              KeyedSubtree(
                key: const ValueKey('story-map.map-view'),
                child: mapBuilder(
                  context,
                  StoryMapViewConfiguration(
                    markers: state.markers,
                    sourceConfiguration: sourceConfiguration,
                    selectedMarkerId: state.selectedMarkerId,
                    onMarkerSelected: onMarkerSelected,
                    cameraCommand: cameraCommand,
                  ),
                ),
              ),
              if (state.isRefreshing)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: Color(0xFFFF5D72),
                    backgroundColor: Color(0xFFFFE6EA),
                  ),
                ),
              if (state.refreshFailure != null)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _RefreshFailureBanner(
                    message: memoryFailureMessage(
                      l10n,
                      state.refreshFailure!,
                    ),
                    onRetry: onRetryRefresh,
                  ),
                ),
              if (!state.hasMarkers)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _StoryMapEmptyState(),
                ),
              if (selectedMemory != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: MemoryMapPreviewCard(
                        memory: selectedMemory!,
                        onTap: onMemorySelected,
                        onClose: onPreviewClose,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryMapAppBar extends StatelessWidget {
  const _StoryMapAppBar({
    required this.isRefreshing,
    required this.onBack,
    required this.onShowAll,
    required this.onRefresh,
  });

  final bool isRefreshing;
  final VoidCallback? onBack;
  final VoidCallback? onShowAll;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        IconButton(
          key: const ValueKey('story-map.back-action'),
          onPressed: onBack,
          tooltip: l10n.storyMapBackLabel,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        Expanded(
          child: Text(
            l10n.storyMapPageTitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('story-map.show-all-action'),
          onPressed: onShowAll,
          tooltip: l10n.storyMapShowAllAction,
          icon: const Icon(Icons.center_focus_strong_rounded),
        ),
        IconButton(
          key: const ValueKey('story-map.refresh-action'),
          onPressed: isRefreshing ? null : onRefresh,
          tooltip: l10n.storyMapRefreshAction,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _StoryMapLoadingView extends StatelessWidget {
  const _StoryMapLoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('story-map.loading-view'),
      children: const [
        _SkeletonBlock(height: 56),
        SizedBox(height: 18),
        Expanded(child: _SkeletonBlock()),
      ],
    );
  }
}

class _StoryMapErrorView extends StatelessWidget {
  const _StoryMapErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _StoryMapCardShell(
      key: const ValueKey('story-map.error-view'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE6EA),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFFFF5D72),
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            key: const ValueKey('story-map.error.retry-action'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

class _StoryMapEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _StoryMapCardShell(
      key: const ValueKey('story-map.empty-state'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE6EA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.map_outlined,
              color: Color(0xFFFF5D72),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.storyMapEmptyTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.storyMapEmptyBody,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshFailureBanner extends StatelessWidget {
  const _RefreshFailureBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('story-map.refresh.failure-banner'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7F8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFD6DC)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFFF5D72),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${l10n.storyMapRefreshFailureTitle}. $message',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('story-map.refresh.retry-action'),
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryMapCardShell extends StatelessWidget {
  const _StoryMapCardShell({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            offset: Offset(0, 12),
            blurRadius: 28,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    this.height,
  });

  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            offset: Offset(0, 10),
            blurRadius: 24,
          ),
        ],
      ),
    );
  }
}

Widget _defaultStoryMapBuilder(
  BuildContext context,
  StoryMapViewConfiguration configuration,
) {
  return MapLibreMarkerMap(
    markers: configuration.markers,
    sourceConfiguration: configuration.sourceConfiguration,
    selectedMarkerId: configuration.selectedMarkerId,
    onMarkerSelected: configuration.onMarkerSelected,
    cameraCommand: configuration.cameraCommand,
  );
}
