import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/domain/story_update_field.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';

void main() {
  group('StoryUpdateField', () {
    test('shouldRepresentNotProvided', () {
      const field = StoryUpdateField<String>.notProvided();

      expect(field.isProvided, isFalse);
      expect(field.value, isNull);
    });

    test('shouldRepresentProvidedValue', () {
      const field = StoryUpdateField<String>.provided('Updated Story');

      expect(field.isProvided, isTrue);
      expect(field.value, 'Updated Story');
    });

    test('shouldRepresentProvidedNull', () {
      const field = StoryUpdateField<String>.provided(null);

      expect(field.isProvided, isTrue);
      expect(field.value, isNull);
    });

    test('shouldCompareFieldsByValue', () {
      expect(
        const StoryUpdateField<String>.provided('Updated Story'),
        const StoryUpdateField<String>.provided('Updated Story'),
      );
      expect(
        const StoryUpdateField<String>.notProvided(),
        const StoryUpdateField<String>.notProvided(),
      );
    });

    test('shouldExposeOnlyPresenceInToString', () {
      const field = StoryUpdateField<String>.provided('Updated Story');

      expect(field.toString(), 'StoryUpdateField[provided]');
      expect(field.toString(), isNot(contains('Updated Story')));
    });
  });

  group('UpdateStoryInput', () {
    test('shouldCreateTitleOnlyUpdate', () {
      final input = UpdateStoryInput(
        storyId: 'story-id',
        title: const StoryUpdateField<String>.provided('Updated Story'),
      );

      expect(input.storyId, 'story-id');
      expect(input.title.isProvided, isTrue);
      expect(input.title.value, 'Updated Story');
      expect(input.description.isProvided, isFalse);
    });

    test('shouldCreateDescriptionOnlyUpdate', () {
      final input = UpdateStoryInput(
        storyId: 'story-id',
        description:
            const StoryUpdateField<String>.provided('Updated description'),
      );

      expect(input.title.isProvided, isFalse);
      expect(input.description.isProvided, isTrue);
      expect(input.description.value, 'Updated description');
    });

    test('shouldAllowClearDescription', () {
      final input = UpdateStoryInput(
        storyId: 'story-id',
        description: const StoryUpdateField<String>.provided(null),
      );

      expect(input.description.isProvided, isTrue);
      expect(input.description.value, isNull);
    });

    test('shouldCreateBothFieldsUpdate', () {
      final input = UpdateStoryInput(
        storyId: 'story-id',
        title: const StoryUpdateField<String>.provided('Updated Story'),
        description:
            const StoryUpdateField<String>.provided('Updated description'),
      );

      expect(input.title.value, 'Updated Story');
      expect(input.description.value, 'Updated description');
    });

    test('shouldRejectBlankStoryId', () {
      expect(
        () => UpdateStoryInput(
          storyId: '   ',
          title: const StoryUpdateField<String>.provided('Updated Story'),
        ),
        throwsA(argumentErrorWithMessage('storyId must not be blank')),
      );
    });

    test('shouldRejectEmptyUpdate', () {
      expect(
        () => UpdateStoryInput(storyId: 'story-id'),
        throwsA(
          argumentErrorWithMessage(
            'at least one update field must be provided',
          ),
        ),
      );
    });

    test('shouldRejectNullTitle', () {
      expect(
        () => UpdateStoryInput(
          storyId: 'story-id',
          title: const StoryUpdateField<String>.provided(null),
        ),
        throwsA(argumentErrorWithMessage('title must not be null')),
      );
    });

    test('shouldRejectEmptyTitle', () {
      expect(
        () => UpdateStoryInput(
          storyId: 'story-id',
          title: const StoryUpdateField<String>.provided(''),
        ),
        throwsA(argumentErrorWithMessage('title must not be blank')),
      );
    });

    test('shouldRejectBlankTitle', () {
      expect(
        () => UpdateStoryInput(
          storyId: 'story-id',
          title: const StoryUpdateField<String>.provided('   '),
        ),
        throwsA(argumentErrorWithMessage('title must not be blank')),
      );
    });

    test('shouldPreserveBlankDescription', () {
      final input = UpdateStoryInput(
        storyId: 'story-id',
        description: const StoryUpdateField<String>.provided('   '),
      );

      expect(input.description.value, '   ');
    });

    test('shouldNotNormalizeTextFields', () {
      final input = UpdateStoryInput(
        storyId: ' story-id ',
        title: const StoryUpdateField<String>.provided(' Updated Story '),
        description:
            const StoryUpdateField<String>.provided(' Updated description '),
      );

      expect(input.storyId, ' story-id ');
      expect(input.title.value, ' Updated Story ');
      expect(input.description.value, ' Updated description ');
    });

    test('shouldCompareInputsByValue', () {
      final first = UpdateStoryInput(
        storyId: 'story-id',
        title: const StoryUpdateField<String>.provided('Updated Story'),
      );
      final second = UpdateStoryInput(
        storyId: 'story-id',
        title: const StoryUpdateField<String>.provided('Updated Story'),
      );
      final different = UpdateStoryInput(
        storyId: 'story-id',
        description:
            const StoryUpdateField<String>.provided('Updated description'),
      );

      expect(first, second);
      expect(first, isNot(different));
      expect(first.hashCode, second.hashCode);
    });

    test('shouldUseSafeToString', () {
      final input = UpdateStoryInput(
        storyId: 'story-id',
        title: const StoryUpdateField<String>.provided('Updated Story'),
      );

      expect(input.toString(), 'UpdateStoryInput');
      expect(input.toString(), isNot(contains('story-id')));
      expect(input.toString(), isNot(contains('Updated Story')));
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
