import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/application/memory_canonical_order.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';

const storyDetailsRecentMemoryLimit = 3;

final storyDetailsRecentMemoriesProvider =
    Provider.family<AsyncValue<List<MemoryReadModel>>, String>(
  (ref, storyId) {
    final memoriesValue = ref.watch(storyMemoriesProvider(storyId));
    return memoriesValue.whenData((state) {
      if (state.hasLoadFailure) {
        return const <MemoryReadModel>[];
      }

      return buildStoryDetailsRecentMemoryReadModels(state.memoryReadModels);
    });
  },
);

final storyDetailsMemoryPeriodProvider =
    Provider.family<AsyncValue<StoryMemoryPeriod?>, String>(
  (ref, storyId) {
    final memoriesValue = ref.watch(storyMemoriesProvider(storyId));
    return memoriesValue.whenData((state) {
      if (state.hasLoadFailure) {
        return null;
      }

      return buildStoryMemoryPeriod(state.memoryReadModels);
    });
  },
);

List<MemoryReadModel> buildStoryDetailsRecentMemoryReadModels(
  List<MemoryReadModel> memories,
) {
  if (memories.isEmpty) {
    return const <MemoryReadModel>[];
  }

  final recent = memories.toList(growable: false)
    ..sort((left, right) => compareMemoryReadModelsCanonical(right, left));
  return List<MemoryReadModel>.unmodifiable(
    recent.take(storyDetailsRecentMemoryLimit),
  );
}

StoryMemoryPeriod? buildStoryMemoryPeriod(List<MemoryReadModel> memories) {
  if (memories.isEmpty) {
    return null;
  }

  MemoryDate? earliest;
  MemoryDate? latest;
  for (final readModel in memories) {
    final eventDate = readModel.memory.eventDate;
    if (earliest == null || eventDate.compareTo(earliest) < 0) {
      earliest = eventDate;
    }
    if (latest == null || eventDate.compareTo(latest) > 0) {
      latest = eventDate;
    }
  }

  if (earliest == null || latest == null) {
    return null;
  }

  return StoryMemoryPeriod(startYear: earliest.year, endYear: latest.year);
}

final class StoryMemoryPeriod {
  const StoryMemoryPeriod({
    required this.startYear,
    required this.endYear,
  });

  final int startYear;
  final int endYear;

  bool get isSingleYear => startYear == endYear;
}
