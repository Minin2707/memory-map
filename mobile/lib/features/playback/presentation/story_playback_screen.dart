import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

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

const int _playbackDisplayMaxDecodeDimension = 2048;

@visibleForTesting
({int cacheWidth, int? cacheHeight}) playbackDisplayDecodeSizeForTesting({
  required Size logicalSize,
  required double devicePixelRatio,
}) {
  final safePixelRatio = devicePixelRatio.isFinite && devicePixelRatio > 0
      ? devicePixelRatio
      : 1.0;
  final physicalWidth = math.max(1, (logicalSize.width * safePixelRatio).ceil());

  return (
    cacheWidth: math.min(physicalWidth, _playbackDisplayMaxDecodeDimension),
    cacheHeight: null,
  );
}

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
    this.onMemoryDetailsSelected,
    super.key,
  });

  final String storyId;
  final String? storyTitle;
  final VoidCallback onClose;
  final PlaybackMapBuilder? mapBuilder;
  final ValueChanged<MemoryReadModel>? onMemoryDetailsSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(storyPlaybackProvider(storyId));
    final notifier = ref.read(storyPlaybackProvider(storyId).notifier);
    final title = storyTitle ?? l10n.playbackTitle;
    final onMemoryDetailsSelected = this.onMemoryDetailsSelected;

    if (state.isLoading) {
      return _PlaybackFrame(
        key: const ValueKey('story-playback.loading'),
        title: title,
        onClose: onClose,
        child: const _PlaybackLoading(),
      );
    }

    if (state.hasLoadFailure) {
      return _PlaybackFrame(
        key: const ValueKey('story-playback.load-failure'),
        title: title,
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
        ),
      );
    }

    final playback = state.requirePlayback;
    return _PlaybackSessionView(
      playback: playback,
      hasCameraFailure: state.hasCameraFailure,
      title: title,
      mapBuilder: mapBuilder,
      onCameraArrived: notifier.cameraArrived,
      onCameraFailed: notifier.cameraFailed,
      onPresentationDismissed: notifier.presentationDismissed,
      onRetryCamera: notifier.retryCamera,
      onPrevious: notifier.previous,
      onNext: notifier.next,
      onPause: notifier.pause,
      onResume: notifier.resume,
      onReplay: notifier.replay,
      onMemoryDetailsSelected: onMemoryDetailsSelected == null
          ? null
          : (memory) {
              notifier.pause();
              onMemoryDetailsSelected(memory);
            },
      onClose: onClose,
    );
  }
}

class _PlaybackSessionView extends StatefulWidget {
  const _PlaybackSessionView({
    required this.playback,
    required this.hasCameraFailure,
    required this.title,
    required this.mapBuilder,
    required this.onCameraArrived,
    required this.onCameraFailed,
    required this.onPresentationDismissed,
    required this.onRetryCamera,
    required this.onPrevious,
    required this.onNext,
    required this.onPause,
    required this.onResume,
    required this.onReplay,
    required this.onClose,
    required this.onMemoryDetailsSelected,
  });

  final StoryPlaybackState playback;
  final bool hasCameraFailure;
  final String title;
  final PlaybackMapBuilder? mapBuilder;
  final ValueChanged<int> onCameraArrived;
  final ValueChanged<int> onCameraFailed;
  final ValueChanged<int> onPresentationDismissed;
  final VoidCallback onRetryCamera;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onReplay;
  final VoidCallback onClose;
  final ValueChanged<MemoryReadModel>? onMemoryDetailsSelected;

  @override
  State<_PlaybackSessionView> createState() => _PlaybackSessionViewState();
}

