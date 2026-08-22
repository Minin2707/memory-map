import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/playback/presentation/story_playback_screen.dart';

final storyPlaybackMapBuilderProvider = Provider<PlaybackMapBuilder?>((_) {
  return null;
});

class StoryPlaybackRoute extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _close(context);
        }
      },
      child: StoryPlaybackScreen(
        storyId: storyId,
        storyTitle: storyTitle,
        mapBuilder: ref.watch(storyPlaybackMapBuilderProvider),
        onMemoryDetailsSelected: onMemoryDetailsSelected,
        onClose: () {
          _close(context);
        },
      ),
    );
  }

  void _close(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }

    context.goNamed(
      fallbackRouteName,
      pathParameters: {storyIdPathParameter: storyId},
    );
  }
}
