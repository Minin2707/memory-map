import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/application/memory_canonical_order.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_year_section.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';

final storyMemoriesYearSectionsProvider =
    Provider.family<AsyncValue<List<StoryMemoriesYearSection>>, String>(
  (ref, storyId) {
    final memoriesValue = ref.watch(storyMemoriesProvider(storyId));
    return memoriesValue.whenData((state) {
      if (state.hasLoadFailure) {
        return const <StoryMemoriesYearSection>[];
      }

      return buildStoryMemoriesYearSections(state.memoryReadModels);
    });
  },
);

List<StoryMemoriesYearSection> buildStoryMemoriesYearSections(
  List<MemoryReadModel> memories,
) {
  if (memories.isEmpty) {
    return const <StoryMemoriesYearSection>[];
  }

  final canonical = memories.toList(growable: false)
    ..sort(compareMemoryReadModelsCanonical);
  final years = <int>[];
  final grouped = <int, List<MemoryReadModel>>{};

  for (final readModel in canonical) {
    final year = readModel.memory.eventDate.year;
    final yearMemories = grouped.putIfAbsent(year, () {
      years.add(year);
      return <MemoryReadModel>[];
    });
    yearMemories.add(readModel);
  }

  years.sort((left, right) => right.compareTo(left));

  return List<StoryMemoriesYearSection>.unmodifiable(
    years.map((year) {
      return StoryMemoriesYearSection(
        year: year,
        memories: grouped[year] ?? const <MemoryReadModel>[],
      );
    }),
  );
}