class _PlaybackSessionViewState extends State<_PlaybackSessionView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _openingController;
  late final Animation<double> _openingAnimation;
  bool _openingComplete = false;

  @override
  void initState() {
    super.initState();
    _openingController = AnimationController(
      vsync: this,
      duration: widget.playback.policy.cinematicOpeningDuration,
    );
    _openingAnimation = CurvedAnimation(
      parent: _openingController,
      curve: Curves.easeOutCubic,
    );
    _openingController.addListener(_handleOpeningTick);
    _openingController.addStatusListener(_handleOpeningStatus);
    _openingComplete = !_usesCinematicOpening(widget.playback);
    _syncOpeningAnimation();
  }

  @override
  void didUpdateWidget(_PlaybackSessionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playback.policy.cinematicOpeningDuration !=
        widget.playback.policy.cinematicOpeningDuration) {
      _openingController.duration =
          widget.playback.policy.cinematicOpeningDuration;
    }

    if (oldWidget.playback.isFinished &&
        _usesCinematicOpening(widget.playback)) {
      _restartOpening();
    }

    if (!_usesCinematicOpening(widget.playback)) {
      _openingComplete = true;
      _openingController.value = 1;
    }

    _syncOpeningAnimation();
  }

  @override
  void dispose() {
    _openingController
      ..removeListener(_handleOpeningTick)
      ..removeStatusListener(_handleOpeningStatus)
      ..dispose();
    super.dispose();
  }

  void _handleOpeningTick() {
    if (_openingComplete || !_hasOpeningAnimationCompleted || !mounted) {
      return;
    }

    setState(() {
      _openingComplete = true;
    });
  }

  void _handleOpeningStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _openingComplete || !mounted) {
      return;
    }

    setState(() {
      _openingComplete = true;
    });
  }

  void _restartOpening() {
    _openingComplete = false;
    _openingController.value = 0;
  }

  void _syncOpeningAnimation() {
    if (_isOpeningComplete || !_usesCinematicOpening(widget.playback)) {
      return;
    }

    if (widget.playback.status == PlaybackStatus.playing) {
      _openingController.forward();
      return;
    }

    _openingController.stop();
  }

  @override
  Widget build(BuildContext context) {
    final playback = widget.playback;
    final isOpeningComplete = _isOpeningComplete;
    final markers = playbackMarkersFromSnapshot(playback.snapshot);
    final route = playbackRouteFromSnapshot(playback.snapshot);
    final mapPresentation = PlaybackMapPresentation(
      markers: markers,
      route: route,
      currentIndex: playback.currentIndex,
      cameraCommand: _effectiveCameraCommand(
        playback,
        isOpeningComplete: isOpeningComplete,
      ),
      onCameraArrived: widget.onCameraArrived,
      onCameraFailed: widget.onCameraFailed,
    );

    return Scaffold(
      key: const ValueKey('story-playback.screen'),
      backgroundColor: const Color(0xFF101820),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildMap(context, mapPresentation),
          const _PlaybackReadabilityOverlays(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
              child: Column(
                children: [
                  _PlaybackTopBar(
                    label: AppLocalizations.of(context).playbackContextLabel,
                    title: widget.title,
                    onClose: widget.onClose,
                  ),
                  const SizedBox(height: 10),
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
          if (!isOpeningComplete)
            _PlaybackOpeningOverlay(animation: _openingAnimation),
        ],
      ),
    );
  }

  bool get _isOpeningComplete =>
      _openingComplete || _hasOpeningAnimationCompleted;

  bool get _hasOpeningAnimationCompleted =>
      _openingController.isCompleted || _openingController.value >= 1;

  PlaybackCameraCommand? _effectiveCameraCommand(
    StoryPlaybackState playback, {
    required bool isOpeningComplete,
  }) {
    if (!_usesCinematicOpening(playback)) {
      return playback.cameraCommand;
    }

    if (isOpeningComplete && playback.status == PlaybackStatus.playing) {
      return playback.cameraCommand;
    }

    return null;
  }

  Widget _bottomOverlay(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final playback = widget.playback;

    if (playback.isIdle) {
      return _PlaybackMessage(
        key: const ValueKey('story-playback.empty'),
        title: l10n.playbackEmptyTitle,
        body: l10n.playbackEmptyBody,
      );
    }

    if (widget.hasCameraFailure) {
      return _PlaybackMessage(
        key: const ValueKey('story-playback.camera-failure'),
        title: l10n.playbackCameraFailureTitle,
        body: l10n.playbackCameraFailureBody,
        primaryAction: _PlaybackTextAction(
          buttonKey: const ValueKey('story-playback.retry-camera'),
          label: l10n.playbackRetryAction,
          icon: Icons.refresh_rounded,
          onPressed: widget.onRetryCamera,
        ),
      );
    }

    if (playback.isFinished) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlaybackMessage(
            key: const ValueKey('story-playback.finished'),
            title: l10n.playbackFinishedTitle,
            body: l10n.playbackFinishedBody,
            cinematic: true,
          ),
          const SizedBox(height: 16),
          _PlaybackProgressOverlay(
            label: _progressLabel(l10n, playback)!,
            value: _progressValue(playback)!,
          ),
          const SizedBox(height: 16),
          _PlaybackPrimaryPlaybackButton(
            buttonKey: const ValueKey('story-playback.replay'),
            label: l10n.playbackReplayAction,
            icon: Icons.replay_rounded,
            onPressed: widget.onReplay,
          ),
        ],
      );
    }

    final progressLabel = _progressLabel(l10n, playback);
    final progressValue = _progressValue(playback);
    final currentMemory = playback.currentMemory;
    final onMemoryDetailsSelected = widget.onMemoryDetailsSelected;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if ((playback.phase == PlaybackPhase.presenting ||
                playback.phase == PlaybackPhase.dismissing) &&
            currentMemory != null)
          _CinematicMemoryCard(
            readModel: currentMemory,
            presentationRevision: playback.presentationRevision,
            status: playback.status,
            phase: playback.phase!,
            arrivalPauseDuration: playback.policy.arrivalPauseDuration,
            revealDuration: playback.policy.memoryRevealDuration,
            dismissalDuration: playback.policy.memoryDismissalDuration,
            onDismissed: widget.onPresentationDismissed,
            childBuilder: (dismissThen) {
              return _CurrentMemoryCard(
                readModel: currentMemory,
                showPrevious: (playback.currentIndex ?? 0) > 0,
                showNext: playback.currentIndex != null,
                onPrevious: () {
                  dismissThen(widget.onPrevious);
                },
                onNext: () {
                  dismissThen(widget.onNext);
                },
                onDetails: onMemoryDetailsSelected == null
                    ? null
                    : () {
                        onMemoryDetailsSelected(currentMemory);
                      },
              );
            },
          ),
        if ((playback.phase == PlaybackPhase.presenting ||
                playback.phase == PlaybackPhase.dismissing) &&
            currentMemory != null)
          const SizedBox(height: 16),
        if (progressLabel != null && progressValue != null)
          _PlaybackProgressOverlay(
            label: progressLabel,
            value: progressValue,
          ),
        const SizedBox(height: 16),
        _PlaybackPrimaryPlaybackButton(
          buttonKey: playback.status == PlaybackStatus.paused
              ? const ValueKey('story-playback.resume')
              : const ValueKey('story-playback.pause'),
          label: playback.status == PlaybackStatus.paused
              ? l10n.playbackResumeAction
              : l10n.playbackPauseAction,
          icon: playback.status == PlaybackStatus.paused
              ? Icons.play_arrow_rounded
              : Icons.pause_rounded,
          onPressed: playback.status == PlaybackStatus.paused
              ? widget.onResume
              : widget.onPause,
        ),
      ],
    );
  }

  Widget _buildMap(
    BuildContext context,
    PlaybackMapPresentation presentation,
  ) {
    final builder = widget.mapBuilder;
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

class _PlaybackOpeningOverlay extends StatelessWidget {
  const _PlaybackOpeningOverlay({
    required this.animation,
  });

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Opacity(
            key: const ValueKey('story-playback.opening-overlay'),
            opacity: 1 - animation.value,
            child: child,
          );
        },
        child: const ColoredBox(color: Colors.black),
      ),
    );
  }
}

