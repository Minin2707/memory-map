import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/presentation/story_memories_screen.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';
import 'package:memory_map/features/story/domain/story_role.dart';

class StoryMemoriesRoute extends ConsumerWidget {
  const StoryMemoriesRoute({
    required this.storyId,
    this.onBack,
    this.onCreateMemory,
    this.onMemorySelected,
    super.key,
  });

  final String storyId;
  final VoidCallback? onBack;
  final VoidCallback? onCreateMemory;
  final ValueChanged<Memory>? onMemorySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCreateMemory = _canCreateMemory(ref);

    return StoryMemoriesScreen(
      storyId: storyId,
      onBack: onBack,
      onCreateMemory: canCreateMemory ? onCreateMemory : null,
      onMemorySelected: onMemorySelected,
    );
  }

  bool _canCreateMemory(WidgetRef ref) {
    final role = ref
        .watch(storyDetailsProvider(storyId))
        .asData
        ?.value
        .userStory
        ?.role;

    return role == StoryRole.owner ||
        role == StoryRole.coOwner ||
        role == StoryRole.editor;
  }
}
