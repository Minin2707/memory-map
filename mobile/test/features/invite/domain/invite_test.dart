import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/invite/domain/invite.dart';

void main() {
  group('Invite', () {
    test('shouldCreateInvite', () {
      final expiresAt = DateTime.utc(2026, 8, 5, 10);
      final inviteLink = Uri.parse(
        'https://app.memorymap.app/invite/share-token-123',
      );

      final invite = Invite(
        inviteLink: inviteLink,
        expiresAt: expiresAt,
      );

      expect(invite.inviteLink, inviteLink);
      expect(invite.expiresAt, expiresAt);
    });

    test('shouldRejectBlankInviteLink', () {
      expect(
        () => Invite(
          inviteLink: Uri.parse(''),
          expiresAt: DateTime.utc(2026, 8, 5, 10),
        ),
        throwsA(argumentErrorWithMessage('inviteLink must not be blank')),
      );
    });

    test('shouldNormalizeExpiresAtToUtc', () {
      final expiresAt = DateTime(2026, 8, 5, 10);

      final invite = createInvite(expiresAt: expiresAt);

      expect(invite.expiresAt, expiresAt.toUtc());
      expect(invite.expiresAt.isUtc, isTrue);
    });

    test('shouldCompareInvitesByValue', () {
      final first = createInvite();
      final second = createInvite();
      final different = createInvite(
        inviteLink: Uri.parse(
          'https://app.memorymap.app/invite/another-token',
        ),
      );

      expect(first, second);
      expect(first, isNot(different));
    });

    test('shouldProduceStableHashCode', () {
      final first = createInvite();
      final second = createInvite();

      expect(first.hashCode, second.hashCode);
    });

    test('shouldUseSafeToString', () {
      final invite = createInvite();

      expect(
        invite.toString(),
        'Invite(inviteLink: <redacted>, '
        'expiresAt: 2026-08-05 10:00:00.000Z)',
      );
      expect(invite.toString(), isNot(contains('share-token-123')));
      expect(invite.toString(), isNot(contains('tokenHash')));
      expect(invite.toString(), isNot(contains('inviteId')));
      expect(invite.toString(), isNot(contains('storyId')));
      expect(invite.toString(), isNot(contains('createdBy')));
      expect(invite.toString(), isNot(contains('usedAt')));
      expect(invite.toString(), isNot(contains('Dio')));
      expect(invite.toString(), isNot(contains('JSON')));
    });
  });
}

Invite createInvite({
  Uri? inviteLink,
  DateTime? expiresAt,
}) {
  return Invite(
    inviteLink: inviteLink ??
        Uri.parse('https://app.memorymap.app/invite/share-token-123'),
    expiresAt: expiresAt ?? DateTime.utc(2026, 8, 5, 10),
  );
}

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}
