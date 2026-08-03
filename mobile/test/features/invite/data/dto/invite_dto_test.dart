import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/invite/data/dto/invite_dto.dart';
import 'package:memory_map/features/invite/domain/invite.dart';

void main() {
  group('InviteDto', () {
    test('shouldParseInvite', () {
      final invite = InviteDto.fromJson(validInviteJson());

      expect(
        invite.inviteLink,
        'https://app.memorymap.app/invite/share-token-123',
      );
      expect(invite.expiresAt, DateTime.parse('2026-02-09T10:00:00Z'));
    });

    test('shouldIgnoreExtraFields', () {
      final invite = InviteDto.fromJson(
        <String, Object?>{
          ...validInviteJson(),
          'tokenHash': 'hash',
          'inviteId': 'invite-id',
          'storyId': 'story-id',
          'createdBy': 'user-id',
          'usedAt': null,
        },
      );

      expect(
        invite.inviteLink,
        'https://app.memorymap.app/invite/share-token-123',
      );
    });

    test('shouldRejectNonMapInvite', () {
      expectMalformed(() => InviteDto.fromJson(<Object?>[]));
    });

    test('shouldRejectMissingInviteLink', () {
      final json = validInviteJson()..remove('inviteLink');

      expectMalformed(() => InviteDto.fromJson(json));
    });

    test('shouldRejectWrongInviteLinkType', () {
      expectMalformed(
        () => InviteDto.fromJson(
          <String, Object?>{
            ...validInviteJson(),
            'inviteLink': 123,
          },
        ),
      );
    });

    test('shouldRejectBlankInviteLink', () {
      expectMalformed(
        () => InviteDto.fromJson(
          <String, Object?>{
            ...validInviteJson(),
            'inviteLink': '   ',
          },
        ),
      );
    });

    test('shouldRejectMissingExpiresAt', () {
      final json = validInviteJson()..remove('expiresAt');

      expectMalformed(() => InviteDto.fromJson(json));
    });

    test('shouldRejectWrongExpiresAtType', () {
      expectMalformed(
        () => InviteDto.fromJson(
          <String, Object?>{
            ...validInviteJson(),
            'expiresAt': 123,
          },
        ),
      );
    });

    test('shouldRejectInvalidExpiresAt', () {
      expectMalformed(
        () => InviteDto.fromJson(
          <String, Object?>{
            ...validInviteJson(),
            'expiresAt': 'not-a-date',
          },
        ),
      );
    });

    test('shouldMapInviteToUtcDomain', () {
      final invite = InviteDto.fromJson(
        <String, Object?>{
          ...validInviteJson(),
          'expiresAt': '2026-02-09T13:00:00+03:00',
        },
      ).toDomain();

      expect(
        invite,
        Invite(
          inviteLink: Uri.parse(
            'https://app.memorymap.app/invite/share-token-123',
          ),
          expiresAt: DateTime.parse('2026-02-09T10:00:00Z'),
        ),
      );
      expect(invite.expiresAt.isUtc, isTrue);
    });

    test('shouldPreserveExactInviteLink', () {
      final invite = InviteDto.fromJson(
        <String, Object?>{
          ...validInviteJson(),
          'inviteLink':
              'https://app.memorymap.app/invite/share-token-123?source=app',
        },
      ).toDomain();

      expect(
        invite.inviteLink.toString(),
        'https://app.memorymap.app/invite/share-token-123?source=app',
      );
    });

    test('shouldCompareInviteDtosByValue', () {
      final first = InviteDto.fromJson(validInviteJson());
      final second = InviteDto.fromJson(validInviteJson());
      final different = InviteDto.fromJson(
        <String, Object?>{
          ...validInviteJson(),
          'expiresAt': '2026-02-10T10:00:00Z',
        },
      );

      expect(first, second);
      expect(first, isNot(different));
      expect(first.hashCode, second.hashCode);
    });

    test('shouldExposeSafeToString', () {
      final invite = InviteDto.fromJson(validInviteJson());

      expect(invite.toString(), 'InviteDto');
      expect(invite.toString(), isNot(contains('share-token-123')));
      expect(invite.toString(), isNot(contains('tokenHash')));
      expect(invite.toString(), isNot(contains('inviteId')));
      expect(invite.toString(), isNot(contains('storyId')));
    });
  });
}

void expectMalformed(Object? Function() callback) {
  expect(callback, throwsA(isA<FormatException>()));
}

Map<String, Object?> validInviteJson() {
  return <String, Object?>{
    'inviteLink': 'https://app.memorymap.app/invite/share-token-123',
    'expiresAt': '2026-02-09T10:00:00Z',
  };
}
