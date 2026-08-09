import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';

void main() {
  group('Memory', () {
    test('shouldCreateMemory', () {
      final memory = createMemory();

      expect(memory.id, 'memory-id');
      expect(memory.storyId, 'story-id');
      expect(memory.createdBy, 'author-id');
      expect(memory.title, 'First day in Tbilisi');
      expect(memory.description, 'Old city walk');
      expect(memory.placeName, 'Tbilisi');
      expect(memory.location, createLocation());
      expect(memory.eventDate, createDate());
      expect(memory.createdAt, DateTime.utc(2026, 8, 9, 10));
      expect(memory.updatedAt, DateTime.utc(2026, 8, 9, 11));
    });

    test('shouldAllowNullableFields', () {
      final memory = createMemory(
        description: null,
        placeName: null,
      );

      expect(memory.description, isNull);
      expect(memory.placeName, isNull);
    });

    test('shouldAllowEmptyOptionalStrings', () {
      final memory = createMemory(
        description: '',
        placeName: '',
      );

      expect(memory.description, '');
      expect(memory.placeName, '');
    });

    test('shouldRejectBlankIdentifiers', () {
      expect(
        () => createMemory(id: '   '),
        throwsA(argumentErrorWithMessage('id must not be blank')),
      );
      expect(
        () => createMemory(storyId: '   '),
        throwsA(argumentErrorWithMessage('storyId must not be blank')),
      );
      expect(
        () => createMemory(createdBy: '   '),
        throwsA(argumentErrorWithMessage('createdBy must not be blank')),
      );
    });

    test('shouldRejectBlankTitle', () {
      expect(
        () => createMemory(title: '   '),
        throwsA(argumentErrorWithMessage('title must not be blank')),
      );
    });

    test('shouldRejectTitleLongerThanBackendLimit', () {
      expect(
        () => createMemory(title: ''.padRight(256, 'a')),
        throwsA(
          argumentErrorWithMessage('title must not exceed 255 characters'),
        ),
      );
    });

    test('shouldAllowTitleAtBackendLimit', () {
      final memory = createMemory(title: ''.padRight(255, 'a'));

      expect(memory.title.length, 255);
    });

    test('shouldRejectPlaceNameLongerThanBackendLimit', () {
      expect(
        () => createMemory(placeName: ''.padRight(256, 'a')),
        throwsA(
          argumentErrorWithMessage('placeName must not exceed 255 characters'),
        ),
      );
    });

    test('shouldNormalizeTimestampsToUtc', () {
      final createdAt = DateTime(2026, 8, 9, 10);
      final updatedAt = DateTime(2026, 8, 9, 11);

      final memory = createMemory(
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      expect(memory.createdAt, createdAt.toUtc());
      expect(memory.createdAt.isUtc, isTrue);
      expect(memory.updatedAt, updatedAt.toUtc());
      expect(memory.updatedAt.isUtc, isTrue);
    });

    test('shouldPreserveMemoryDateAndLocation', () {
      final location = MemoryLocation(latitude: 41.715123, longitude: 44.827456);
      final eventDate = MemoryDate(year: 2035, month: 12, day: 17);

      final memory = createMemory(
        location: location,
        eventDate: eventDate,
      );

      expect(memory.location, location);
      expect(memory.eventDate, eventDate);
    });

    test('shouldNotNormalizeTextFields', () {
      final memory = createMemory(
        id: ' memory-id ',
        storyId: ' story-id ',
        createdBy: ' author-id ',
        title: ' First day ',
        description: ' Old city walk ',
        placeName: ' Tbilisi ',
      );

      expect(memory.id, ' memory-id ');
      expect(memory.storyId, ' story-id ');
      expect(memory.createdBy, ' author-id ');
      expect(memory.title, ' First day ');
      expect(memory.description, ' Old city walk ');
      expect(memory.placeName, ' Tbilisi ');
    });

    test('shouldCompareMemoriesByValue', () {
      final first = createMemory();
      final second = createMemory();
      final different = createMemory(id: 'another-memory-id');

      expect(first, second);
      expect(first, isNot(different));
      expect(first.hashCode, second.hashCode);
    });

    test('shouldUseSafeToString', () {
      final memory = createSensitiveMemory();
      final value = memory.toString();

      expect(value, 'Memory(hasDescription: true, hasPlaceName: true)');
      expect(value, isNot(contains('memory-id-secret')));
      expect(value, isNot(contains('story-id-secret')));
      expect(value, isNot(contains('author-id-secret')));
      expect(value, isNot(contains('SECRET TITLE')));
      expect(value, isNot(contains('SECRET DESCRIPTION')));
      expect(value, isNot(contains('SECRET PLACE')));
      expect(value, isNot(contains('41.715123')));
      expect(value, isNot(contains('44.827456')));
      expect(value, isNot(contains('2035')));
      expect(value, isNot(contains('2035-12-17')));
      expect(value, isNot(contains('token')));
      expect(value, isNot(contains('Dio')));
      expect(value, isNot(contains('HTTP')));
    });
  });
}

Memory createMemory({
  String id = 'memory-id',
  String storyId = 'story-id',
  String createdBy = 'author-id',
  String title = 'First day in Tbilisi',
  String? description = 'Old city walk',
  String? placeName = 'Tbilisi',
  MemoryLocation? location,
  MemoryDate? eventDate,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return Memory(
    id: id,
    storyId: storyId,
    createdBy: createdBy,
    title: title,
    description: description,
    placeName: placeName,
    location: location ?? createLocation(),
    eventDate: eventDate ?? createDate(),
    createdAt: createdAt ?? DateTime.utc(2026, 8, 9, 10),
    updatedAt: updatedAt ?? DateTime.utc(2026, 8, 9, 11),
  );
}

Memory createSensitiveMemory() {
  return createMemory(
    id: 'memory-id-secret',
    storyId: 'story-id-secret',
    createdBy: 'author-id-secret',
    title: 'SECRET TITLE',
    description: 'SECRET DESCRIPTION',
    placeName: 'SECRET PLACE',
    location: MemoryLocation(latitude: 41.715123, longitude: 44.827456),
    eventDate: MemoryDate(year: 2035, month: 12, day: 17),
  );
}

MemoryLocation createLocation() {
  return MemoryLocation(latitude: 41.6938, longitude: 44.8015);
}

MemoryDate createDate() {
  return MemoryDate(year: 2024, month: 5, day: 18);
}

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}
