import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/application/auth_network_providers.dart';
import 'package:memory_map/features/auth/data/storage/auth_session_storage.dart';
import 'package:memory_map/features/auth/data/storage/flutter_secure_auth_session_storage.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_session_store.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/domain/photo_preprocessor.dart';
import 'package:memory_map/features/media/domain/photo_selection_gateway.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/media/domain/selected_photo.dart';
import 'package:memory_map/features/profile/application/profile_application_providers.dart';
import 'package:memory_map/features/profile/application/profile_avatar_notifier.dart';
import 'package:memory_map/features/profile/domain/account_avatar_failure.dart';
import 'package:memory_map/features/profile/domain/account_repository.dart';

void main() {
  group('ProfileAvatarNotifier', () {
    test('shouldIgnorePickerCancelWithoutUploading', () async {
      final context = TestContext();
      final container = context.createContainer();
      await container.read(profileAvatarProvider.future);

      final result = await container
          .read(profileAvatarProvider.notifier)
          .chooseAndUploadAvatar(session);

      expect(result, isFalse);
      expect(context.accountRepository.uploadCalls, 0);
      expect(context.sessionStorage.writtenSession, isNull);
    });

    test('shouldUploadSelectedAvatarAndUpdateSession', () async {
      final context = TestContext()
        ..photoSelectionGateway.selectedPhoto = selectedPhoto();
      context.sessionStore.setSession(session);
      final container = context.createContainer();
      await container.read(profileAvatarProvider.future);

      final result = await container
          .read(profileAvatarProvider.notifier)
          .chooseAndUploadAvatar(session);

      expect(result, isTrue);
      expect(context.accountRepository.uploadCalls, 1);
      expect(context.sessionStorage.writtenSession?.user.hasCustomAvatar,
          isTrue);
      expect(context.sessionStore.session?.user.avatarUrl,
          '/api/v1/me/avatar/1');
    });

    test('shouldBlockDuplicateUploadWhilePending', () async {
      final context = TestContext()
        ..photoSelectionGateway.selectedPhoto = selectedPhoto()
        ..accountRepository.uploadCompleter = Completer<AuthUser>();
      context.sessionStore.setSession(session);
      final container = context.createContainer();
      addTearDown(container.dispose);
      final subscription = container.listen(
        profileAvatarProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(profileAvatarProvider.future);
      final notifier = container.read(profileAvatarProvider.notifier);

      final first = notifier.chooseAndUploadAvatar(session);
      await pumpEventQueue();
      final second = await notifier.chooseAndUploadAvatar(session);

      expect(second, isFalse);
      expect(context.accountRepository.uploadCalls, 1);

      context.accountRepository.uploadCompleter?.complete(customUser);
      expect(await first, isTrue);
    });

    test('shouldDropLateAvatarUploadAfterUserSwitch', () async {
      final context = TestContext()
        ..photoSelectionGateway.selectedPhoto = selectedPhoto()
        ..accountRepository.uploadCompleter = Completer<AuthUser>();
      context.sessionStore.setSession(session);
      final container = context.createContainer();
      addTearDown(container.dispose);
      final subscription = container.listen(
        profileAvatarProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(profileAvatarProvider.future);

      final result = container
          .read(profileAvatarProvider.notifier)
          .chooseAndUploadAvatar(session);
      await pumpEventQueue();
      context.sessionStore.setSession(otherSession);
      context.accountRepository.uploadCompleter?.complete(customUser);

      expect(await result, isFalse);
      expect(context.sessionStorage.writeCalls, 0);
      expect(context.sessionStore.session, otherSession);
    });

    test('shouldRemoveAvatarAndFallbackToGoogleAvatar', () async {
      final context = TestContext();
      context.sessionStore.setSession(customSession);
      final container = context.createContainer();
      await container.read(profileAvatarProvider.future);

      final result = await container
          .read(profileAvatarProvider.notifier)
          .removeAvatar(customSession);

      expect(result, isTrue);
      expect(context.accountRepository.removeCalls, 1);
      expect(context.sessionStore.session?.user.hasCustomAvatar, isFalse);
      expect(context.sessionStore.session?.user.avatarUrl,
          'https://example.com/avatar.png');
    });

    test('shouldDropLateAvatarRemoveAfterLogout', () async {
      final context = TestContext()
        ..accountRepository.removeCompleter = Completer<AuthUser>();
      context.sessionStore.setSession(customSession);
      final container = context.createContainer();
      addTearDown(container.dispose);
      final subscription = container.listen(
        profileAvatarProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(profileAvatarProvider.future);

      final result = container
          .read(profileAvatarProvider.notifier)
          .removeAvatar(customSession);
      await pumpEventQueue();
      context.sessionStore.clear();
      context.accountRepository.removeCompleter?.complete(googleUser);

      expect(await result, isFalse);
      expect(context.sessionStorage.writeCalls, 0);
      expect(context.sessionStore.session, isNull);
    });

    test('shouldDropLateAvatarRemoveAfterUserSwitch', () async {
      final context = TestContext()
        ..accountRepository.removeCompleter = Completer<AuthUser>();
      context.sessionStore.setSession(customSession);
      final container = context.createContainer();
      addTearDown(container.dispose);
      final subscription = container.listen(
        profileAvatarProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(profileAvatarProvider.future);

      final result = container
          .read(profileAvatarProvider.notifier)
          .removeAvatar(customSession);
      await pumpEventQueue();
      context.sessionStore.setSession(otherSession);
      context.accountRepository.removeCompleter?.complete(googleUser);

      expect(await result, isFalse);
      expect(context.sessionStorage.writeCalls, 0);
      expect(context.sessionStore.session, otherSession);
    });

    test('shouldPublishLiveAvatarWhenSecureStorageWriteFails', () async {
      final context = TestContext()
        ..photoSelectionGateway.selectedPhoto = selectedPhoto()
        ..sessionStorage.failure = const AuthSessionStorageException();
      context.sessionStore.setSession(session);
      final container = context.createContainer();
      await container.read(profileAvatarProvider.future);

      final result = await container
          .read(profileAvatarProvider.notifier)
          .chooseAndUploadAvatar(session);

      expect(result, isFalse);
      expect(context.sessionStore.session?.user.hasCustomAvatar, isTrue);
      expect(context.sessionStore.session?.tokens, session.tokens);
      expect(
        container.read(profileAvatarProvider).asData!.value.failure,
        isA<AccountAvatarLocalPersistenceFailure>(),
      );
    });
  });
}

final class TestContext {
  final accountRepository = FakeAccountRepository();
  final sessionStorage = FakeAuthSessionStorage();
  final sessionStore = FakeAuthSessionStore();
  final photoSelectionGateway = FakePhotoSelectionGateway();
  final photoPreprocessor = FakePhotoPreprocessor();

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        accountRepositoryProvider.overrideWithValue(accountRepository),
        authSessionStorageProvider.overrideWithValue(sessionStorage),
        authSessionStoreProvider.overrideWithValue(sessionStore),
        photoSelectionGatewayProvider.overrideWithValue(photoSelectionGateway),
        photoPreprocessorProvider.overrideWithValue(photoPreprocessor),
      ],
    );
  }
}

final class FakeAccountRepository implements AccountRepository {
  int uploadCalls = 0;
  int removeCalls = 0;
  Completer<AuthUser>? uploadCompleter;
  Completer<AuthUser>? removeCompleter;

  @override
  Future<void> deleteCurrentAccount() {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser> updateDisplayName(String displayName) {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser> uploadCurrentUserAvatar(PreparedPhotoUpload photo) async {
    uploadCalls += 1;
    final completer = uploadCompleter;
    if (completer != null) {
      return completer.future;
    }

    return customUser;
  }

  @override
  Future<AuthUser> removeCurrentUserAvatar() async {
    removeCalls += 1;
    final completer = removeCompleter;
    if (completer != null) {
      return completer.future;
    }

    return googleUser;
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

final class FakePhotoSelectionGateway implements PhotoSelectionGateway {
  SelectedPhoto? selectedPhoto;

  @override
  Future<SelectedPhoto?> selectPhoto() async => selectedPhoto;
}

final class FakePhotoPreprocessor implements PhotoPreprocessor {
  @override
  Future<PreparedPhotoUpload> process(SelectedPhoto photo) async {
    return PreparedPhotoUpload(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      contentType: 'image/jpeg',
    );
  }
}

SelectedPhoto selectedPhoto() {
  return SelectedPhoto(
    readBytes: () async => Uint8List.fromList(<int>[9, 8, 7]),
    declaredContentType: 'image/jpeg',
  );
}

final AuthUser googleUser = AuthUser(
  id: 'user-id',
  displayName: 'Ada Lovelace',
  avatarUrl: 'https://example.com/avatar.png',
);

final AuthUser customUser = AuthUser(
  id: 'user-id',
  displayName: 'Ada Lovelace',
  avatarUrl: '/api/v1/me/avatar/1',
  hasCustomAvatar: true,
);

final AuthSession session = AuthSession(
  user: googleUser,
  tokens: AuthTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  ),
);

final AuthSession customSession = AuthSession(
  user: customUser,
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
