import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/application/auth_network_providers.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';
import 'package:memory_map/features/auth/domain/authorized_session_manager.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/profile/application/account_deletion_exception.dart';
import 'package:memory_map/features/profile/application/delete_profile_notifier.dart';
import 'package:memory_map/features/profile/application/profile_application_providers.dart';
import 'package:memory_map/features/profile/domain/account_deletion_failure.dart';
import 'package:memory_map/features/profile/domain/account_repository.dart';

void main() {
  group('DeleteProfileNotifier', () {
    test('shouldDeleteAccountAndInvalidateCurrentSessionAfterSuccess', () async {
      final repository = FakeAccountRepository();
      final sessionManager = FakeAuthorizedSessionManager();
      final container = createContainer(repository, sessionManager);
      addTearDown(container.dispose);
      await container.read(deleteProfileProvider.future);

      final success = await container
          .read(deleteProfileProvider.notifier)
          .deleteProfile(session);

      expect(success, isTrue);
      expect(repository.deleteCurrentAccountCalls, 1);
      expect(sessionManager.invalidatedSessions, <AuthSession>[session]);
    });

    test('shouldIgnoreDuplicateDeleteWhilePending', () async {
      final deleteCompleter = Completer<void>();
      final repository = FakeAccountRepository()
        ..deleteCompleter = deleteCompleter;
      final sessionManager = FakeAuthorizedSessionManager();
      final container = createContainer(repository, sessionManager);
      addTearDown(container.dispose);
      final subscription = container.listen(
        deleteProfileProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(deleteProfileProvider.future);

      final first = container
          .read(deleteProfileProvider.notifier)
          .deleteProfile(session);
      await pumpEventQueue();
      final second = await container
          .read(deleteProfileProvider.notifier)
          .deleteProfile(session);

      expect(second, isFalse);
      expect(repository.deleteCurrentAccountCalls, 1);

      deleteCompleter.complete();
      expect(await first, isTrue);
    });

    test('shouldKeepSessionWhenOwnershipConflictIsReturned', () async {
      final repository = FakeAccountRepository()
        ..failure = const AccountDeletionApplicationException(
          AccountDeletionOwnershipConflict(),
        );
      final sessionManager = FakeAuthorizedSessionManager();
      final container = createContainer(repository, sessionManager);
      addTearDown(container.dispose);
      await container.read(deleteProfileProvider.future);

      final success = await container
          .read(deleteProfileProvider.notifier)
          .deleteProfile(session);

      expect(success, isFalse);
      expect(sessionManager.invalidatedSessions, isEmpty);
      expect(
        container.read(deleteProfileProvider).asData!.value.failure,
        isA<AccountDeletionOwnershipConflict>(),
      );
    });

    test('shouldNotTreatUnauthorizedFailureAsDeletionSuccess', () async {
      final repository = FakeAccountRepository()
        ..failure = const AccountDeletionApplicationException(
          AccountDeletionUnauthorized(),
        );
      final sessionManager = FakeAuthorizedSessionManager();
      final container = createContainer(repository, sessionManager);
      addTearDown(container.dispose);
      await container.read(deleteProfileProvider.future);

      final success = await container
          .read(deleteProfileProvider.notifier)
          .deleteProfile(session);

      expect(success, isFalse);
      expect(sessionManager.invalidatedSessions, isEmpty);
      expect(
        container.read(deleteProfileProvider).asData!.value.failure,
        isA<AccountDeletionUnauthorized>(),
      );
    });

    test('shouldKeepSessionAndAllowRetryAfterTransientFailure', () async {
      final repository = FakeAccountRepository()
        ..failure = const AccountDeletionApplicationException(
          AccountDeletionNetworkUnavailable(),
        );
      final sessionManager = FakeAuthorizedSessionManager();
      final container = createContainer(repository, sessionManager);
      addTearDown(container.dispose);
      await container.read(deleteProfileProvider.future);

      final failed = await container
          .read(deleteProfileProvider.notifier)
          .deleteProfile(session);
      repository.failure = null;
      final succeeded = await container
          .read(deleteProfileProvider.notifier)
          .deleteProfile(session);

      expect(failed, isFalse);
      expect(succeeded, isTrue);
      expect(repository.deleteCurrentAccountCalls, 2);
      expect(sessionManager.invalidatedSessions, <AuthSession>[session]);
    });
  });
}

ProviderContainer createContainer(
  FakeAccountRepository repository,
  FakeAuthorizedSessionManager sessionManager,
) {
  return ProviderContainer(
    overrides: [
      accountRepositoryProvider.overrideWithValue(repository),
      authorizedSessionManagerProvider.overrideWithValue(sessionManager),
    ],
  );
}

final class FakeAccountRepository implements AccountRepository {
  int deleteCurrentAccountCalls = 0;
  Object? failure;
  Completer<void>? deleteCompleter;

  @override
  Future<void> deleteCurrentAccount() async {
    deleteCurrentAccountCalls += 1;

    final completer = deleteCompleter;
    if (completer != null) {
      return completer.future;
    }

    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<AuthUser> updateDisplayName(String displayName) {
    throw UnimplementedError();
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

final class FakeAuthorizedSessionManager implements AuthorizedSessionManager {
  final List<AuthSession> invalidatedSessions = <AuthSession>[];

  @override
  Future<AuthSession?> getCurrentSession() {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> refreshCurrentSession(AuthSession currentSession) {
    throw UnimplementedError();
  }

  @override
  Future<void> invalidateCurrentSession(AuthSession currentSession) async {
    invalidatedSessions.add(currentSession);
  }

  @override
  Future<AuthSession?> updateCurrentSessionUserIfStillCurrent({
    required AuthSession expectedSession,
    required AuthUser updatedUser,
  }) {
    throw UnimplementedError();
  }
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
