import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';

void main() {
  group('StoryFailure', () {
    test('shouldCreateAllStoryFailureVariants', () {
      const failures = <StoryFailure>[
        StoryValidationFailure(),
        StoryUnauthorized(),
        StoryNotFound(),
        StoryNetworkUnavailable(),
        StoryRequestTimedOut(),
        StoryServerFailure(),
        UnknownStoryFailure(),
      ];

      expect(failures, hasLength(7));
    });

    test('shouldCompareSameFailureTypesAsEqual', () {
      expect(const StoryNotFound(), const StoryNotFound());
      expect(const StoryNetworkUnavailable(), const StoryNetworkUnavailable());
      expect(const UnknownStoryFailure(), const UnknownStoryFailure());
    });

    test('shouldCompareDifferentFailureTypesAsNotEqual', () {
      expect(const StoryNotFound(), isNot(const StoryUnauthorized()));
      expect(const StoryServerFailure(), isNot(const StoryRequestTimedOut()));
      expect(const StoryValidationFailure(), isNot(const UnknownStoryFailure()));
    });

    test('shouldProduceStableHashCodeForSameFailureType', () {
      expect(
        const StoryNotFound().hashCode,
        const StoryNotFound().hashCode,
      );
      expect(
        const UnknownStoryFailure().hashCode,
        const UnknownStoryFailure().hashCode,
      );
    });

    test('shouldExposeOnlySafeFailureTypeInToString', () {
      const failure = StoryNotFound();

      expect(failure.toString(), 'StoryNotFound');
      expect(failure.toString(), isNot(contains('story-id')));
      expect(failure.toString(), isNot(contains('user-id')));
      expect(failure.toString(), isNot(contains('token')));
      expect(failure.toString(), isNot(contains('Dio')));
      expect(failure.toString(), isNot(contains('HTTP')));
      expect(failure.toString(), isNot(contains('response body')));
    });
  });
}
