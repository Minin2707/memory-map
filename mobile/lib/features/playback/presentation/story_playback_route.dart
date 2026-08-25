import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
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
        ref.read(storyPlaybackProvider(widget.storyId).notifier).pause();
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
          _stopAndClose(context, ref);
        }
      },
      child: StoryPlaybackScreen(
        storyId: widget.storyId,
        storyTitle: widget.storyTitle,
        mapBuilder: ref.watch(storyPlaybackMapBuilderProvider),
        onMemoryDetailsSelected: widget.onMemoryDetailsSelected,
        onClose: () {
          _stopAndClose(context, ref);
        },
      ),
    );
  }

  void _stopAndClose(BuildContext context, WidgetRef ref) {
    ref.read(storyPlaybackProvider(widget.storyId).notifier).stop();
    _close(context);
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
