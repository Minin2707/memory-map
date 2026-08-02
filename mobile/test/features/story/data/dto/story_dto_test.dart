import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/data/dto/story_dto.dart';
import 'package:memory_map/features/story/data/dto/user_story_dto.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('StoryDto', () {
    test('shouldParseStory', () {
      final story = StoryDto.fromJson(validStoryJson());

      expect(story.id, 'story-id');
      expect(story.title, 'Our Story');
      expect(story.description, 'Together since 2021');
      expect(story.createdAt, DateTime.parse('2026-01-01T10:00:00.123456Z'));
      expect(story.updatedAt, DateTime.parse('2026-01-10T10:00:00.123456Z'));
    });

    test('shouldAllowNullDescription', () {
      final story = StoryDto.fromJson(
        <String, Object?>{
          ...validStoryJson(),
          'description': null,
        },
      );

      expect(story.description, isNull);
    });

    test('shouldAllowBlankDescription', () {
      final story = StoryDto.fromJson(
        <String, Object?>{
          ...validStoryJson(),
          'description': '   ',
        },
      );

      expect(story.description, '   ');
    });

    test('shouldRejectNonMapStory', () {
      expectMalformed(() => StoryDto.fromJson(<Object?>[]));
    });

    test('shouldRejectMissingStoryId', () {
      final json = validStoryJson()..remove('id');

      expectMalformed(() => StoryDto.fromJson(json));
    });

    test('shouldRejectNonStringStoryId', () {
      expectMalformed(
        () => StoryDto.fromJson(
          <String, Object?>{
            ...validStoryJson(),
            'id': 123,
          },
        ),
      );
    });

    test('shouldRejectBlankStoryId', () {
      expectMalformed(
        () => StoryDto.fromJson(
          <String, Object?>{
            ...validStoryJson(),
            'id': '   ',
          },
        ),
      );
    });

    test('shouldRejectMissingTitle', () {
      final json = validStoryJson()..remove('title');

      expectMalformed(() => StoryDto.fromJson(json));
    });

    test('shouldRejectNonStringTitle', () {
      expectMalformed(
        () => StoryDto.fromJson(
          <String, Object?>{
            ...validStoryJson(),
            'title': 123,
          },
        ),
      );
    });

    test('shouldRejectBlankTitle', () {
      expectMalformed(
        () => StoryDto.fromJson(
          <String, Object?>{
            ...validStoryJson(),
            'title': '   ',
          },
        ),
      );
    });

    test('shouldRejectWrongDescriptionType', () {
      expectMalformed(
        () => StoryDto.fromJson(
          <String, Object?>{
            ...validStoryJson(),
            'description': 123,
          },
        ),
      );
    });

    test('shouldRejectMissingCreatedAt', () {
      final json = validStoryJson()..remove('createdAt');

      expectMalformed(() => StoryDto.fromJson(json));
    });

    test('shouldRejectInvalidUpdatedAt', () {
      expectMalformed(
        () => StoryDto.fromJson(
          <String, Object?>{
            ...validStoryJson(),
            'updatedAt': 'not-a-date',
          },
        ),
      );
    });

    test('shouldMapStoryToUtcDomain', () {
      final story = StoryDto.fromJson(
        <String, Object?>{
          ...validStoryJson(),
          'createdAt': '2026-01-01T13:00:00.123456+03:00',
          'updatedAt': '2026-01-10T13:00:00.123456+03:00',
        },
      ).toDomain();

      expect(
        story,
        Story(
          id: 'story-id',
          title: 'Our Story',
          description: 'Together since 2021',
          createdAt: DateTime.parse('2026-01-01T10:00:00.123456Z'),
          updatedAt: DateTime.parse('2026-01-10T10:00:00.123456Z'),
        ),
      );
      expect(story.createdAt.isUtc, isTrue);
      expect(story.updatedAt.isUtc, isTrue);
    });

    test('shouldNotNormalizeTextFields', () {
      final story = StoryDto.fromJson(
        <String, Object?>{
          ...validStoryJson(),
          'id': ' story-id ',
          'title': ' Our Story ',
          'description': ' Together since 2021 ',
        },
      ).toDomain();

      expect(story.id, ' story-id ');
      expect(story.title, ' Our Story ');
      expect(story.description, ' Together since 2021 ');
    });

    test('shouldExposeSafeToString', () {
      final story = StoryDto.fromJson(validStoryJson());

      expect(story.toString(), 'StoryDto');
      expect(story.toString(), isNot(contains('story-id')));
      expect(story.toString(), isNot(contains('token')));
    });
  });

  group('UserStoryDto', () {
    test('shouldParseUserStory', () {
      final userStory = UserStoryDto.fromJson(validUserStoryJson());

      expect(userStory.story, StoryDto.fromJson(validStoryJson()));
      expect(userStory.role, StoryRole.owner);
    });

    test('shouldParseAllBackendRoles', () {
      expect(parseRole('OWNER'), StoryRole.owner);
      expect(parseRole('CO_OWNER'), StoryRole.coOwner);
      expect(parseRole('EDITOR'), StoryRole.editor);
      expect(parseRole('VIEWER'), StoryRole.viewer);
    });

    test('shouldAllowNullDescription', () {
      final userStory = UserStoryDto.fromJson(
        <String, Object?>{
          ...validUserStoryJson(),
          'description': null,
        },
      );

      expect(userStory.story.description, isNull);
    });

    test('shouldRejectMissingRole', () {
      final json = validUserStoryJson()..remove('role');

      expectMalformed(() => UserStoryDto.fromJson(json));
    });

    test('shouldRejectUnknownRole', () {
      expectMalformed(
        () => UserStoryDto.fromJson(
          <String, Object?>{
            ...validUserStoryJson(),
            'role': 'ADMIN',
          },
        ),
      );
    });

    test('shouldRejectWrongRoleType', () {
      expectMalformed(
        () => UserStoryDto.fromJson(
          <String, Object?>{
            ...validUserStoryJson(),
            'role': 123,
          },
        ),
      );
    });

    test('shouldMapUserStoryToDomain', () {
      final userStory = UserStoryDto.fromJson(validUserStoryJson()).toDomain();

      expect(
        userStory,
        UserStory(
          story: Story(
            id: 'story-id',
            title: 'Our Story',
            description: 'Together since 2021',
            createdAt: DateTime.parse('2026-01-01T10:00:00.123456Z'),
            updatedAt: DateTime.parse('2026-01-10T10:00:00.123456Z'),
          ),
          role: StoryRole.owner,
        ),
      );
    });

    test('shouldExposeSafeToString', () {
      final userStory = UserStoryDto.fromJson(validUserStoryJson());

      expect(userStory.toString(), 'UserStoryDto');
      expect(userStory.toString(), isNot(contains('story-id')));
      expect(userStory.toString(), isNot(contains('token')));
    });
  });
}

StoryRole parseRole(String role) {
  return UserStoryDto.fromJson(
    <String, Object?>{
      ...validUserStoryJson(),
      'role': role,
    },
  ).role;
}

void expectMalformed(Object? Function() callback) {
  expect(callback, throwsA(isA<FormatException>()));
}

Map<String, Object?> validStoryJson() {
  return <String, Object?>{
    'id': 'story-id',
    'title': 'Our Story',
    'description': 'Together since 2021',
    'createdAt': '2026-01-01T10:00:00.123456Z',
    'updatedAt': '2026-01-10T10:00:00.123456Z',
  };
}

Map<String, Object?> validUserStoryJson() {
  return <String, Object?>{
    ...validStoryJson(),
    'role': 'OWNER',
  };
}
