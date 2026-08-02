import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';

void main() {
  group('StoryApplicationException', () {
    test('shouldExposeStoryFailure', () {
      const exception = StoryApplicationException(StoryNotFound());

      expect(exception.failure, const StoryNotFound());
    });

    test('shouldUseSafeToString', () {
      const exception = StoryApplicationException(StoryNotFound());

      expect(exception.toString(), 'StoryApplicationException');
    });

    test('shouldNotExposeTokenStoryIdOrInfrastructureDetails', () {
      const sensitiveValues = <String>[
        'story-id',
        'user-id',
        'signed-access-token',
        'raw-refresh-token',
        'Authorization',
        'DioException',
        'StoryRemoteNotFoundException',
        'response body',
        '404',
      ];
      const exception = StoryApplicationException(StoryNotFound());

      for (final value in sensitiveValues) {
        expect(exception.toString(), isNot(contains(value)));
      }
    });
  });
}
