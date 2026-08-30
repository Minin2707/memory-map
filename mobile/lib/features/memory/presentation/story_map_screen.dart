import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/media/presentation/widgets/authenticated_media_image.dart';
import 'package:memory_map/features/map/config/map_source_configuration.dart';
import 'package:memory_map/features/map/domain/map_camera.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';
import 'package:memory_map/features/memory/application/story_map_projection.dart';
import 'package:memory_map/features/memory/application/story_map_notifier.dart';
import 'package:memory_map/features/memory/application/story_map_state.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_state.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/presentation/memory_failure_message.dart';
import 'package:memory_map/features/memory/presentation/story_map_camera.dart';
import 'package:memory_map/features/memory/presentation/story_map_photo_marker_map.dart';
import 'package:memory_map/features/memory/presentation/story_map_selected_memory.dart';
import 'package:memory_map/features/memory/presentation/widgets/memory_map_preview_card.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';
import 'package:memory_map/features/story/application/story_details_state.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
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
    this.initialSelectedMemoryId,
    this.sourceConfiguration = MapSources.openFreeMapLiberty,
    this.mapBuilder = _defaultStoryMapBuilder,
    super.key,
  });

  final String storyId;
  final VoidCallback? onBack;
  final ValueChanged<Memory>? onMemorySelected;
  final String? initialSelectedMemoryId;
  final MapSourceConfiguration sourceConfiguration;
  final StoryMapBuilder mapBuilder;

  @override
  ConsumerState<StoryMapScreen> createState() => _StoryMapScreenState();
}

class _StoryMapScreenState extends ConsumerState<StoryMapScreen> {
  bool _initialCameraApplied = false;
  bool _initialSelectionApplied = false;
  int _cameraRevision = 0;
  MapCameraCommand? _cameraCommand;

