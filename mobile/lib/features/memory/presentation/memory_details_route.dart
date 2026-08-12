import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/application/memory_details_notifier.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/presentation/memory_details_screen.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';
import 'package:memory_map/features/story/domain/story_role.dart';

class MemoryDetailsRoute extends ConsumerWidget {
  const MemoryDetailsRoute({
    required this.memoryId,
    required this.currentUserId,
    this.onBackUnavailable,
    this.onBack,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  final String memoryId;
  final String? currentUserId;
  final VoidCallback? onBackUnavailable;
  final ValueChanged<Memory>? onBack;
  final ValueChanged<Memory>? onEdit;
  final ValueChanged<Memory>? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsValue = ref.watch(memoryDetailsProvider(memoryId));
    final memory = detailsValue.asData?.value.memory;
    final canManage = _canManageMemory(ref, memory);
    final canMutateMedia = _canMutateMemoryContent(ref, memory);

    return MemoryDetailsScreen(
      memoryId: memoryId,
      canUploadPhoto: canMutateMedia,
      canDeletePhoto: canMutateMedia,
      onBack: () {
        final currentMemory = ref
            .read(memoryDetailsProvider(memoryId))
            .asData
            ?.value
            .memory;
        if (currentMemory == null) {
          onBackUnavailable?.call();
          return;
        }

        onBack?.call(currentMemory);
      },
      onEdit: canManage ? onEdit : null,
      onDelete: canManage ? onDelete : null,
    );
  }

  bool _canManageMemory(WidgetRef ref, Memory? memory) {
    if (memory == null) {
      return false;
    }

    if (currentUserId != null && memory.createdBy == currentUserId) {
      return true;
    }

    final userStory = ref
        .watch(storyDetailsProvider(memory.storyId))
        .asData
        ?.value
        .userStory;
    final role = userStory?.role;

    return role == StoryRole.owner || role == StoryRole.coOwner;
  }

  bool _canMutateMemoryContent(WidgetRef ref, Memory? memory) {
    if (memory == null) {
      return false;
    }

    if (currentUserId != null && memory.createdBy == currentUserId) {
      return true;
    }

    final userStory = ref
        .watch(storyDetailsProvider(memory.storyId))
        .asData
        ?.value
        .userStory;
    final role = userStory?.role;

    return role == StoryRole.owner || role == StoryRole.coOwner;
  }
}
