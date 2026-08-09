import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/story/domain/story_role.dart';

void main() {
  group('StoryParticipant', () {
    test('shouldCreateParticipant', () {
      final joinedAt = DateTime.utc(2026, 8, 3, 10);

      final participant = StoryParticipant(
        userId: 'user-id',
        displayName: 'Anna',
        avatarUrl: 'https://example.com/avatar.png',
        role: StoryRole.owner,
        joinedAt: joinedAt,
      );

      expect(participant.userId, 'user-id');
      expect(participant.displayName, 'Anna');
      expect(participant.avatarUrl, 'https://example.com/avatar.png');
      expect(participant.role, StoryRole.owner);
      expect(participant.joinedAt, joinedAt);
    });

    test('shouldAllowEveryStoryRole', () {
      for (final role in StoryRole.values) {
        final participant = createParticipant(role: role);

        expect(participant.role, role);
      }
    });

    test('shouldAllowNullAvatarUrl', () {
      final participant = createParticipant(avatarUrl: null);

      expect(participant.avatarUrl, isNull);
      expect(participant.toString(), contains('hasAvatar: false'));
    });

    test('shouldPreserveBlankAvatarUrl', () {
      final participant = createParticipant(avatarUrl: '   ');

      expect(participant.avatarUrl, '   ');
      expect(participant.toString(), contains('hasAvatar: true'));
    });

    test('shouldRejectEmptyUserId', () {
      expect(
        () => createParticipant(userId: ''),
        throwsA(argumentErrorWithMessage('userId must not be blank')),
      );
    });

    test('shouldRejectWhitespaceUserId', () {
      expect(
        () => createParticipant(userId: '   '),
        throwsA(argumentErrorWithMessage('userId must not be blank')),
      );
    });

    test('shouldRejectEmptyDisplayName', () {
      expect(
        () => createParticipant(displayName: ''),
        throwsA(argumentErrorWithMessage('displayName must not be blank')),
      );
    });

    test('shouldRejectWhitespaceDisplayName', () {
      expect(
        () => createParticipant(displayName: '   '),
        throwsA(argumentErrorWithMessage('displayName must not be blank')),
      );
    });

    test('shouldNormalizeJoinedAtToUtc', () {
      final joinedAt = DateTime(2026, 8, 3, 10);

      final participant = createParticipant(joinedAt: joinedAt);

      expect(participant.joinedAt, joinedAt.toUtc());
      expect(participant.joinedAt.isUtc, isTrue);
    });

    test('shouldNotNormalizeTextFields', () {
      final participant = createParticipant(
        userId: ' user-id ',
        displayName: ' Anna ',
        avatarUrl: ' https://example.com/avatar.png ',
      );

      expect(participant.userId, ' user-id ');
      expect(participant.displayName, ' Anna ');
      expect(participant.avatarUrl, ' https://example.com/avatar.png ');
    });

    test('shouldCompareParticipantsByValue', () {
      final first = createParticipant();
      final second = createParticipant();
      final different = createParticipant(userId: 'another-user-id');

      expect(first, second);
      expect(first, isNot(different));
    });

    test('shouldProduceStableHashCode', () {
      final first = createParticipant();
      final second = createParticipant();

      expect(first.hashCode, second.hashCode);
    });

    test('shouldUseSafeToString', () {
      final participant = createParticipant();

      expect(
        participant.toString(),
        'StoryParticipant(role: StoryRole.coOwner, '
        'hasAvatar: true, joinedAt: 2026-08-03 10:00:00.000Z)',
      );
      expect(participant.toString(), isNot(contains('user-id')));
      expect(participant.toString(), isNot(contains('Anna')));
      expect(
        participant.toString(),
        isNot(contains('https://example.com/avatar.png')),
      );
      expect(participant.toString(), isNot(contains('storyId')));
      expect(participant.toString(), isNot(contains('ownerId')));
      expect(participant.toString(), isNot(contains('email')));
      expect(participant.toString(), isNot(contains('googleSubject')));
      expect(participant.toString(), isNot(contains('isCurrentUser')));
      expect(participant.toString(), isNot(contains('permission')));
      expect(participant.toString(), isNot(contains('availableAction')));
    });
  });
}

StoryParticipant createParticipant({
  String userId = 'user-id',
  String displayName = 'Anna',
  String? avatarUrl = 'https://example.com/avatar.png',
  StoryRole role = StoryRole.coOwner,
  DateTime? joinedAt,
}) {
  return StoryParticipant(
    userId: userId,
    displayName: displayName,
    avatarUrl: avatarUrl,
    role: role,
    joinedAt: joinedAt ?? DateTime.utc(2026, 8, 3, 10),
  );
}

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}
