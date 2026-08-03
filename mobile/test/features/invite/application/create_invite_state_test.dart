import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/invite/application/create_invite_state.dart';
import 'package:memory_map/features/invite/domain/invite.dart';
import 'package:memory_map/features/invite/domain/invite_failure.dart';

void main() {
  group('CreateInviteState', () {
    test('shouldStartIdleByDefault', () {
      const state = CreateInviteState();

      expect(state.isCreating, isFalse);
      expect(state.createdInvite, isNull);
      expect(state.hasCreatedInvite, isFalse);
      expect(state.failure, isNull);
    });

    test('shouldCopyValues', () {
      final state = const CreateInviteState().copyWith(
        isCreating: true,
        createdInvite: inviteFixture,
        failure: const InviteServerFailure(),
      );

      expect(state.isCreating, isTrue);
      expect(state.createdInvite, inviteFixture);
      expect(state.hasCreatedInvite, isTrue);
      expect(state.failure, const InviteServerFailure());
    });

    test('shouldClearNullableValues', () {
      final state = CreateInviteState(
        createdInvite: inviteFixture,
        failure: const InviteServerFailure(),
      ).copyWith(
        clearCreatedInvite: true,
        clearFailure: true,
      );

      expect(state.createdInvite, isNull);
      expect(state.hasCreatedInvite, isFalse);
      expect(state.failure, isNull);
    });

    test('shouldSupportEqualityAndHashCode', () {
      final first = CreateInviteState(
        isCreating: true,
        createdInvite: inviteFixture,
        failure: const InviteNetworkUnavailable(),
      );
      final second = CreateInviteState(
        isCreating: true,
        createdInvite: inviteFixture,
        failure: const InviteNetworkUnavailable(),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('shouldHaveSafeToString', () {
      final state = CreateInviteState(createdInvite: inviteFixture);

      expect(
        state.toString(),
        'CreateInviteState(isCreating: false, hasCreatedInvite: true, '
        'failure: null)',
      );
      expect(state.toString(), isNot(contains('story-id')));
      expect(state.toString(), isNot(contains('share-token-123')));
      expect(state.toString(), isNot(contains('memorymap.app')));
      expect(state.toString(), isNot(contains('Dio')));
      expect(state.toString(), isNot(contains('HTTP')));
    });
  });
}

final Invite inviteFixture = Invite(
  inviteLink: Uri.parse('https://app.memorymap.app/invite/share-token-123'),
  expiresAt: DateTime.utc(2026, 2, 9, 10),
);
