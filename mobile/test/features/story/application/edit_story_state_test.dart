import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/application/edit_story_state.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';

void main() {
  group('EditStoryState', () {
    test('shouldRepresentInitialIdleState', () {
      const state = EditStoryState();

      expect(state.isSaving, isFalse);
      expect(state.saveFailure, isNull);
    });

    test('shouldRepresentSavingAndSaveFailure', () {
      const state = EditStoryState(
        isSaving: true,
        saveFailure: StoryNetworkUnavailable(),
      );

      expect(state.isSaving, isTrue);
      expect(state.saveFailure, const StoryNetworkUnavailable());
    });

    test('shouldCopyWithUpdatedValuesAndClearFailure', () {
      const initial = EditStoryState(
        isSaving: true,
        saveFailure: StoryRequestTimedOut(),
      );

      final copied = initial.copyWith(
        isSaving: false,
        clearSaveFailure: true,
      );

      expect(copied.isSaving, isFalse);
      expect(copied.saveFailure, isNull);
    });

    test('shouldUseValueSemantics', () {
      const left = EditStoryState(
        saveFailure: StoryServerFailure(),
      );
      const right = EditStoryState(
        saveFailure: StoryServerFailure(),
      );

      expect(left, right);
      expect(left.hashCode, right.hashCode);
    });

    test('shouldNotExposeStoryDetailsThroughToString', () {
      const state = EditStoryState(
        isSaving: true,
        saveFailure: StoryNotFound(),
      );

      final text = state.toString();

      expect(text, isNot(contains('private-story-id')));
      expect(text, isNot(contains('Private title')));
      expect(text, isNot(contains('Private description')));
      expect(text, isNot(contains('accessToken')));
      expect(text, isNot(contains('refreshToken')));
      expect(text, isNot(contains('Dio')));
    });
  });
}
