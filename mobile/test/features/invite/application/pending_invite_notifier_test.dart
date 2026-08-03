import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/invite/application/pending_invite_notifier.dart';
import 'package:memory_map/features/invite/application/pending_invite_state.dart';

void main() {
  group('PendingInviteNotifier', () {
    test('shouldStartEmpty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(pendingInviteProvider), const PendingInviteState());
      expect(container.read(pendingInviteProvider).hasInvite, isFalse);
    });

    test('shouldStoreReplaceAndClearSingleToken', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(pendingInviteProvider.notifier);

      notifier.setToken(firstToken);

      expect(container.read(pendingInviteProvider).rawToken, firstToken);

      notifier.setToken(secondToken);

      expect(container.read(pendingInviteProvider).rawToken, secondToken);

      notifier.clear();

      expect(container.read(pendingInviteProvider), const PendingInviteState());
    });

    test('shouldTakeAndClearToken', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(pendingInviteProvider.notifier);
      notifier.setToken(firstToken);

      final token = notifier.takeToken();

      expect(token, firstToken);
      expect(container.read(pendingInviteProvider).hasInvite, isFalse);
      expect(notifier.takeToken(), isNull);
    });

    test('shouldRejectBlankTokenWithoutLeakingInput', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(pendingInviteProvider.notifier).setToken('   '),
        throwsA(isA<ArgumentError>()),
      );
      expect(container.read(pendingInviteProvider).hasInvite, isFalse);
    });

    test('shouldUseSafeToString', () {
      final state = PendingInviteState(rawToken: firstToken);

      expect(state.toString(), contains('hasInvite: true'));
      expect(state.toString(), isNot(contains(firstToken)));
      expect(const PendingInviteState().toString(), isNot(contains('token')));
    });
  });
}

const firstToken = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const secondToken = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