bool _usesCinematicOpening(StoryPlaybackState playback) {
  return playback.phase == PlaybackPhase.moving &&
      playback.currentIndex == 0 &&
      playback.cameraCommand?.memoryIndex == 0;
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
    final l10n = AppLocalizations.of(context);

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
                  label: l10n.playbackContextLabel,
                  title: title,
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
    required this.label,
    required this.title,
    required this.onClose,
  });

  final String label;
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox.square(dimension: 50),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1.08,
                    shadows: [
                      Shadow(
                        color: Color(0x99000000),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _PlaybackChromeButton(
          buttonKey: const ValueKey('story-playback.close'),
          tooltip: l10n.playbackCloseAction,
          icon: Icons.close_rounded,
          onPressed: onClose,
        ),
      ],
    );
  }
}

class _PlaybackPhotoArrowButton extends StatelessWidget {
  const _PlaybackPhotoArrowButton({
    required this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final Key buttonKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 44,
      child: IconButton(
        key: buttonKey,
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0x8C000000),
          foregroundColor: Colors.white,
          shadowColor: const Color(0x66000000),
          elevation: 6,
        ),
        icon: Icon(icon, size: 28),
      ),
    );
  }
}

typedef _DismissThen = void Function(VoidCallback action);
typedef _CinematicMemoryCardBuilder = Widget Function(_DismissThen dismissThen);

