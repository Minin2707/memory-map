import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/presentation/story_timeline_screen.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';
import 'package:memory_map/features/story/domain/story_role.dart';

class StoryTimelineRoute extends ConsumerWidget {
  const StoryTimelineRoute({
    required this.storyId,
    this.onBack,
    this.onCreateMemory,
    this.onMemorySelected,
    this.onPlaybackSelected,
    super.key,
  });

  final String storyId;
  final VoidCallback? onBack;
  final VoidCallback? onCreateMemory;
  final ValueChanged<Memory>? onMemorySelected;
  final VoidCallback? onPlaybackSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userStory =
        ref.watch(storyDetailsProvider(storyId)).asData?.value.userStory;
    final role = userStory?.role;

    return StoryTimelineScreen(
      storyId: storyId,
      storyTitle: userStory?.story.title,
      onBack: onBack,
      onCreateMemory: _canCreateMemory(role) ? onCreateMemory : null,
      onMemorySelected: onMemorySelected,
      onPlaybackSelected: onPlaybackSelected,
    );
  }

  bool _canCreateMemory(StoryRole? role) {
    return role == StoryRole.owner ||
        role == StoryRole.coOwner ||
        role == StoryRole.editor;
  }
}