  @override
  void didUpdateWidget(StoryMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storyId != widget.storyId) {
      _initialCameraApplied = false;
      _initialSelectionApplied = false;
      _cameraCommand = null;
    }
    if (oldWidget.initialSelectedMemoryId != widget.initialSelectedMemoryId) {
      _initialSelectionApplied = false;
      _initialCameraApplied = false;
      _cameraCommand = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapValue = ref.watch(storyMapProvider(widget.storyId));
    final memoriesValue = ref.watch(storyMemoriesProvider(widget.storyId));
    final storyValue = ref.watch(storyDetailsProvider(widget.storyId));
    final usableState = _usableState(mapValue);
    _applyInitialSelection(usableState);
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: _StoryMapHeader(
                  storyValue: storyValue,
                  onBack: widget.onBack,
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
                  onShowAll: usableState == null
                      ? null
                      : () {
                          _showAll(usableState.markers);
                        },
                  onRefresh: usableState == null || usableState.isRefreshing
                      ? null
                      : _refreshMemories,
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

  MemoryReadModel? _selectedMemory(
    AsyncValue<StoryMemoriesState> memoriesValue,
    StoryMapState? state,
  ) {
    if (state == null) {
      return null;
    }

    return findSelectedStoryMapMemoryReadModel(
      memoriesValue.asData?.value.memoryReadModels ??
          const <MemoryReadModel>[],
      state.selectedMarkerId,
    );
  }

  MapCameraCommand? _cameraCommandFor(StoryMapState? state) {
    if (state == null) {
      return _cameraCommand;
    }

    if (!_initialCameraApplied) {
      _initialCameraApplied = true;
      _cameraCommand = _newCameraCommandFor(
        state.markers,
        preferredMarkerId:
            state.selectedMarkerId ?? widget.initialSelectedMemoryId,
      );
    }

    return _cameraCommand;
  }

  MapCameraCommand _newCameraCommandFor(
    List<MapMarker> markers, {
    String? preferredMarkerId,
  }) {
    _cameraRevision += 1;
    final preferredMarker = _markerById(markers, preferredMarkerId);
    return MapCameraCommand(
      revision: _cameraRevision,
      target: preferredMarker == null
          ? storyMapCameraTargetForMarkers(markers)
          : MapCameraTarget.point(
              coordinate: preferredMarker.coordinate,
              zoom: storyMapSingleMarkerZoom,
            ),
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

  void _applyInitialSelection(StoryMapState? state) {
    final initialSelectedMemoryId = widget.initialSelectedMemoryId;
    if (_initialSelectionApplied ||
        state == null ||
        initialSelectedMemoryId == null ||
        state.selectedMarkerId == initialSelectedMemoryId ||
        _markerById(state.markers, initialSelectedMemoryId) == null) {
      return;
    }

    _initialSelectionApplied = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _selectMarker(initialSelectedMemoryId);
    });
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

MapMarker? _markerById(List<MapMarker> markers, String? markerId) {
  if (markerId == null) {
    return null;
  }

  for (final marker in markers) {
    if (marker.id == markerId) {
      return marker;
    }
  }

  return null;
}

final class StoryMapViewConfiguration {
  StoryMapViewConfiguration({
    required List<MapMarker> markers,
    List<StoryMapMarkerPresentation>? markerPresentations,
    required this.sourceConfiguration,
    required this.onMarkerSelected,
    this.selectedMarkerId,
    this.cameraCommand,
  })  : markers = List<MapMarker>.unmodifiable(markers),
        markerPresentations = List<StoryMapMarkerPresentation>.unmodifiable(
          markerPresentations ??
              markers.map((marker) {
                return StoryMapMarkerPresentation(marker: marker);
              }),
        );

  final List<MapMarker> markers;
  final List<StoryMapMarkerPresentation> markerPresentations;
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
    required this.onShowAll,
    required this.onRefresh,
    required this.onRetryLoad,
    required this.onRetryRefresh,
  });

  final AsyncValue<StoryMapState> mapValue;
  final MapSourceConfiguration sourceConfiguration;
  final StoryMapBuilder mapBuilder;
  final MapCameraCommand? cameraCommand;
  final MemoryReadModel? selectedMemory;
  final ValueChanged<Memory>? onMemorySelected;
  final VoidCallback onPreviewClose;
  final ValueChanged<String> onMarkerSelected;
  final VoidCallback? onShowAll;
  final VoidCallback? onRefresh;
  final VoidCallback onRetryLoad;
  final VoidCallback onRetryRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (mapValue.isLoading) {
      return const _StoryMapLoadingView();
    }

    if (mapValue.hasError) {
      return DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFEFF3F7)),
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
      return DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFEFF3F7)),
        child: Center(
          child: _StoryMapErrorView(
            title: l10n.storyMapLoadFailureTitle,
            message: memoryFailureMessage(l10n, loadFailure),
            onRetry: onRetryLoad,
          ),
        ),
      );
    }

    return DecoratedBox(
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
                markerPresentations: state.markerPresentations,
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
          Positioned(
            top: 12,
            right: 12,
            child: _StoryMapControls(
              isRefreshing: state.isRefreshing,
              onShowAll: onShowAll,
              onRefresh: onRefresh,
            ),
          ),
          if (state.refreshFailure != null)
            Positioned(
              top: 14,
              left: 14,
              right: 78,
              child: _RefreshFailureBanner(
                message: memoryFailureMessage(
                  l10n,
                  state.refreshFailure!,
                ),
                onRetry: onRetryRefresh,
              ),
            ),
          if (!state.hasMarkers)
            const Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: _StoryMapEmptyState(),
            ),
          if (selectedMemory != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: MemoryMapPreviewCard(
                    memory: selectedMemory!.memory,
                    previewPhoto: selectedMemory!.previewPhoto,
                    onTap: onMemorySelected,
                    onClose: onPreviewClose,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StoryMapHeader extends StatelessWidget {
  const _StoryMapHeader({
    required this.storyValue,
    required this.onBack,
  });

  final AsyncValue<StoryDetailsState> storyValue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final storyState = storyValue.asData?.value;
    final userStory = storyState?.userStory;
    final loading = storyValue.isLoading && userStory == null;

    return Row(
      key: const ValueKey('story-map.header'),
      children: [
        _StoryMapBackButton(onBack: onBack),
        const SizedBox(width: 10),
        if (loading)
          const _HeaderThumbnailSkeleton()
        else
          _StoryMapHeaderThumbnail(userStory: userStory),
        const SizedBox(width: 12),
        Expanded(
          child: loading
              ? const _StoryMapHeaderTextSkeleton()
              : _StoryMapHeaderText(userStory: userStory),
        ),
      ],
    );
  }
}

class _StoryMapBackButton extends StatelessWidget {
  const _StoryMapBackButton({
    required this.onBack,
  });

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: const Color(0x180F172A),
      child: IconButton(
        key: const ValueKey('story-map.back-action'),
        onPressed: onBack,
        tooltip: AppLocalizations.of(context).storyMapBackLabel,
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 21),
        color: const Color(0xFF111827),
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _StoryMapHeaderThumbnail extends StatelessWidget {
  const _StoryMapHeaderThumbnail({
    required this.userStory,
  });

  final UserStory? userStory;

  @override
  Widget build(BuildContext context) {
    final preview = userStory?.previewPhoto;
    final fallback = _StoryMapHeaderThumbnailFallback(userStory: userStory);

    if (preview == null) {
      return fallback;
    }

    return Semantics(
      image: true,
      label: AppLocalizations.of(context).storyThumbnailLabel,
      child: ExcludeSemantics(
        child: ClipOval(
          child: SizedBox.square(
            dimension: 54,
            child: AuthenticatedMediaPathImage(
              key: ValueKey(
                'story-map.header-thumbnail.${preview.thumbnailPath}',
              ),
              thumbnailPath: preview.thumbnailPath,
              fit: BoxFit.cover,
              placeholder: fallback,
              errorBuilder: (_) => fallback,
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryMapHeaderThumbnailFallback extends StatelessWidget {
  const _StoryMapHeaderThumbnailFallback({
    required this.userStory,
  });

  final UserStory? userStory;

  @override
  Widget build(BuildContext context) {
    final title = userStory?.story.title ?? '';

    return ExcludeSemantics(
      child: Container(
        key: const ValueKey('story-map.header.no-photo'),
        width: 54,
        height: 54,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFE6EA),
              Color(0xFFFFF6D9),
              Color(0xFFEAF7FF),
            ],
          ),
        ),
        child: Center(
          child: title.trim().isEmpty
              ? const Icon(
                  Icons.map_outlined,
                  color: Color(0xFFFF5D72),
                  size: 24,
                )
              : Text(
                  _initials(title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFF5D72),
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
        ),
      ),
    );
  }
}

class _StoryMapHeaderText extends StatelessWidget {
  const _StoryMapHeaderText({
    required this.userStory,
  });

  final UserStory? userStory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final story = userStory;

    if (story == null) {
      return Text(
        l10n.storyMapPageTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 22,
          height: 1.1,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          story.story.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 22,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.storyMemoryCount(story.memoryCount),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF7B8494),
            fontSize: 15,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _HeaderThumbnailSkeleton extends StatelessWidget {
  const _HeaderThumbnailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const _SkeletonBlock(
      key: ValueKey('story-map.header.thumbnail-loading'),
      width: 54,
      height: 54,
      radius: 999,
    );
  }
}

class _StoryMapHeaderTextSkeleton extends StatelessWidget {
  const _StoryMapHeaderTextSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SkeletonBlock(width: 154, height: 22, radius: 9),
        SizedBox(height: 8),
        _SkeletonBlock(width: 96, height: 14, radius: 7),
      ],
    );
  }
}

class _StoryMapControls extends StatelessWidget {
  const _StoryMapControls({
    required this.isRefreshing,
    required this.onShowAll,
    required this.onRefresh,
  });

  final bool isRefreshing;
  final VoidCallback? onShowAll;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StoryMapControlButton(
          buttonKey: const ValueKey('story-map.show-all-action'),
          tooltip: l10n.storyMapShowAllAction,
          icon: Icons.center_focus_strong_rounded,
          onPressed: onShowAll,
        ),
        const SizedBox(height: 8),
        _StoryMapControlButton(
          buttonKey: const ValueKey('story-map.refresh-action'),
          tooltip: l10n.storyMapRefreshAction,
          icon: Icons.refresh_rounded,
          onPressed: isRefreshing ? null : onRefresh,
        ),
      ],
    );
  }
}

class _StoryMapControlButton extends StatelessWidget {
  const _StoryMapControlButton({
    required this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final Key buttonKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 7,
      shadowColor: const Color(0x1A0F172A),
      child: IconButton(
        key: buttonKey,
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 20),
        color: const Color(0xFF111827),
        disabledColor: const Color(0xFFB8C0CC),
        constraints: const BoxConstraints.tightFor(width: 42, height: 42),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _StoryMapLoadingView extends StatelessWidget {
  const _StoryMapLoadingView();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      key: ValueKey('story-map.loading-view'),
      decoration: BoxDecoration(color: Color(0xFFEFF3F7)),
      child: Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Color(0xFFFF5D72),
          ),
        ),
      ),
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
  const _StoryMapEmptyState();

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
    this.width,
    this.height,
    this.radius = 24,
    super.key,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
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

String _initials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) {
    return '';
  }

  return words.take(2).map((word) => word.substring(0, 1)).join();
}

Widget _defaultStoryMapBuilder(
  BuildContext context,
  StoryMapViewConfiguration configuration,
) {
  return StoryMapPhotoMarkerMap(
    markerPresentations: configuration.markerPresentations,
    sourceConfiguration: configuration.sourceConfiguration,
    selectedMarkerId: configuration.selectedMarkerId,
    onMarkerSelected: configuration.onMarkerSelected,
    cameraCommand: configuration.cameraCommand,
  );
}
