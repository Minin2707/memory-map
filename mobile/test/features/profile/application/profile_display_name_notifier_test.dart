import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/application/auth_network_providers.dart';
import 'package:memory_map/features/auth/data/storage/auth_session_storage.dart';
import 'package:memory_map/features/auth/data/storage/flutter_secure_auth_session_storage.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_session_store.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/profile/application/account_display_name_exception.dart';
import 'package:memory_map/features/profile/application/profile_application_providers.dart';
import 'package:memory_map/features/profile/application/profile_display_name_notifier.dart';
import 'package:memory_map/features/profile/domain/account_display_name_failure.dart';
import 'package:memory_map/features/profile/domain/account_repository.dart';

void main() {
  group('ProfileDisplayNameNotifier', () {
    test('shouldTrimDisplayNameAndUpdateStoredLiveSession', () async {
      final context = TestContext();
      context.sessionStore.setSession(session);
      final container = context.createContainer();
      await container.read(profileDisplayNameProvider.future);

      final result = await container
          .read(profileDisplayNameProvider.notifier)
          .saveDisplayName(session, '  Анна-Мария O\'Connor  ');

      expect(result, isTrue);
      expect(context.accountRepository.updateDisplayNameCalls, 1);
      expect(
        context.accountRepository.updateDisplayNameValue,
        'Анна-Мария O\'Connor',
      );
      expect(
        context.sessionStorage.writtenSession?.user.displayName,
        'Анна-Мария O\'Connor',
      );
      expect(
        context.sessionStore.session?.user.displayName,
        'Анна-Мария O\'Connor',
      );
      expect(context.sessionStore.session?.tokens, session.tokens);
    });

    test('shouldPreserveCustomAvatarWhenDisplayNameChanges', () async {
      final context = TestContext()
        ..accountRepository.updatedUser = AuthUser(
          id: 'user-id',
          displayName: 'Grace Hopper',
          avatarUrl: '/api/v1/me/avatar/1',
          hasCustomAvatar: true,
        );
      context.sessionStore.setSession(customAvatarSession);
      final container = context.createContainer();
      await container.read(profileDisplayNameProvider.future);

      final result = await container
          .read(profileDisplayNameProvider.notifier)
          .saveDisplayName(customAvatarSession, 'Grace Hopper');

      expect(result, isTrue);
      expect(context.sessionStorage.writtenSession?.user.displayName,
          'Grace Hopper');
      expect(context.sessionStorage.writtenSession?.user.avatarUrl,
          '/api/v1/me/avatar/1');
      expect(context.sessionStorage.writtenSession?.user.hasCustomAvatar,
          isTrue);
    });

    test('shouldSkipNetworkWhenNormalizedDisplayNameIsUnchanged', () async {
      final context = TestContext();
      final container = context.createContainer();
      await container.read(profileDisplayNameProvider.future);

      final result = await container
          .read(profileDisplayNameProvider.notifier)
          .saveDisplayName(session, '  Ada Lovelace  ');

      expect(result, isTrue);
      expect(context.accountRepository.updateDisplayNameCalls, 0);
      expect(context.sessionStorage.writtenSession, isNull);
      expect(context.sessionStore.session, isNull);
    });

    test('shouldRejectBlankTooLongAndControlCharacterNames', () async {
      final context = TestContext();
      final container = context.createContainer();
      await container.read(profileDisplayNameProvider.future);
      final notifier = container.read(profileDisplayNameProvider.notifier);

      expect(await notifier.saveDisplayName(session, '   '), isFalse);
      expect(
        await notifier.saveDisplayName(
          session,
          List<String>.filled(256, 'a').join(),
        ),
        isFalse,
      );
      expect(await notifier.saveDisplayName(session, 'Ada\nLovelace'), isFalse);
      expect(context.accountRepository.updateDisplayNameCalls, 0);
      expect(
        container.read(profileDisplayNameProvider).asData!.value.failure,
        isA<AccountDisplayNameValidationFailure>(),
      );
    });

    test('shouldBlockDuplicateSaveWhilePending', () async {
      final context = TestContext()
        ..accountRepository.updateDisplayNameCompleter =
            Completer<AuthUser>();
      context.sessionStore.setSession(session);
      final container = context.createContainer();
      addTearDown(container.dispose);
      final subscription = container.listen(
        profileDisplayNameProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(profileDisplayNameProvider.future);
      final notifier = container.read(profileDisplayNameProvider.notifier);

      final first = notifier.saveDisplayName(session, 'Grace Hopper');
      await pumpEventQueue();
      final second = await notifier.saveDisplayName(session, 'Grace Hopper');

      expect(second, isFalse);
      expect(context.accountRepository.updateDisplayNameCalls, 1);

      context.accountRepository.updateDisplayNameCompleter?.complete(
        AuthUser(
          id: 'user-id',
          displayName: 'Grace Hopper',
          avatarUrl: 'https://example.com/avatar.png',
        ),
      );
      expect(await first, isTrue);
    });

    test('shouldDropLateDisplayNameUpdateAfterLogout', () async {
      final context = TestContext()
        ..accountRepository.updateDisplayNameCompleter =
            Completer<AuthUser>();
      context.sessionStore.setSession(session);
      final container = context.createContainer();
      addTearDown(container.dispose);
      final subscription = container.listen(
        profileDisplayNameProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(profileDisplayNameProvider.future);

      final result = container
          .read(profileDisplayNameProvider.notifier)
          .saveDisplayName(session, 'Grace Hopper');
      await pumpEventQueue();
      context.sessionStore.clear();
      context.accountRepository.updateDisplayNameCompleter?.complete(
        AuthUser(
          id: 'user-id',
          displayName: 'Grace Hopper',
          avatarUrl: 'https://example.com/avatar.png',
        ),
      );

      expect(await result, isFalse);
      expect(context.sessionStorage.writeCalls, 0);
      expect(context.sessionStore.session, isNull);
    });

    test('shouldDropLateDisplayNameUpdateAfterUserSwitch', () async {
      final context = TestContext()
        ..accountRepository.updateDisplayNameCompleter =
            Completer<AuthUser>();
      context.sessionStore.setSession(session);
      final container = context.createContainer();
      addTearDown(container.dispose);
      final subscription = container.listen(
        profileDisplayNameProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(profileDisplayNameProvider.future);

      final result = container
          .read(profileDisplayNameProvider.notifier)
          .saveDisplayName(session, 'Grace Hopper');
      await pumpEventQueue();
      context.sessionStore.setSession(otherSession);
      context.accountRepository.updateDisplayNameCompleter?.complete(
        AuthUser(
          id: 'user-id',
          displayName: 'Grace Hopper',
          avatarUrl: 'https://example.com/avatar.png',
        ),
      );

      expect(await result, isFalse);
      expect(context.sessionStorage.writeCalls, 0);
      expect(context.sessionStore.session, otherSession);
    });

    test('shouldKeepTypedRetryStateAndSessionOnBackendFailure', () async {
      final context = TestContext()
        ..accountRepository.failure =
            const AccountDisplayNameApplicationException(
          AccountDisplayNameNetworkUnavailable(),
        );
      final container = context.createContainer();
      await container.read(profileDisplayNameProvider.future);

      final result = await container
          .read(profileDisplayNameProvider.notifier)
          .saveDisplayName(session, 'Grace Hopper');

      expect(result, isFalse);
      expect(context.sessionStorage.writtenSession, isNull);
      expect(context.sessionStore.session, isNull);
      expect(
        container.read(profileDisplayNameProvider).asData!.value.failure,
        isA<AccountDisplayNameNetworkUnavailable>(),
      );
    });

    test('shouldPublishLiveSessionWhenSecureStorageWriteFails', () async {
      final context = TestContext()
        ..sessionStorage.failure = const AuthSessionStorageException();
      context.sessionStore.setSession(session);
      final container = context.createContainer();
      await container.read(profileDisplayNameProvider.future);

      final result = await container
          .read(profileDisplayNameProvider.notifier)
          .saveDisplayName(session, 'Grace Hopper');

      expect(result, isFalse);
      expect(context.accountRepository.updateDisplayNameCalls, 1);
      expect(context.sessionStore.session?.user.displayName, 'Grace Hopper');
      expect(
        container.read(profileDisplayNameProvider).asData!.value.failure,
        isA<AccountDisplayNameLocalPersistenceFailure>(),
      );
    });
  });
}

final class TestContext {
  final accountRepository = FakeAccountRepository();
  final sessionStorage = FakeAuthSessionStorage();
  final sessionStore = FakeAuthSessionStore();

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        accountRepositoryProvider.overrideWithValue(accountRepository),
        authSessionStorageProvider.overrideWithValue(sessionStorage),
        authSessionStoreProvider.overrideWithValue(sessionStore),
      ],
    );
  }
}

