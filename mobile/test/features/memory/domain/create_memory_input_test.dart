import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';

void main() {
  group('CreateMemoryInput', () {
    test('shouldCreateInput', () {
      final input = createInput();

      expect(input.storyId, 'story-id');
      expect(input.title, 'First day in Tbilisi');
      expect(input.description, 'Old city walk');
      expect(input.placeName, 'Tbilisi');
      expect(input.location, createLocation());
      expect(input.eventDate, createDate());
    });

    test('shouldAllowNullableOptionalFields', () {
      final input = createInput(
        description: null,
        placeName: null,
      );

      expect(input.description, isNull);
      expect(input.placeName, isNull);
    });

    test('shouldAllowEmptyOptionalStrings', () {
      final input = createInput(
        description: '',
        placeName: '',
      );

      expect(input.description, '');
      expect(input.placeName, '');
    });

    test('shouldRejectBlankStoryId', () {
      expect(
        () => createInput(storyId: '   '),
        throwsA(argumentErrorWithMessage('storyId must not be blank')),
      );
    });

    test('shouldRejectBlankTitle', () {
      expect(
        () => createInput(title: '   '),
        throwsA(argumentErrorWithMessage('title must not be blank')),
      );
    });

    test('shouldRejectTitleLongerThanBackendLimit', () {
      expect(
        () => createInput(title: ''.padRight(256, 'a')),
        throwsA(
          argumentErrorWithMessage('title must not exceed 255 characters'),
        ),
      );
    });

    test('shouldRejectPlaceNameLongerThanBackendLimit', () {
      expect(
        () => createInput(placeName: ''.padRight(256, 'a')),
        throwsA(
          argumentErrorWithMessage('placeName must not exceed 255 characters'),
        ),
      );
    });

    test('shouldAllowFutureEventDate', () {
      final input = createInput(
        eventDate: MemoryDate(year: 2035, month: 12, day: 17),
      );

      expect(input.eventDate.toIso8601Date(), '2035-12-17');
    });

    test('shouldNotNormalizeTextFields', () {
      final input = createInput(
        storyId: ' story-id ',
        title: ' First day ',
        description: ' Old city walk ',
        placeName: ' Tbilisi ',
      );

      expect(input.storyId, ' story-id ');
      expect(input.title, ' First day ');
      expect(input.description, ' Old city walk ');
      expect(input.placeName, ' Tbilisi ');
    });

    test('shouldCompareInputsByValue', () {
      final first = createInput();
      final second = createInput();
      final different = createInput(title: 'Another title');

      expect(first, second);
      expect(first, isNot(different));
      expect(first.hashCode, second.hashCode);
    });

    test('shouldUseSafeToString', () {
      final input = createInput(
        storyId: 'story-id-secret',
        title: 'SECRET TITLE',
        description: 'SECRET DESCRIPTION',
        placeName: 'SECRET PLACE',
        location: MemoryLocation(latitude: 41.715123, longitude: 44.827456),
        eventDate: MemoryDate(year: 2035, month: 12, day: 17),
      );
      final value = input.toString();

      expect(value, 'CreateMemoryInput');
      expect(value, isNot(contains('story-id-secret')));
      expect(value, isNot(contains('SECRET TITLE')));
      expect(value, isNot(contains('SECRET DESCRIPTION')));
      expect(value, isNot(contains('SECRET PLACE')));
      expect(value, isNot(contains('41.715123')));
      expect(value, isNot(contains('44.827456')));
      expect(value, isNot(contains('2035-12-17')));
    });
  });
}

CreateMemoryInput createInput({
  String storyId = 'story-id',
  String title = 'First day in Tbilisi',
  String? description = 'Old city walk',
  String? placeName = 'Tbilisi',
  MemoryLocation? location,
  MemoryDate? eventDate,
}) {
  return CreateMemoryInput(
    storyId: storyId,
    title: title,
    description: description,
    placeName: placeName,
    location: location ?? createLocation(),
    eventDate: eventDate ?? createDate(),
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
