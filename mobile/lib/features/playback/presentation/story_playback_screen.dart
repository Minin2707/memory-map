import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/media/presentation/widgets/authenticated_media_image.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/presentation/memory_date_format.dart';
import 'package:memory_map/features/playback/application/story_playback_provider.dart';
import 'package:memory_map/features/playback/domain/playback_camera_command.dart';
import 'package:memory_map/features/playback/domain/playback_phase.dart';
import 'package:memory_map/features/playback/domain/playback_status.dart';
import 'package:memory_map/features/playback/domain/story_playback_state.dart';
import 'package:memory_map/features/playback/presentation/map/playback_map_view.dart';
import 'package:memory_map/features/playback/presentation/map/playback_marker_projection.dart';
import 'package:memory_map/features/playback/presentation/map/playback_route_projection.dart';
import 'package:memory_map/l10n/app_localizations.dart';

typedef PlaybackMapBuilder = Widget Function(
  BuildContext context,
  PlaybackMapPresentation presentation,
);

final class PlaybackMapPresentation {
  const PlaybackMapPresentation({
    required this.markers,
    required this.route,
    required this.currentIndex,
    required this.cameraCommand,
    required this.onCameraArrived,
    required this.onCameraFailed,
  });

  final List<PlaybackMapMarker> markers;
  final PlaybackRouteProjection route;
  final int? currentIndex;
  final PlaybackCameraCommand? cameraCommand;
  final ValueChanged<int> onCameraArrived;
  final ValueChanged<int> onCameraFailed;

  @override
  String toString() {
    return 'PlaybackMapPresentation(markerCount: ${markers.length}, '
        'routePointCount: ${route.coordinates.length}, '
        'currentIndex: $currentIndex, '
        'hasCameraCommand: ${cameraCommand != null})';
  }
}

class StoryPlaybackScreen extends ConsumerWidget {
  const StoryPlaybackScreen({
    required this.storyId,
    required this.onClose,
    this.storyTitle,
    this.mapBuilder,
    super.key,
  });

  final String storyId;
  final String? storyTitle;
  final VoidCallback onClose;
  final PlaybackMapBuilder? mapBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(storyPlaybackProvider(storyId));
    final notifier = ref.read(storyPlaybackProvider(storyId).notifier);

    if (state.isLoading) {
      return _PlaybackFrame(
        key: const ValueKey('story-playback.loading'),
        title: storyTitle ?? l10n.playbackTitle,
        onClose: onClose,
        child: const _PlaybackLoading(),
      );
    }

    if (state.hasLoadFailure) {
      return _PlaybackFrame(
        key: const ValueKey('story-playback.load-failure'),
        title: storyTitle ?? l10n.playbackTitle,
        onClose: onClose,
        child: _PlaybackMessage(
          title: l10n.playbackLoadFailureTitle,
          body: l10n.playbackLoadFailureBody,
          primaryAction: _PlaybackTextAction(
            buttonKey: const ValueKey('story-playback.retry-load'),
            label: l10n.playbackRetryAction,
            icon: Icons.refresh_rounded,
            onPressed: notifier.retry,
          ),
          secondaryAction: _PlaybackTextAction(
            buttonKey: const ValueKey('story-playback.close-load-failure'),
            label: l10n.playbackCloseAction,
            icon: Icons.close_rounded,
            onPressed: onClose,
          ),
        ),
      );
    }

    final playback = state.requirePlayback;
    return _PlaybackSessionView(
      playback: playback,
      hasCameraFailure: state.hasCameraFailure,
      title: storyTitle ?? l10n.playbackTitle,
      mapBuilder: mapBuilder,
      onCameraArrived: notifier.cameraArrived,
      onCameraFailed: notifier.cameraFailed,
      onRetryCamera: notifier.retryCamera,
      onPrevious: notifier.previous,
      onNext: notifier.next,
      onPause: notifier.pause,
      onResume: notifier.resume,
      onReplay: notifier.replay,
      onClose: onClose,
    );
  }
}

class _PlaybackSessionView extends StatelessWidget {
  const _PlaybackSessionView({
    required this.playback,
    required this.hasCameraFailure,
    required this.title,
    required this.mapBuilder,
    required this.onCameraArrived,
    required this.onCameraFailed,
    required this.onRetryCamera,
    required this.onPrevious,
    required this.onNext,
    required this.onPause,
    required this.onResume,
    required this.onReplay,
    required this.onClose,
  });

  final StoryPlaybackState playback;
  final bool hasCameraFailure;
  final String title;
  final PlaybackMapBuilder? mapBuilder;
  final ValueChanged<int> onCameraArrived;
  final ValueChanged<int> onCameraFailed;
  final VoidCallback onRetryCamera;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onReplay;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final markers = playbackMarkersFromSnapshot(playback.snapshot);
    final route = playbackRouteFromSnapshot(playback.snapshot);
    final mapPresentation = PlaybackMapPresentation(
      markers: markers,
      route: route,
      currentIndex: playback.currentIndex,
      cameraCommand: playback.cameraCommand,
      onCameraArrived: onCameraArrived,
      onCameraFailed: onCameraFailed,
    );

