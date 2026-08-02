import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/domain/story.dart';

void main() {
  group('Story', () {
    test('shouldCreateStory', () {
      final createdAt = DateTime.utc(2026, 7, 31, 10);
      final updatedAt = DateTime.utc(2026, 7, 31, 11);

      final story = Story(
        id: 'story-id',
        title: 'Our Story',
        description: 'Together since 2021',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      expect(story.id, 'story-id');
      expect(story.title, 'Our Story');
      expect(story.description, 'Together since 2021');
      expect(story.createdAt, createdAt);
      expect(story.updatedAt, updatedAt);
    });

    test('shouldAllowNullDescription', () {
      final story = createStory(description: null);

      expect(story.description, isNull);
    });

    test('shouldAllowBlankDescriptionUntilBackendPolicyChanges', () {
      final story = createStory(description: '   ');

      expect(story.description, '   ');
    });

    test('shouldRejectEmptyId', () {
      expect(
        () => createStory(id: ''),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'id must not be blank',
          ),
        ),
      );
    });

    test('shouldRejectWhitespaceId', () {
      expect(
        () => createStory(id: '   '),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'id must not be blank',
          ),
        ),
      );
    });

    test('shouldRejectEmptyTitle', () {
      expect(
        () => createStory(title: ''),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'title must not be blank',
          ),
        ),
      );
    });

    test('shouldRejectWhitespaceTitle', () {
      expect(
        () => createStory(title: '   '),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'title must not be blank',
          ),
        ),
      );
    });

    test('shouldNormalizeDateTimesToUtc', () {
      final createdAt = DateTime(2026, 7, 31, 10);
      final updatedAt = DateTime(2026, 7, 31, 11);

      final story = createStory(
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      expect(story.createdAt, createdAt.toUtc());
      expect(story.createdAt.isUtc, isTrue);
      expect(story.updatedAt, updatedAt.toUtc());
      expect(story.updatedAt.isUtc, isTrue);
    });

    test('shouldNotNormalizeTextFields', () {
      final story = createStory(
        id: ' story-id ',
        title: ' Our Story ',
        description: ' Together since 2021 ',
      );

      expect(story.id, ' story-id ');
      expect(story.title, ' Our Story ');
      expect(story.description, ' Together since 2021 ');
    });

    test('shouldCompareStoriesByValue', () {
      final first = createStory();
      final second = createStory();
      final different = createStory(id: 'another-story-id');

      expect(first, second);
      expect(first, isNot(different));
    });

    test('shouldProduceStableHashCode', () {
      final first = createStory();
      final second = createStory();

      expect(first.hashCode, second.hashCode);
    });

    test('shouldExposeOnlyStoryFieldsInToString', () {
      final story = createStory();

      expect(
        story.toString(),
        'Story(id: story-id, title: Our Story, '
        'description: Together since 2021, '
        'createdAt: 2026-07-31 10:00:00.000Z, '
        'updatedAt: 2026-07-31 11:00:00.000Z)',
      );
      expect(story.toString(), isNot(contains('ownerId')));
      expect(story.toString(), isNot(contains('userId')));
      expect(story.toString(), isNot(contains('token')));
    });
  });
}

Story createStory({
  String id = 'story-id',
  String title = 'Our Story',
  String? description = 'Together since 2021',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return Story(
    id: id,
    title: title,
    description: description,
    createdAt: createdAt ?? DateTime.utc(2026, 7, 31, 10),
    updatedAt: updatedAt ?? DateTime.utc(2026, 7, 31, 11),
  );
}
