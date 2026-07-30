import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/application/in_memory_auth_session_store.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';

void main() {
  group('InMemoryAuthSessionStore', () {
    test('shouldStartEmpty', () {
      final store = InMemoryAuthSessionStore();
      addTearDown(store.dispose);

      expect(store.session, isNull);
    });

    test('shouldStoreSession', () {
      final store = InMemoryAuthSessionStore();
      addTearDown(store.dispose);

      store.setSession(session);

      expect(store.session, session);
    });

    test('shouldReplaceSession', () {
      final store = InMemoryAuthSessionStore();
      addTearDown(store.dispose);

      store.setSession(session);
      store.setSession(refreshedSession);

      expect(store.session, refreshedSession);
    });

    test('shouldClearSession', () {
      final store = InMemoryAuthSessionStore();
      addTearDown(store.dispose);

      store.setSession(session);
      store.clear();

      expect(store.session, isNull);
    });

    test('shouldEmitSessionChanges', () {
      final store = InMemoryAuthSessionStore();
      addTearDown(store.dispose);
      final emissions = <AuthSession?>[];
      final subscription = store.changes.listen(emissions.add);
      addTearDown(subscription.cancel);

      store.setSession(session);
      store.setSession(refreshedSession);

      expect(emissions, <AuthSession?>[
        session,
        refreshedSession,
      ]);
    });

    test('shouldEmitClear', () {
      final store = InMemoryAuthSessionStore();
      addTearDown(store.dispose);
      final emissions = <AuthSession?>[];
      final subscription = store.changes.listen(emissions.add);
      addTearDown(subscription.cancel);

      store.setSession(session);
      store.clear();

      expect(emissions, <AuthSession?>[
        session,
        null,
      ]);
    });

    test('shouldUseRedactedToString', () {
      final store = InMemoryAuthSessionStore();
      addTearDown(store.dispose);

      store.setSession(session);

      expect(store.toString(), 'InMemoryAuthSessionStore[REDACTED]');
      expect(store.toString(), isNot(contains('signed-access-token')));
      expect(store.toString(), isNot(contains('raw-refresh-token')));
      expect(store.toString(), isNot(contains('user-id')));
    });

    test('shouldStopEmittingAfterDispose', () {
      final store = InMemoryAuthSessionStore();
      final emissions = <AuthSession?>[];
      final subscription = store.changes.listen(emissions.add);
      addTearDown(subscription.cancel);

      store.dispose();
      store.setSession(session);
      store.clear();

      expect(emissions, isEmpty);
    });
  });
}

final AuthSession session = AuthSession(
  user: AuthUser(
    id: 'user-id',
    displayName: 'Ada Lovelace',
    avatarUrl: 'https://example.com/avatar.png',
  ),
  tokens: AuthTokens(
    accessToken: 'signed-access-token',
    refreshToken: 'raw-refresh-token',
  ),
);

final AuthSession refreshedSession = AuthSession(
  user: session.user,
  tokens: AuthTokens(
    accessToken: 'new-access-token',
    refreshToken: 'new-refresh-token',
  ),
);