final class FakeAccountRepository implements AccountRepository {
  int updateDisplayNameCalls = 0;
  String? updateDisplayNameValue;
  Object? failure;
  AuthUser? updatedUser;
  Completer<AuthUser>? updateDisplayNameCompleter;

  @override
  Future<void> deleteCurrentAccount() {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser> updateDisplayName(String displayName) async {
    updateDisplayNameCalls += 1;
    updateDisplayNameValue = displayName;

    final completer = updateDisplayNameCompleter;
    if (completer != null) {
      return completer.future;
    }

    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }

    return updatedUser ??
        AuthUser(
          id: 'user-id',
          displayName: displayName,
          avatarUrl: 'https://example.com/avatar.png',
        );
  }

  @override
  Future<AuthUser> uploadCurrentUserAvatar(PreparedPhotoUpload photo) {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser> removeCurrentUserAvatar() {
    throw UnimplementedError();
  }
}

final class FakeAuthSessionStorage implements AuthSessionStorage {
  AuthSession? writtenSession;
  int writeCalls = 0;
  Object? failure;

  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async => writtenSession;

  @override
  Future<void> write(AuthSession session) async {
    writeCalls += 1;
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }

    writtenSession = session;
  }
}

final class FakeAuthSessionStore implements AuthSessionStore {
  final controller = StreamController<AuthSession?>.broadcast(sync: true);
  AuthSession? _session;

  @override
  AuthSession? get session => _session;

  @override
  Stream<AuthSession?> get changes => controller.stream;

  @override
  void clear() {
    _session = null;
    controller.add(null);
  }

  @override
  void setSession(AuthSession session) {
    _session = session;
    controller.add(session);
  }
}

final AuthSession session = AuthSession(
  user: AuthUser(
    id: 'user-id',
    displayName: 'Ada Lovelace',
    avatarUrl: 'https://example.com/avatar.png',
  ),
  tokens: AuthTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  ),
);

final AuthSession customAvatarSession = AuthSession(
  user: AuthUser(
    id: 'user-id',
    displayName: 'Ada Lovelace',
    avatarUrl: '/api/v1/me/avatar/1',
    hasCustomAvatar: true,
  ),
  tokens: AuthTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  ),
);

final AuthSession otherSession = AuthSession(
  user: AuthUser(
    id: 'other-user-id',
    displayName: 'Katherine Johnson',
    avatarUrl: 'https://example.com/other-avatar.png',
  ),
  tokens: AuthTokens(
    accessToken: 'other-access-token',
    refreshToken: 'other-refresh-token',
  ),
);
