import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_update_field.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';

void main() {
  group('UpdateMemoryInput', () {
    test('shouldCreateTitleOnlyUpdate', () {
      final input = UpdateMemoryInput(
        memoryId: 'memory-id',
        title: const MemoryUpdateField<String>.provided('Updated title'),
      );

      expect(input.memoryId, 'memory-id');
      expect(input.title.isProvided, isTrue);
      expect(input.title.value, 'Updated title');
      expect(input.description.isProvided, isFalse);
      expect(input.placeName.isProvided, isFalse);
      expect(input.location.isProvided, isFalse);
      expect(input.eventDate.isProvided, isFalse);
    });

    test('shouldCreateDescriptionSetUpdate', () {
      final input = UpdateMemoryInput(
        memoryId: 'memory-id',
        description:
            const MemoryUpdateField<String?>.provided('Updated description'),
      );

      expect(input.description.isProvided, isTrue);
      expect(input.description.value, 'Updated description');
    });

    test('shouldCreateDescriptionClearUpdate', () {
      final input = UpdateMemoryInput(
        memoryId: 'memory-id',
        description: const MemoryUpdateField<String?>.provided(null),
      );

      expect(input.description.isProvided, isTrue);
      expect(input.description.value, isNull);
    });

    test('shouldCreatePlaceNameSetAndClearUpdates', () {
      final setInput = UpdateMemoryInput(
        memoryId: 'memory-id',
        placeName: const MemoryUpdateField<String?>.provided('Updated place'),
      );
      final clearInput = UpdateMemoryInput(
        memoryId: 'memory-id',
        placeName: const MemoryUpdateField<String?>.provided(null),
      );

      expect(setInput.placeName.value, 'Updated place');
      expect(clearInput.placeName.isProvided, isTrue);
      expect(clearInput.placeName.value, isNull);
    });

    test('shouldCreateLocationOnlyUpdate', () {
      final location = createLocation();

      final input = UpdateMemoryInput(
        memoryId: 'memory-id',
        location: MemoryUpdateField<MemoryLocation>.provided(location),
      );

      expect(input.location.isProvided, isTrue);
      expect(input.location.value, location);
    });

    test('shouldCreateEventDateOnlyUpdate', () {
      final eventDate = createDate();

      final input = UpdateMemoryInput(
        memoryId: 'memory-id',
        eventDate: MemoryUpdateField<MemoryDate>.provided(eventDate),
      );

      expect(input.eventDate.isProvided, isTrue);
      expect(input.eventDate.value, eventDate);
    });

    test('shouldCreateAllFieldsUpdate', () {
      final input = UpdateMemoryInput(
        memoryId: 'memory-id',
        title: const MemoryUpdateField<String>.provided('Updated title'),
        description:
            const MemoryUpdateField<String?>.provided('Updated description'),
        placeName: const MemoryUpdateField<String?>.provided('Updated place'),
        location: MemoryUpdateField<MemoryLocation>.provided(createLocation()),
        eventDate: MemoryUpdateField<MemoryDate>.provided(createDate()),
      );

      expect(input.title.isProvided, isTrue);
      expect(input.description.isProvided, isTrue);
      expect(input.placeName.isProvided, isTrue);
      expect(input.location.isProvided, isTrue);
      expect(input.eventDate.isProvided, isTrue);
    });

    test('shouldRejectBlankMemoryId', () {
      expect(
        () => UpdateMemoryInput(
          memoryId: '   ',
          title: const MemoryUpdateField<String>.provided('Updated title'),
        ),
        throwsA(argumentErrorWithMessage('memoryId must not be blank')),
      );
    });

    test('shouldRejectEmptyUpdate', () {
      expect(
        () => UpdateMemoryInput(memoryId: 'memory-id'),
        throwsA(
          argumentErrorWithMessage(
            'at least one update field must be provided',
          ),
        ),
      );
    });

    test('shouldRejectNullTitle', () {
      expect(
        () => UpdateMemoryInput(
          memoryId: 'memory-id',
          title: const MemoryUpdateField<String>.provided(null),
        ),
        throwsA(argumentErrorWithMessage('title must not be null')),
      );
    });

    test('shouldRejectBlankTitle', () {
      expect(
        () => UpdateMemoryInput(
          memoryId: 'memory-id',
          title: const MemoryUpdateField<String>.provided('   '),
        ),
        throwsA(argumentErrorWithMessage('title must not be blank')),
      );
    });

    test('shouldRejectTitleLongerThanBackendLimit', () {
      expect(
        () => UpdateMemoryInput(
          memoryId: 'memory-id',
          title: MemoryUpdateField<String>.provided(''.padRight(256, 'a')),
        ),
        throwsA(
          argumentErrorWithMessage('title must not exceed 255 characters'),
        ),
      );
    });

    test('shouldRejectPlaceNameLongerThanBackendLimit', () {
      expect(
        () => UpdateMemoryInput(
          memoryId: 'memory-id',
          placeName: MemoryUpdateField<String?>.provided(
            ''.padRight(256, 'a'),
          ),
        ),
        throwsA(
          argumentErrorWithMessage('placeName must not exceed 255 characters'),
        ),
      );
    });

    test('shouldRejectNullLocationAndEventDate', () {
      expect(
        () => UpdateMemoryInput(
          memoryId: 'memory-id',
          location: const MemoryUpdateField<MemoryLocation>.provided(null),
        ),
        throwsA(argumentErrorWithMessage('location must not be null')),
      );
      expect(
        () => UpdateMemoryInput(
          memoryId: 'memory-id',
          eventDate: const MemoryUpdateField<MemoryDate>.provided(null),
        ),
        throwsA(argumentErrorWithMessage('eventDate must not be null')),
      );
    });

    test('shouldPreserveEmptyNullableStrings', () {
      final input = UpdateMemoryInput(
        memoryId: 'memory-id',
        description: const MemoryUpdateField<String?>.provided(''),
        placeName: const MemoryUpdateField<String?>.provided(''),
      );

      expect(input.description.value, '');
      expect(input.placeName.value, '');
    });

    test('shouldNotNormalizeTextFields', () {
      final input = UpdateMemoryInput(
        memoryId: ' memory-id ',
        title: const MemoryUpdateField<String>.provided(' Updated title '),
        description:
            const MemoryUpdateField<String?>.provided(' Updated description '),
        placeName: const MemoryUpdateField<String?>.provided(' Updated place '),
      );

      expect(input.memoryId, ' memory-id ');
      expect(input.title.value, ' Updated title ');
      expect(input.description.value, ' Updated description ');
      expect(input.placeName.value, ' Updated place ');
    });

    test('shouldAllowSameLookingValuesAsValidInput', () {
      final input = UpdateMemoryInput(
        memoryId: 'memory-id',
        title: const MemoryUpdateField<String>.provided('Current title'),
      );

      expect(input.title.value, 'Current title');
    });

    test('shouldCompareInputsByValue', () {
      final first = UpdateMemoryInput(
        memoryId: 'memory-id',
        title: const MemoryUpdateField<String>.provided('Updated title'),
      );
      final second = UpdateMemoryInput(
        memoryId: 'memory-id',
        title: const MemoryUpdateField<String>.provided('Updated title'),
      );
      final different = UpdateMemoryInput(
        memoryId: 'memory-id',
        description:
            const MemoryUpdateField<String?>.provided('Updated description'),
      );

      expect(first, second);
      expect(first, isNot(different));
      expect(first.hashCode, second.hashCode);
    });

    test('shouldUsePresenceOnlySafeToString', () {
      final input = UpdateMemoryInput(
        memoryId: 'memory-id-secret',
        title: const MemoryUpdateField<String>.provided('SECRET TITLE'),
        description:
            const MemoryUpdateField<String?>.provided('SECRET DESCRIPTION'),
        placeName: const MemoryUpdateField<String?>.provided('SECRET PLACE'),
        location: MemoryUpdateField<MemoryLocation>.provided(
          MemoryLocation(latitude: 41.715123, longitude: 44.827456),
        ),
        eventDate: MemoryUpdateField<MemoryDate>.provided(
          MemoryDate(year: 2035, month: 12, day: 17),
        ),
      );
      final value = input.toString();

      expect(
        value,
        'UpdateMemoryInput(updatesTitle: true, '
        'updatesDescription: true, updatesPlaceName: true, '
        'updatesLocation: true, updatesEventDate: true)',
      );
      expect(value, isNot(contains('memory-id-secret')));
      expect(value, isNot(contains('SECRET TITLE')));
      expect(value, isNot(contains('SECRET DESCRIPTION')));
      expect(value, isNot(contains('SECRET PLACE')));
      expect(value, isNot(contains('41.715123')));
      expect(value, isNot(contains('44.827456')));
      expect(value, isNot(contains('2035-12-17')));
    });
  });
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
