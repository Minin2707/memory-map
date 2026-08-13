import 'package:memory_map/features/memory/application/memory_canonical_order.dart';
import 'package:memory_map/features/memory/application/story_timeline_section.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';

List<StoryTimelineSection> buildStoryTimelineSections(
  List<MemoryReadModel> memories,
) {
  if (memories.isEmpty) {
    return const <StoryTimelineSection>[];
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

  return List<StoryTimelineSection>.unmodifiable(
    years.map((year) {
      return StoryTimelineSection(
        year: year,
        memories: grouped[year] ?? const <MemoryReadModel>[],
      );
    }),
  );
}