class _CinematicMemoryCard extends StatefulWidget {
  const _CinematicMemoryCard({
    required this.readModel,
    required this.presentationRevision,
    required this.status,
    required this.phase,
    required this.arrivalPauseDuration,
    required this.revealDuration,
    required this.dismissalDuration,
    required this.onDismissed,
    required this.childBuilder,
  });

  final MemoryReadModel readModel;
  final int presentationRevision;
  final PlaybackStatus status;
  final PlaybackPhase phase;
  final Duration arrivalPauseDuration;
  final Duration revealDuration;
  final Duration dismissalDuration;
  final ValueChanged<int> onDismissed;
  final _CinematicMemoryCardBuilder childBuilder;

  @override
  State<_CinematicMemoryCard> createState() => _CinematicMemoryCardState();
}

class _CinematicMemoryCardState extends State<_CinematicMemoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  late Animation<Offset> _offset;
  Timer? _arrivalTimer;
  bool _dismissalNotified = false;
  bool _manualDismissalPending = false;
  VoidCallback? _pendingAction;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.revealDuration,
      reverseDuration: widget.dismissalDuration,
    );
    _configureAnimations();
    _syncAnimationForState();
  }

  @override
  void didUpdateWidget(_CinematicMemoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revealDuration != widget.revealDuration ||
        oldWidget.dismissalDuration != widget.dismissalDuration) {
      _controller
        ..duration = widget.revealDuration
        ..reverseDuration = widget.dismissalDuration;
    }

    if (oldWidget.readModel.memory.id != widget.readModel.memory.id) {
      _dismissalNotified = false;
      _manualDismissalPending = false;
      _pendingAction = null;
      _controller.value = 0;
    }

    _syncAnimationForState();
  }

  @override
  void dispose() {
    _arrivalTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _configureAnimations() {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _scale = Tween<double>(begin: 0.82, end: 1).animate(curved);
    _offset = Tween<Offset>(
      begin: const Offset(0, -0.22),
      end: Offset.zero,
    ).animate(curved);
  }

  void _syncAnimationForState() {
    _arrivalTimer?.cancel();

    if (widget.status == PlaybackStatus.paused) {
      _controller.stop();
      return;
    }

    if (widget.phase == PlaybackPhase.dismissing) {
      _startDismissal(notifyWhenComplete: true);
      return;
    }

    if (widget.phase != PlaybackPhase.presenting) {
      return;
    }

    if (_controller.value >= 1) {
      return;
    }

    _arrivalTimer = Timer(widget.arrivalPauseDuration, () {
      if (!mounted ||
          widget.status != PlaybackStatus.playing ||
          widget.phase != PlaybackPhase.presenting) {
        return;
      }

      _controller.forward();
    });
  }

  void _dismissThen(VoidCallback action) {
    if (_manualDismissalPending) {
      return;
    }

    _manualDismissalPending = true;
    _pendingAction = action;
    _arrivalTimer?.cancel();
    _startDismissal(notifyWhenComplete: false);
  }

  void _startDismissal({required bool notifyWhenComplete}) {
    _arrivalTimer?.cancel();
    _controller.reverse().then((_) {
      if (!mounted) {
        return;
      }

      final action = _pendingAction;
      _pendingAction = null;
      if (action != null) {
        action();
        return;
      }

      if (notifyWhenComplete && !_dismissalNotified) {
        _dismissalNotified = true;
        widget.onDismissed(widget.presentationRevision);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: widget.phase == PlaybackPhase.dismissing,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _offset,
          child: ScaleTransition(
            scale: _scale,
            child: widget.childBuilder(_dismissThen),
          ),
        ),
      ),
    );
  }
}