    return Scaffold(
      key: const ValueKey('story-playback.screen'),
      backgroundColor: const Color(0xFF101820),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildMap(context, mapPresentation),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x990B1220),
                  Color(0x220B1220),
                  Color(0xBB0B1220),
                ],
                stops: [0, 0.48, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  _PlaybackTopBar(
                    title: title,
                    progressLabel: _progressLabel(playback),
                    progressValue: _progressValue(playback),
                    onClose: onClose,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SingleChildScrollView(
                        child: _bottomOverlay(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomOverlay(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (playback.isIdle) {
      return _PlaybackMessage(
        key: const ValueKey('story-playback.empty'),
        title: l10n.playbackEmptyTitle,
        body: l10n.playbackEmptyBody,
        primaryAction: _PlaybackTextAction(
          buttonKey: const ValueKey('story-playback.close-empty'),
          label: l10n.playbackCloseAction,
          icon: Icons.close_rounded,
          onPressed: onClose,
        ),
      );
    }

    if (hasCameraFailure) {
      return _PlaybackMessage(
        key: const ValueKey('story-playback.camera-failure'),
        title: l10n.playbackCameraFailureTitle,
        body: l10n.playbackCameraFailureBody,
        primaryAction: _PlaybackTextAction(
          buttonKey: const ValueKey('story-playback.retry-camera'),
          label: l10n.playbackRetryAction,
          icon: Icons.refresh_rounded,
          onPressed: onRetryCamera,
        ),
        secondaryAction: _PlaybackTextAction(
          buttonKey: const ValueKey('story-playback.close-camera'),
          label: l10n.playbackCloseAction,
          icon: Icons.close_rounded,
          onPressed: onClose,
        ),
      );
    }

    if (playback.isFinished) {
      return _PlaybackMessage(
        key: const ValueKey('story-playback.finished'),
        title: l10n.playbackFinishedTitle,
        body: l10n.playbackFinishedBody,
        primaryAction: _PlaybackTextAction(
          buttonKey: const ValueKey('story-playback.replay'),
          label: l10n.playbackReplayAction,
          icon: Icons.replay_rounded,
          onPressed: onReplay,
        ),
        secondaryAction: _PlaybackTextAction(
          buttonKey: const ValueKey('story-playback.close-finished'),
          label: l10n.playbackCloseAction,
          icon: Icons.close_rounded,
          onPressed: onClose,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (playback.phase == PlaybackPhase.presenting &&
            playback.currentMemory != null)
          _CurrentMemoryCard(readModel: playback.currentMemory!),
        const SizedBox(height: 14),
        _PlaybackControls(
          status: playback.status,
          onPrevious: onPrevious,
          onNext: onNext,
          onPause: onPause,
          onResume: onResume,
        ),
      ],
    );
  }

  Widget _buildMap(
    BuildContext context,
    PlaybackMapPresentation presentation,
  ) {
    final builder = mapBuilder;
    if (builder != null) {
      return builder(context, presentation);
    }

    return PlaybackMapView(
      key: const ValueKey('story-playback.map'),
      markers: presentation.markers,
      route: presentation.route,
      currentIndex: presentation.currentIndex,
      cameraCommand: presentation.cameraCommand,
      onCameraArrived: presentation.onCameraArrived,
      onCameraFailed: presentation.onCameraFailed,
    );
  }
}

class _PlaybackFrame extends StatelessWidget {
  const _PlaybackFrame({
    required this.title,
    required this.onClose,
    required this.child,
    super.key,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101820),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF182232),
              Color(0xFF101820),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                _PlaybackTopBar(
                  title: title,
                  progressLabel: null,
                  progressValue: null,
                  onClose: onClose,
                ),
                Expanded(child: Center(child: child)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaybackTopBar extends StatelessWidget {
  const _PlaybackTopBar({
    required this.title,
    required this.progressLabel,
    required this.progressValue,
    required this.onClose,
  });

  final String title;
  final String? progressLabel;
  final double? progressValue;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progressLabel = this.progressLabel;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD9FFFFFF),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF182232),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  if (progressLabel != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              key: const ValueKey('story-playback.progress'),
                              value: progressValue,
                              minHeight: 6,
                              color: const Color(0xFFFF5D72),
                              backgroundColor: const Color(0xFFE4E7EC),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          progressLabel,
                          key: const ValueKey(
                            'story-playback.progress-label',
                          ),
                          style: const TextStyle(
                            color: Color(0xFF475467),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              key: const ValueKey('story-playback.close'),
              tooltip: l10n.playbackCloseAction,
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
              color: const Color(0xFF182232),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.status,
    required this.onPrevious,
    required this.onNext,
    required this.onPause,
    required this.onResume,
  });

  final PlaybackStatus status;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPause;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPaused = status == PlaybackStatus.paused;

    return DecoratedBox(
      key: const ValueKey('story-playback.controls'),
      decoration: BoxDecoration(
        color: const Color(0xEFFFFFFF),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PlaybackIconButton(
              buttonKey: const ValueKey('story-playback.previous'),
              tooltip: l10n.playbackPreviousAction,
              icon: Icons.skip_previous_rounded,
              onPressed: onPrevious,
            ),
            const SizedBox(width: 8),
            _PlaybackIconButton(
              buttonKey: ValueKey(
                isPaused ? 'story-playback.resume' : 'story-playback.pause',
              ),
              tooltip: isPaused
                  ? l10n.playbackResumeAction
                  : l10n.playbackPauseAction,
              icon: isPaused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              emphasized: true,
              onPressed: isPaused ? onResume : onPause,
            ),
            const SizedBox(width: 8),
            _PlaybackIconButton(
              buttonKey: const ValueKey('story-playback.next'),
              tooltip: l10n.playbackNextAction,
              icon: Icons.skip_next_rounded,
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackIconButton extends StatelessWidget {
  const _PlaybackIconButton({
    required this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
  });

  final Key buttonKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: emphasized ? 56 : 48,
      child: IconButton.filled(
        key: buttonKey,
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: emphasized
              ? const Color(0xFFFF5D72)
              : const Color(0xFFF2F4F7),
          foregroundColor:
              emphasized ? Colors.white : const Color(0xFF344054),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _CurrentMemoryCard extends StatelessWidget {
  const _CurrentMemoryCard({
    required this.readModel,
  });

  final MemoryReadModel readModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final memory = readModel.memory;
    final placeName = memory.placeName?.trim();
    final description = memory.description;

    return ConstrainedBox(
      key: const ValueKey('story-playback.memory-card'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.58,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xF7FFFFFF),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _MemoryPhotoPanel(preview: readModel.previewPhoto),
              const SizedBox(height: 14),
              _MemoryMetaRow(
                icon: Icons.calendar_today_rounded,
                text: formatMemoryDate(l10n, memory.eventDate),
              ),
              if (placeName != null && placeName.isNotEmpty) ...[
                const SizedBox(height: 8),
                _MemoryMetaRow(
                  icon: Icons.place_rounded,
                  text: placeName,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                memory.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF182232),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  height: 1.15,
                ),
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF475467),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    height: 1.42,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryPhotoPanel extends StatelessWidget {
  const _MemoryPhotoPanel({
    required this.preview,
  });

  final MemoryPhotoPreview? preview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preview = this.preview;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: preview == null
            ? _PhotoFallback(
                key: const ValueKey('story-playback.no-photo'),
                label: l10n.playbackNoPhotoTitle,
                icon: Icons.photo_outlined,
              )
            : Semantics(
                label: l10n.playbackMemoryPhotoLabel,
                image: true,
                child: AuthenticatedMediaPathImage(
                  key: const ValueKey('story-playback.display-image'),
                  thumbnailPath: _displayPath(preview),
                  representation: AuthenticatedMediaRepresentation.display,
                  fit: BoxFit.cover,
                  placeholder: const _PhotoLoading(),
                  errorBuilder: (_) {
                    return _PhotoFallback(
                      key: const ValueKey('story-playback.photo-unavailable'),
                      label: l10n.playbackPhotoUnavailable,
                      icon: Icons.broken_image_outlined,
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _PhotoLoading extends StatelessWidget {
  const _PhotoLoading();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: Color(0xFFEFF3F7)),
      child: Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Color(0xFFFF5D72),
          ),
        ),
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback({
    required this.label,
    required this.icon,
    super.key,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFF5D72), size: 34),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF344054),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryMetaRow extends StatelessWidget {
  const _MemoryMetaRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFFFF5D72)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaybackLoading extends StatelessWidget {
  const _PlaybackLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 40,
      child: CircularProgressIndicator(
        strokeWidth: 4,
        color: Color(0xFFFF5D72),
      ),
    );
  }
}

class _PlaybackMessage extends StatelessWidget {
  const _PlaybackMessage({
    required this.title,
    required this.body,
    required this.primaryAction,
    this.secondaryAction,
    super.key,
  });

  final String title;
  final String body;
  final _PlaybackTextAction primaryAction;
  final _PlaybackTextAction? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final secondaryAction = this.secondaryAction;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF7FFFFFF),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF182232),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                primaryAction,
                if (secondaryAction != null) secondaryAction,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackTextAction extends StatelessWidget {
  const _PlaybackTextAction({
    required this.buttonKey,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: buttonKey,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFFF5D72),
        foregroundColor: Colors.white,
        minimumSize: const Size(112, 44),
      ),
    );
  }
}

String? _progressLabel(StoryPlaybackState playback) {
  final progress = playback.progress;
  if (progress.total == 0) {
    return null;
  }

  return '${progress.currentPosition} / ${progress.total}';
}

double? _progressValue(StoryPlaybackState playback) {
  final progress = playback.progress;
  if (progress.total == 0) {
    return null;
  }

  return progress.currentPosition / progress.total;
}

String _displayPath(MemoryPhotoPreview preview) {
  return '/api/v1/media/${Uri.encodeComponent(preview.mediaId)}/display';
}
