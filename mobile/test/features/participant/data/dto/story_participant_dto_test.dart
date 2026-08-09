import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/participant/data/dto/story_participant_dto.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/story/domain/story_role.dart';

void main() {
  group('StoryParticipantDto', () {
    test('shouldParseParticipant', () {
      final participant = StoryParticipantDto.fromJson(
        validParticipantJson(),
      );

      expect(participant.userId, 'user-id');
      expect(participant.displayName, 'Anna');
      expect(participant.avatarUrl, 'https://cdn.memorymap.app/avatar.png');
      expect(participant.role, StoryRole.owner);
      expect(participant.joinedAt, DateTime.parse('2026-08-09T10:00:00Z'));
    });

    test('shouldParseAllBackendRoles', () {
      expect(parseRole('OWNER'), StoryRole.owner);
      expect(parseRole('CO_OWNER'), StoryRole.coOwner);
      expect(parseRole('EDITOR'), StoryRole.editor);
      expect(parseRole('VIEWER'), StoryRole.viewer);
    });

    test('shouldAllowNullAvatarUrl', () {
      final participant = StoryParticipantDto.fromJson(
        validParticipantJson(avatarUrl: null),
      );

      expect(participant.avatarUrl, isNull);
    });

    test('shouldMapUtcTimestampToDomain', () {
      final participant = StoryParticipantDto.fromJson(
        validParticipantJson(joinedAt: '2026-08-09T10:00:00Z'),
      ).toDomain();

      expect(
        participant,
        StoryParticipant(
          userId: 'user-id',
          displayName: 'Anna',
          avatarUrl: 'https://cdn.memorymap.app/avatar.png',
          role: StoryRole.owner,
          joinedAt: DateTime.parse('2026-08-09T10:00:00Z'),
        ),
      );
      expect(participant.joinedAt.isUtc, isTrue);
    });

    test('shouldMapOffsetTimestampToUtcDomain', () {
      final participant = StoryParticipantDto.fromJson(
        validParticipantJson(joinedAt: '2026-08-09T13:00:00+03:00'),
      ).toDomain();

      expect(participant.joinedAt, DateTime.parse('2026-08-09T10:00:00Z'));
      expect(participant.joinedAt.isUtc, isTrue);
    });

    test('shouldNotNormalizeTextFields', () {
      final participant = StoryParticipantDto.fromJson(
        <String, Object?>{
          ...validParticipantJson(),
          'userId': ' user-id ',
          'displayName': ' Anna ',
          'avatarUrl': ' https://cdn.memorymap.app/avatar.png ',
        },
      ).toDomain();

      expect(participant.userId, ' user-id ');
      expect(participant.displayName, ' Anna ');
      expect(participant.avatarUrl, ' https://cdn.memorymap.app/avatar.png ');
    });

    test('shouldIgnoreExtraFields', () {
      final participant = StoryParticipantDto.fromJson(
        <String, Object?>{
          ...validParticipantJson(),
          'ownerId': 'owner-id',
          'token': 'raw-token',
        },
      );

      expect(participant.userId, 'user-id');
      expect(participant.role, StoryRole.owner);
    });

    test('shouldRejectNonMapParticipant', () {
      expectMalformed(() => StoryParticipantDto.fromJson(<Object?>[]));
    });

    test('shouldRejectMissingRequiredFields', () {
      for (final key in <String>[
        'userId',
        'displayName',
        'role',
        'joinedAt',
      ]) {
        final json = validParticipantJson()..remove(key);

        expectMalformed(() => StoryParticipantDto.fromJson(json));
      }
    });

    test('shouldRejectWrongRuntimeTypes', () {
      expectMalformed(
        () => StoryParticipantDto.fromJson(
          <String, Object?>{
            ...validParticipantJson(),
            'userId': 123,
          },
        ),
      );
      expectMalformed(
        () => StoryParticipantDto.fromJson(
          <String, Object?>{
            ...validParticipantJson(),
            'displayName': 123,
          },
        ),
      );
      expectMalformed(
        () => StoryParticipantDto.fromJson(
          <String, Object?>{
            ...validParticipantJson(),
            'avatarUrl': 123,
          },
        ),
      );
      expectMalformed(
        () => StoryParticipantDto.fromJson(
          <String, Object?>{
            ...validParticipantJson(),
            'role': 123,
          },
        ),
      );
      expectMalformed(
        () => StoryParticipantDto.fromJson(
          <String, Object?>{
            ...validParticipantJson(),
            'joinedAt': 123,
          },
        ),
      );
    });

    test('shouldRejectBlankRequiredStrings', () {
      expectMalformed(
        () => StoryParticipantDto.fromJson(
          <String, Object?>{
            ...validParticipantJson(),
            'userId': '   ',
          },
        ),
      );
      expectMalformed(
        () => StoryParticipantDto.fromJson(
          <String, Object?>{
            ...validParticipantJson(),
            'displayName': '   ',
          },
        ),
      );
    });

    test('shouldRejectUnknownRole', () {
      expectMalformed(
        () => StoryParticipantDto.fromJson(
          validParticipantJson(role: 'ADMIN'),
        ),
      );
    });

    test('shouldRejectMalformedDate', () {
      expectMalformed(
        () => StoryParticipantDto.fromJson(
          validParticipantJson(joinedAt: 'not-a-date'),
        ),
      );
    });

    test('shouldExposeEqualityAndHashCode', () {
      final first = StoryParticipantDto.fromJson(validParticipantJson());
      final second = StoryParticipantDto.fromJson(validParticipantJson());

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('shouldExposeSafeToString', () {
      final participant = StoryParticipantDto.fromJson(validParticipantJson());

      expect(participant.toString(), 'StoryParticipantDto');
      expect(participant.toString(), isNot(contains('user-id')));
      expect(participant.toString(), isNot(contains('Anna')));
      expect(participant.toString(), isNot(contains('avatar')));
      expect(participant.toString(), isNot(contains('token')));
    });
  });
}

StoryRole parseRole(String role) {
  return StoryParticipantDto.fromJson(
    validParticipantJson(role: role),
  ).role;
}

Map<String, Object?> validParticipantJson({
  String role = 'OWNER',
  Object? avatarUrl = 'https://cdn.memorymap.app/avatar.png',
  String joinedAt = '2026-08-09T10:00:00Z',
}) {
  return <String, Object?>{
    'userId': 'user-id',
    'displayName': 'Anna',
    'avatarUrl': avatarUrl,
    'role': role,
    'joinedAt': joinedAt,
  };
}

void expectMalformed(Object? Function() body) {
  expect(
    body,
    throwsA(
      isA<FormatException>().having(
        (error) => error.message,
        'message',
        'Malformed participant response',
      ),
    ),
  );
}