class _CurrentMemoryCard extends StatelessWidget {
  const _CurrentMemoryCard({
    required this.readModel,
    required this.showPrevious,
    required this.showNext,
    required this.onPrevious,
    required this.onNext,
    required this.onDetails,
  });

  final MemoryReadModel readModel;
  final bool showPrevious;
  final bool showNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final memory = readModel.memory;
    final placeName = memory.placeName?.trim();
    final description = memory.description?.trim();
    final onDetails = this.onDetails;

    return ConstrainedBox(
      key: const ValueKey('story-playback.memory-card'),
      constraints: const BoxConstraints(maxWidth: 548),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xB80A1018),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0x33FFFFFF)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x5C000000),
                  blurRadius: 30,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MemoryPhotoPanel(
                    preview: readModel.previewPhoto,
                    showPrevious: showPrevious,
                    showNext: showNext,
                    onPrevious: onPrevious,
                    onNext: onNext,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _MemoryMetaRow(
                      icon: Icons.calendar_today_rounded,
                      text: formatMemoryDate(l10n, memory.eventDate),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      memory.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        height: 1.1,
                      ),
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xE6FFFFFF),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          height: 1.34,
                        ),
                      ),
                    ),
                  ],
                  if (onDetails != null ||
                      (placeName != null && placeName.isNotEmpty)) ...[
                    const SizedBox(height: 11),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: onDetails == null
                          ? _MemoryMetaRow(
                              icon: Icons.place_rounded,
                              text: placeName!,
                            )
                          : _MemoryCardFooter(
                              placeName:
                                  placeName != null && placeName.isNotEmpty
                                      ? placeName
                                      : null,
                              onDetails: onDetails,
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemoryCardFooter extends StatelessWidget {
  const _MemoryCardFooter({
    required this.placeName,
    required this.onDetails,
  });

  final String? placeName;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final onDetails = this.onDetails;
    if (onDetails == null) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Expanded(
          child: placeName == null
              ? const SizedBox.shrink()
              : _MemoryPlaceChip(placeName: placeName!),
        ),
        const SizedBox(width: 8),
        _MemoryDetailsAction(onPressed: onDetails),
      ],
    );
  }
}

class _MemoryPlaceChip extends StatelessWidget {
  const _MemoryPlaceChip({
    required this.placeName,
  });

  final String placeName;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: _MemoryMetaRow(
            icon: Icons.place_rounded,
            text: placeName,
          ),
        ),
      ),
    );
  }
}

class _MemoryDetailsAction extends StatelessWidget {
  const _MemoryDetailsAction({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return TextButton(
      key: const ValueKey('story-playback.details'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: const Color(0x1FFFFFFF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.fromLTRB(13, 8, 10, 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: Color(0x3DFFFFFF)),
        ),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.storyMapShowDetailsAction),
          const SizedBox(width: 3),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
    );
  }
}

class _MemoryPhotoPanel extends StatelessWidget {
  const _MemoryPhotoPanel({
    required this.preview,
    required this.showPrevious,
    required this.showNext,
    required this.onPrevious,
    required this.onNext,
  });

  final MemoryPhotoPreview? preview;
  final bool showPrevious;
  final bool showNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preview = this.preview;

