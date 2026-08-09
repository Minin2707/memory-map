import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/data/remote/create_memory_remote_request.dart';
import 'package:memory_map/features/memory/data/remote/memory_patch_field.dart';
import 'package:memory_map/features/memory/data/remote/update_memory_remote_request.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_update_field.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';

void main() {
  group('CreateMemoryRemoteRequest', () {
    test('shouldSerializeCreateMemoryRequest', () {
      final request = CreateMemoryRemoteRequest(
        title: 'First picnic',
        description: 'Near the river',
        placeName: 'Riverside Park',
        location: location(),
        eventDate: eventDate(),
      );

      expect(request.toJson(), <String, Object?>{
        'title': 'First picnic',
        'description': 'Near the river',
        'placeName': 'Riverside Park',
        'latitude': 55.751244,
        'longitude': 37.618423,
        'eventDate': '2026-08-09',
      });
    });

    test('shouldOmitNullNullableFields', () {
      final request = CreateMemoryRemoteRequest(
        title: 'First picnic',
        description: null,
        placeName: null,
        location: location(),
        eventDate: eventDate(),
      );

      expect(request.toJson(), <String, Object?>{
        'title': 'First picnic',
        'latitude': 55.751244,
        'longitude': 37.618423,
        'eventDate': '2026-08-09',
      });
      expect(request.toJson().containsKey('description'), isFalse);
      expect(request.toJson().containsKey('placeName'), isFalse);
    });

    test('shouldCreateFromInputWithoutSendingStoryId', () {
      final request = CreateMemoryRemoteRequest.fromInput(
        CreateMemoryInput(
          storyId: 'story-id',
          title: 'First picnic',
          description: 'Near the river',
          placeName: 'Riverside Park',
          location: location(),
          eventDate: eventDate(),
        ),
      );

      expect(request.toJson().containsKey('storyId'), isFalse);
      expect(request.toJson(), containsPair('title', 'First picnic'));
    });

    test('shouldRejectBlankTitle', () {
      expect(
        () => CreateMemoryRemoteRequest(
          title: '   ',
          location: location(),
          eventDate: eventDate(),
        ),
        throwsA(argumentErrorWithMessage('title must not be blank')),
      );
    });

    test('shouldNotNormalizeTextFields', () {
      final request = CreateMemoryRemoteRequest(
        title: ' First picnic ',
        description: ' Near the river ',
        placeName: ' Riverside Park ',
        location: location(),
        eventDate: eventDate(),
      );

      expect(request.toJson(), <String, Object?>{
        'title': ' First picnic ',
        'description': ' Near the river ',
        'placeName': ' Riverside Park ',
        'latitude': 55.751244,
        'longitude': 37.618423,
        'eventDate': '2026-08-09',
      });
    });
  });

  group('MemoryPatchField', () {
    test('shouldRepresentNotProvided', () {
      const field = MemoryPatchField<String>.notProvided();

      expect(field.isProvided, isFalse);
      expect(field.value, isNull);
    });

    test('shouldRepresentProvidedValue', () {
      const field = MemoryPatchField<String>.provided('First picnic');

      expect(field.isProvided, isTrue);
      expect(field.value, 'First picnic');
    });

    test('shouldRepresentProvidedNull', () {
      const field = MemoryPatchField<String?>.provided(null);

      expect(field.isProvided, isTrue);
      expect(field.value, isNull);
    });

    test('shouldComparePatchFieldsByValue', () {
      expect(
        const MemoryPatchField<String>.provided('First picnic'),
        const MemoryPatchField<String>.provided('First picnic'),
      );
      expect(
        const MemoryPatchField<String>.notProvided(),
        const MemoryPatchField<String>.notProvided(),
      );
    });

    test('shouldExposePresenceOnlyInToString', () {
      const field = MemoryPatchField<String>.provided('First picnic');

      expect(field.toString(), 'MemoryPatchField[provided]');
      expect(field.toString(), isNot(contains('First picnic')));
    });
  });

  group('UpdateMemoryRemoteRequest', () {
    test('shouldSerializeTitleOnlyPatch', () {
      final request = UpdateMemoryRemoteRequest(
        title: const MemoryPatchField<String>.provided('Updated title'),
      );

      expect(request.toJson(), <String, Object?>{
        'title': 'Updated title',
      });
    });

    test('shouldSerializeDescriptionOnlyPatch', () {
      final request = UpdateMemoryRemoteRequest(
        description:
            const MemoryPatchField<String?>.provided('Updated description'),
      );

      expect(request.toJson(), <String, Object?>{
        'description': 'Updated description',
      });
    });

    test('shouldSerializeClearNullableFieldsPatch', () {
      final request = UpdateMemoryRemoteRequest(
        description: const MemoryPatchField<String?>.provided(null),
        placeName: const MemoryPatchField<String?>.provided(null),
      );

      expect(request.toJson(), <String, Object?>{
        'description': null,
        'placeName': null,
      });
      expect(request.toJson().containsKey('description'), isTrue);
      expect(request.toJson().containsKey('placeName'), isTrue);
    });

    test('shouldSerializeLocationPatchAsLatitudeAndLongitude', () {
      final request = UpdateMemoryRemoteRequest(
        location: MemoryPatchField<MemoryLocation>.provided(location()),
      );

      expect(request.toJson(), <String, Object?>{
        'latitude': 55.751244,
        'longitude': 37.618423,
      });
    });

    test('shouldSerializeEventDatePatch', () {
      final request = UpdateMemoryRemoteRequest(
        eventDate: MemoryPatchField<MemoryDate>.provided(eventDate()),
      );

      expect(request.toJson(), <String, Object?>{
        'eventDate': '2026-08-09',
      });
    });

    test('shouldSerializeAllFieldsPatch', () {
      final request = UpdateMemoryRemoteRequest(
        title: const MemoryPatchField<String>.provided('Updated title'),
        description:
            const MemoryPatchField<String?>.provided('Updated description'),
        placeName: const MemoryPatchField<String?>.provided('Updated place'),
        location: MemoryPatchField<MemoryLocation>.provided(location()),
        eventDate: MemoryPatchField<MemoryDate>.provided(eventDate()),
      );

      expect(request.toJson(), <String, Object?>{
        'title': 'Updated title',
        'description': 'Updated description',
        'placeName': 'Updated place',
        'latitude': 55.751244,
        'longitude': 37.618423,
        'eventDate': '2026-08-09',
      });
    });

    test('shouldCreateFromInputWithPatchPresenceSemantics', () {
      final request = UpdateMemoryRemoteRequest.fromInput(
        UpdateMemoryInput(
          memoryId: 'memory-id',
          title: const MemoryUpdateField<String>.provided('Updated title'),
          description: const MemoryUpdateField<String?>.provided(null),
          location: MemoryUpdateField<MemoryLocation>.provided(location()),
        ),
      );

      expect(request.toJson(), <String, Object?>{
        'title': 'Updated title',
        'description': null,
        'latitude': 55.751244,
        'longitude': 37.618423,
      });
      expect(request.toJson().containsKey('memoryId'), isFalse);
      expect(request.toJson().containsKey('placeName'), isFalse);
      expect(request.toJson().containsKey('eventDate'), isFalse);
    });

    test('shouldRejectEmptyPatch', () {
      expect(
        () => UpdateMemoryRemoteRequest(),
        throwsA(
          argumentErrorWithMessage(
            'at least one update field must be provided',
          ),
        ),
      );
    });

    test('shouldRejectNullTitlePatch', () {
      expect(
        () => UpdateMemoryRemoteRequest(
          title: const MemoryPatchField<String>.provided(null),
        ),
        throwsA(argumentErrorWithMessage('title must not be null')),
      );
    });

    test('shouldRejectBlankTitlePatch', () {
      expect(
        () => UpdateMemoryRemoteRequest(
          title: const MemoryPatchField<String>.provided('   '),
        ),
        throwsA(argumentErrorWithMessage('title must not be blank')),
      );
    });

    test('shouldRejectNullLocationPatch', () {
      expect(
        () => UpdateMemoryRemoteRequest(
          location: const MemoryPatchField<MemoryLocation>.provided(null),
        ),
        throwsA(argumentErrorWithMessage('location must not be null')),
      );
    });

    test('shouldRejectNullEventDatePatch', () {
      expect(
        () => UpdateMemoryRemoteRequest(
          eventDate: const MemoryPatchField<MemoryDate>.provided(null),
        ),
        throwsA(argumentErrorWithMessage('eventDate must not be null')),
      );
    });

    test('shouldPreserveBlankNullableTextPatch', () {
      final request = UpdateMemoryRemoteRequest(
        description: const MemoryPatchField<String?>.provided('   '),
        placeName: const MemoryPatchField<String?>.provided('   '),
      );

      expect(request.toJson(), <String, Object?>{
        'description': '   ',
        'placeName': '   ',
      });
    });

    test('shouldNotExposeInternalPresenceFieldsInJson', () {
      final request = UpdateMemoryRemoteRequest(
        title: const MemoryPatchField<String>.provided('Updated title'),
      );

      expect(request.toJson().containsKey('isProvided'), isFalse);
      expect(request.toJson().containsKey('value'), isFalse);
      expect(request.toJson().containsKey('storyId'), isFalse);
      expect(request.toJson().containsKey('createdBy'), isFalse);
    });

    test('shouldExposeSafeToString', () {
      final request = UpdateMemoryRemoteRequest(
        title: const MemoryPatchField<String>.provided('secret title'),
      );

      expect(request.toString(), contains('updatesTitle: true'));
      expect(request.toString(), isNot(contains('secret title')));
    });
  });
}

MemoryLocation location() {
  return MemoryLocation(
    latitude: 55.751244,
    longitude: 37.618423,
  );
}

MemoryDate eventDate() {
  return MemoryDate(year: 2026, month: 8, day: 9);
}

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}
