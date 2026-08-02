import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/data/remote/create_story_remote_request.dart';
import 'package:memory_map/features/story/data/remote/story_patch_field.dart';
import 'package:memory_map/features/story/data/remote/update_story_remote_request.dart';

void main() {
  group('CreateStoryRemoteRequest', () {
    test('shouldSerializeCreateStoryRequest', () {
      final request = CreateStoryRemoteRequest(
        title: 'Our Story',
        description: 'Together since 2021',
      );

      expect(request.toJson(), <String, Object?>{
        'title': 'Our Story',
        'description': 'Together since 2021',
      });
    });

    test('shouldOmitNullCreateDescription', () {
      final request = CreateStoryRemoteRequest(
        title: 'Our Story',
        description: null,
      );

      expect(request.toJson(), <String, Object?>{
        'title': 'Our Story',
      });
      expect(request.toJson().containsKey('description'), isFalse);
    });

    test('shouldRejectBlankCreateTitle', () {
      expect(
        () => CreateStoryRemoteRequest(title: '   '),
        throwsA(argumentErrorWithMessage('title must not be blank')),
      );
    });

    test('shouldNotNormalizeCreateTextFields', () {
      final request = CreateStoryRemoteRequest(
        title: ' Our Story ',
        description: ' Together since 2021 ',
      );

      expect(request.toJson(), <String, Object?>{
        'title': ' Our Story ',
        'description': ' Together since 2021 ',
      });
    });
  });

  group('StoryPatchField', () {
    test('shouldRepresentNotProvided', () {
      const field = StoryPatchField<String>.notProvided();

      expect(field.isProvided, isFalse);
      expect(field.value, isNull);
    });

    test('shouldRepresentProvidedValue', () {
      const field = StoryPatchField<String>.provided('Updated Story');

      expect(field.isProvided, isTrue);
      expect(field.value, 'Updated Story');
    });

    test('shouldRepresentProvidedNull', () {
      const field = StoryPatchField<String>.provided(null);

      expect(field.isProvided, isTrue);
      expect(field.value, isNull);
    });

    test('shouldComparePatchFieldsByValue', () {
      expect(
        const StoryPatchField<String>.provided('Updated Story'),
        const StoryPatchField<String>.provided('Updated Story'),
      );
      expect(
        const StoryPatchField<String>.notProvided(),
        const StoryPatchField<String>.notProvided(),
      );
    });

    test('shouldExposePresenceOnlyInToString', () {
      const field = StoryPatchField<String>.provided('Updated Story');

      expect(field.toString(), 'StoryPatchField[provided]');
      expect(field.toString(), isNot(contains('Updated Story')));
    });
  });

  group('UpdateStoryRemoteRequest', () {
    test('shouldSerializeTitleOnlyPatch', () {
      final request = UpdateStoryRemoteRequest(
        title: const StoryPatchField<String>.provided('Updated Story'),
      );

      expect(request.toJson(), <String, Object?>{
        'title': 'Updated Story',
      });
      expect(request.toJson().containsKey('description'), isFalse);
    });

    test('shouldSerializeDescriptionOnlyPatch', () {
      final request = UpdateStoryRemoteRequest(
        description:
            const StoryPatchField<String>.provided('Updated description'),
      );

      expect(request.toJson(), <String, Object?>{
        'description': 'Updated description',
      });
      expect(request.toJson().containsKey('title'), isFalse);
    });

    test('shouldSerializeClearDescriptionPatch', () {
      final request = UpdateStoryRemoteRequest(
        description: const StoryPatchField<String>.provided(null),
      );

      expect(request.toJson(), <String, Object?>{
        'description': null,
      });
      expect(request.toJson().containsKey('description'), isTrue);
    });

    test('shouldSerializeBothFieldsPatch', () {
      final request = UpdateStoryRemoteRequest(
        title: const StoryPatchField<String>.provided('Updated Story'),
        description:
            const StoryPatchField<String>.provided('Updated description'),
      );

      expect(request.toJson(), <String, Object?>{
        'title': 'Updated Story',
        'description': 'Updated description',
      });
    });

    test('shouldSerializeTitleAndClearDescriptionPatch', () {
      final request = UpdateStoryRemoteRequest(
        title: const StoryPatchField<String>.provided('Updated Story'),
        description: const StoryPatchField<String>.provided(null),
      );

      expect(request.toJson(), <String, Object?>{
        'title': 'Updated Story',
        'description': null,
      });
    });

    test('shouldRejectEmptyPatch', () {
      expect(
        () => UpdateStoryRemoteRequest(),
        throwsA(
          argumentErrorWithMessage(
            'at least one update field must be provided',
          ),
        ),
      );
    });

    test('shouldRejectNullTitlePatch', () {
      expect(
        () => UpdateStoryRemoteRequest(
          title: const StoryPatchField<String>.provided(null),
        ),
        throwsA(argumentErrorWithMessage('title must not be null')),
      );
    });

    test('shouldRejectBlankTitlePatch', () {
      expect(
        () => UpdateStoryRemoteRequest(
          title: const StoryPatchField<String>.provided('   '),
        ),
        throwsA(argumentErrorWithMessage('title must not be blank')),
      );
    });

    test('shouldPreserveBlankDescriptionPatch', () {
      final request = UpdateStoryRemoteRequest(
        description: const StoryPatchField<String>.provided('   '),
      );

      expect(request.toJson(), <String, Object?>{
        'description': '   ',
      });
    });

    test('shouldNotExposeInternalPresenceFieldsInJson', () {
      final request = UpdateStoryRemoteRequest(
        title: const StoryPatchField<String>.provided('Updated Story'),
      );

      expect(request.toJson().containsKey('isProvided'), isFalse);
      expect(request.toJson().containsKey('value'), isFalse);
      expect(request.toJson().containsKey('ownerId'), isFalse);
      expect(request.toJson().containsKey('role'), isFalse);
    });
  });
}

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}