    return ClipRRect(
      borderRadius: BorderRadius.circular(21),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (preview == null)
              _PhotoFallback(
                key: const ValueKey('story-playback.no-photo'),
                label: l10n.playbackNoPhotoTitle,
                icon: Icons.photo_outlined,
              )
            else
              Semantics(
                label: l10n.playbackMemoryPhotoLabel,
                image: true,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final decodeSize = playbackDisplayDecodeSizeForTesting(
                      logicalSize: constraints.biggest,
                      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                    );
                    return AuthenticatedMediaPathImage(
                      key: const ValueKey('story-playback.display-image'),
                      thumbnailPath: _displayPath(preview),
                      representation: AuthenticatedMediaRepresentation.display,
                      fit: BoxFit.cover,
                      cacheWidth: decodeSize.cacheWidth,
                      cacheHeight: decodeSize.cacheHeight,
                      placeholder: const _PhotoLoading(),
                      errorBuilder: (_) {
                        return _PhotoFallback(
                          key: const ValueKey(
                            'story-playback.photo-unavailable',
                          ),
                          label: l10n.playbackPhotoUnavailable,
                          icon: Icons.broken_image_outlined,
                        );
                      },
                    );
                  },
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x14000000),
                    Color(0x00000000),
                    Color(0x52000000),
                  ],
                ),
              ),
            ),
            if (showPrevious)
              Positioned(
                left: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _PlaybackPhotoArrowButton(
                    buttonKey: const ValueKey('story-playback.previous'),
                    tooltip: l10n.playbackPreviousAction,
                    icon: Icons.chevron_left_rounded,
                    onPressed: onPrevious,
                  ),
                ),
              ),
            if (showNext)
              Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _PlaybackPhotoArrowButton(
                    buttonKey: const ValueKey('story-playback.next'),
                    tooltip: l10n.playbackNextAction,
                    icon: Icons.chevron_right_rounded,
                    onPressed: onNext,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackPrimaryPlaybackButton extends StatelessWidget {
  const _PlaybackPrimaryPlaybackButton({
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: buttonKey,
          onPressed: onPressed,
          icon: Icon(icon, size: 26),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0x300B1220),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(23),
              side: const BorderSide(color: Color(0x40FFFFFF)),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
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
      decoration: BoxDecoration(color: Color(0xFF182232)),
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
            Color(0xFF1E2937),
            Color(0xFF332032),
            Color(0xFF15303A),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFF7A8A), size: 34),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
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
        Icon(icon, size: 16, color: const Color(0xFFFF7A8A)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
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

class _PlaybackReadabilityOverlays extends StatelessWidget {
  const _PlaybackReadabilityOverlays();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x9C000812),
              Color(0x33000812),
              Color(0x05000812),
              Color(0x26000812),
              Color(0xC0000812),
            ],
            stops: [0, 0.18, 0.46, 0.68, 1],
          ),
        ),
      ),
    );
  }
}

class _PlaybackProgressOverlay extends StatelessWidget {
  const _PlaybackProgressOverlay({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              key: const ValueKey('story-playback.progress-label'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xD9FFFFFF),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 9),
            _PlaybackProgressTrack(value: value),
          ],
        ),
      ),
    );
  }
}

class _PlaybackProgressTrack extends StatelessWidget {
  const _PlaybackProgressTrack({
    required this.value,
  });

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: const ValueKey('story-playback.progress'),
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0x55FFFFFF)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0).toDouble(),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFFF5D72),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x55FF5D72),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackChromeButton extends StatelessWidget {
  const _PlaybackChromeButton({
    required this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final Key buttonKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 50,
      child: IconButton(
        key: buttonKey,
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0x99000000),
          foregroundColor: Colors.white,
        ),
        icon: Icon(icon, size: 28),
      ),
    );
  }
}

class _PlaybackMessage extends StatelessWidget {
  const _PlaybackMessage({
    required this.title,
    required this.body,
    this.primaryAction,
    this.cinematic = false,
    super.key,
  });

  final String title;
  final String body;
  final _PlaybackTextAction? primaryAction;
  final bool cinematic;

  @override
  Widget build(BuildContext context) {
    final primaryAction = this.primaryAction;
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xB80A1018),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x33FFFFFF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x5C000000),
            blurRadius: cinematic ? 30 : 24,
            offset: Offset(0, cinematic ? 16 : 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          cinematic ? 24 : 20,
          cinematic ? 24 : 20,
          cinematic ? 24 : 20,
          cinematic ? 26 : 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xD9FFFFFF),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                height: 1.4,
              ),
            ),
            if (primaryAction != null) ...[
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  primaryAction,
                ],
              ),
            ],
          ],
        ),
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: surface,
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
        minimumSize: const Size(118, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

String? _progressLabel(
  AppLocalizations l10n,
  StoryPlaybackState playback,
) {
  final progress = playback.progress;
  if (progress.total == 0) {
    return null;
  }

  return l10n.playbackProgressLabel(
    progress.currentPosition,
    progress.total,
  );
}

double? _progressValue(StoryPlaybackState playback) {
  final progress = playback.progress;
  if (progress.total == 0) {
    return null;
  }

  return progress.fraction;
}

String _displayPath(MemoryPhotoPreview preview) {
  return '/api/v1/media/${Uri.encodeComponent(preview.mediaId)}/display';
}
