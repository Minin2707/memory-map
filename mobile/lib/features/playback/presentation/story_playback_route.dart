import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/playback/application/story_playback_notifier.dart';
import 'package:memory_map/features/playback/application/story_playback_provider.dart';
import 'package:memory_map/features/playback/presentation/story_playback_screen.dart';

final storyPlaybackMapBuilderProvider = Provider<PlaybackMapBuilder?>((_) {
  return null;
});

class StoryPlaybackRoute extends ConsumerStatefulWidget {
  const StoryPlaybackRoute({
    required this.storyId,
    required this.fallbackRouteName,
    required this.storyIdPathParameter,
    this.storyTitle,
    this.onMemoryDetailsSelected,
    super.key,
  });

  final String storyId;
  final String fallbackRouteName;
  final String storyIdPathParameter;
  final String? storyTitle;
  final ValueChanged<MemoryReadModel>? onMemoryDetailsSelected;

  @override
  ConsumerState<StoryPlaybackRoute> createState() => _StoryPlaybackRouteState();
}

class _StoryPlaybackRouteState extends ConsumerState<StoryPlaybackRoute>
    with WidgetsBindingObserver {
  late StoryPlaybackNotifier _playbackNotifier;
  bool _hasRequestedPlaybackShutdown = false;

  @override
  void initState() {
    super.initState();
    _playbackNotifier = ref.read(
      storyPlaybackProvider(widget.storyId).notifier,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant StoryPlaybackRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storyId == widget.storyId) {
      return;
    }

    _playbackNotifier = ref.read(
      storyPlaybackProvider(widget.storyId).notifier,
    );
    _hasRequestedPlaybackShutdown = false;
  }

  @override
  void dispose() {
    _requestPlaybackShutdownOnce();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _playbackNotifier.pause();
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _stopAndClose(context);
        }
      },
      child: StoryPlaybackScreen(
        storyId: widget.storyId,
        storyTitle: widget.storyTitle,
        mapBuilder: ref.watch(storyPlaybackMapBuilderProvider),
        onMemoryDetailsSelected: widget.onMemoryDetailsSelected,
        onClose: () {
          _stopAndClose(context);
        },
      ),
    );
  }

  void _stopAndClose(BuildContext context) {
    _requestPlaybackShutdownOnce();
    _close(context);
  }

  void _requestPlaybackShutdownOnce() {
    if (_hasRequestedPlaybackShutdown) {
      return;
    }

    _hasRequestedPlaybackShutdown = true;
    _playbackNotifier.stop();
  }

  void _close(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }

    context.goNamed(
      widget.fallbackRouteName,
      pathParameters: {widget.storyIdPathParameter: widget.storyId},
    );
  }
}
