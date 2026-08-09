import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/memory_canonical_order.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';

void main() {
  group('compareMemoriesCanonical', () {
    test('shouldOrderByEventDateFirst', () {
      final memories = <Memory>[
        memory(id: '00000000-0000-0000-0000-000000000003', day: 20),
        memory(id: '00000000-0000-0000-0000-000000000001', day: 10),
        memory(id: '00000000-0000-0000-0000-000000000002', day: 15),
      ];

      memories.sort(compareMemoriesCanonical);

      expect(
        memories.map((memory) => memory.id),
        <String>[
          '00000000-0000-0000-0000-000000000001',
          '00000000-0000-0000-0000-000000000002',
          '00000000-0000-0000-0000-000000000003',
        ],
      );
    });

    test('shouldOrderByCreatedAtWhenEventDateMatches', () {
      final memories = <Memory>[
        memory(id: '00000000-0000-0000-0000-000000000003', createdHour: 12),
        memory(id: '00000000-0000-0000-0000-000000000001', createdHour: 10),
        memory(id: '00000000-0000-0000-0000-000000000002', createdHour: 11),
      ];

      memories.sort(compareMemoriesCanonical);

      expect(
        memories.map((memory) => memory.id),
        <String>[
          '00000000-0000-0000-0000-000000000001',
          '00000000-0000-0000-0000-000000000002',
          '00000000-0000-0000-0000-000000000003',
        ],
      );
    });

    test('shouldOrderByCanonicalStringIdWhenDatesAndCreatedAtMatch', () {
      final memories = <Memory>[
        memory(id: '00000000-0000-0000-0000-00000000000c'),
        memory(id: '00000000-0000-0000-0000-00000000000a'),
        memory(id: '00000000-0000-0000-0000-00000000000b'),
      ];

      memories.sort(compareMemoriesCanonical);

      expect(
        memories.map((memory) => memory.id),
        <String>[
          '00000000-0000-0000-0000-00000000000a',
          '00000000-0000-0000-0000-00000000000b',
          '00000000-0000-0000-0000-00000000000c',
        ],
      );
    });
  });
}

Memory memory({
  required String id,
  int day = 9,
  int createdHour = 10,
}) {
  return Memory(
    id: id,
    storyId: 'story-id',
    createdBy: 'author-id',
    title: 'First picnic',
    description: 'Near the river',
    placeName: 'Riverside Park',
    location: MemoryLocation(latitude: 55.751244, longitude: 37.618423),
    eventDate: MemoryDate(year: 2026, month: 8, day: day),
    createdAt: DateTime.utc(2026, 8, 9, createdHour),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}
