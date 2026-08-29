import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/profile/application/account_avatar_exception.dart';
import 'package:memory_map/features/profile/application/account_deletion_exception.dart';
import 'package:memory_map/features/profile/application/account_display_name_exception.dart';
import 'package:memory_map/features/profile/application/default_account_repository.dart';
import 'package:memory_map/features/profile/data/remote/account_remote_data_source.dart';
import 'package:memory_map/features/profile/data/remote/account_remote_exception.dart';
import 'package:memory_map/features/profile/domain/account_avatar_failure.dart';
import 'package:memory_map/features/profile/domain/account_deletion_failure.dart';
import 'package:memory_map/features/profile/domain/account_display_name_failure.dart';

void main() {
  group('DefaultAccountRepository deleteCurrentAccount', () {
    test('shouldDeleteCurrentAccountThroughRemoteDataSource', () async {
      final remoteDataSource = FakeAccountRemoteDataSource();
      final repository = DefaultAccountRepository(remoteDataSource);

      await repository.deleteCurrentAccount();

      expect(remoteDataSource.deleteCurrentAccountCalls, 1);
    });

    test('shouldMapOwnershipConflict', () async {
      final remoteDataSource = FakeAccountRemoteDataSource()
        ..failure = const AccountRemoteOwnershipConflictException();
      final repository = DefaultAccountRepository(remoteDataSource);

      await expectLater(
        repository.deleteCurrentAccount(),
        throwsA(
          isA<AccountDeletionApplicationException>().having(
            (error) => error.failure,
            'failure',
            isA<AccountDeletionOwnershipConflict>(),
          ),
        ),
      );
    });

    test('shouldMapUnauthorized', () async {
      final remoteDataSource = FakeAccountRemoteDataSource()
        ..failure = const AccountRemoteUnauthorizedException();
      final repository = DefaultAccountRepository(remoteDataSource);

      await expectLater(
        repository.deleteCurrentAccount(),
        throwsA(
          isA<AccountDeletionApplicationException>().having(
            (error) => error.failure,
            'failure',
            isA<AccountDeletionUnauthorized>(),
          ),
        ),
      );
    });

    test('shouldMapRetryableInfrastructureFailures', () async {
      final remoteDataSource = FakeAccountRemoteDataSource()
        ..failure = const AccountRemoteNetworkException();
      final repository = DefaultAccountRepository(remoteDataSource);

      await expectLater(
        repository.deleteCurrentAccount(),
        throwsA(
          isA<AccountDeletionApplicationException>().having(
            (error) => error.failure,
            'failure',
            isA<AccountDeletionNetworkUnavailable>(),
          ),
        ),
      );
    });
  });

  group('DefaultAccountRepository avatar', () {
    test('shouldUploadAvatarThroughRemoteDataSource', () async {
      final remoteDataSource = FakeAccountRemoteDataSource();
      final repository = DefaultAccountRepository(remoteDataSource);

      final user = await repository.uploadCurrentUserAvatar(photo);

      expect(remoteDataSource.uploadCurrentUserAvatarCalls, 1);
      expect(user.hasCustomAvatar, isTrue);
      expect(user.avatarUrl, '/api/v1/me/avatar/1');
    });

    test('shouldRemoveAvatarThroughRemoteDataSource', () async {
      final remoteDataSource = FakeAccountRemoteDataSource();
      final repository = DefaultAccountRepository(remoteDataSource);

      final user = await repository.removeCurrentUserAvatar();

      expect(remoteDataSource.removeCurrentUserAvatarCalls, 1);
      expect(user.hasCustomAvatar, isFalse);
      expect(user.avatarUrl, 'https://example.com/avatar.png');
    });

    test('shouldMapAvatarValidationFailure', () async {
      final remoteDataSource = FakeAccountRemoteDataSource()
        ..failure = const AccountRemoteValidationException();
      final repository = DefaultAccountRepository(remoteDataSource);

      await expectLater(
        repository.uploadCurrentUserAvatar(photo),
        throwsA(
          isA<AccountAvatarApplicationException>().having(
            (error) => error.failure,
            'failure',
            isA<AccountAvatarValidationFailure>(),
          ),
        ),
      );
    });
  });

  group('DefaultAccountRepository updateDisplayName', () {
    test('shouldUpdateDisplayNameThroughRemoteDataSource', () async {
      final remoteDataSource = FakeAccountRemoteDataSource();
      final repository = DefaultAccountRepository(remoteDataSource);

      final user = await repository.updateDisplayName('Анна-Мария');

      expect(remoteDataSource.updateDisplayNameCalls, 1);
      expect(remoteDataSource.updateDisplayNameValue, 'Анна-Мария');
      expect(user.displayName, 'Анна-Мария');
      expect(user.avatarUrl, 'https://example.com/avatar.png');
    });

    test('shouldMapDisplayNameValidationFailure', () async {
      final remoteDataSource = FakeAccountRemoteDataSource()
        ..failure = const AccountRemoteValidationException();
      final repository = DefaultAccountRepository(remoteDataSource);

      await expectLater(
        repository.updateDisplayName(''),
        throwsA(
          isA<AccountDisplayNameApplicationException>().having(
            (error) => error.failure,
            'failure',
            isA<AccountDisplayNameValidationFailure>(),
          ),
        ),
      );
    });

    test('shouldMapDisplayNameUnauthorizedFailure', () async {
      final remoteDataSource = FakeAccountRemoteDataSource()
        ..failure = const AccountRemoteUnauthorizedException();
      final repository = DefaultAccountRepository(remoteDataSource);

      await expectLater(
        repository.updateDisplayName('Ada'),
        throwsA(
          isA<AccountDisplayNameApplicationException>().having(
            (error) => error.failure,
            'failure',
            isA<AccountDisplayNameUnauthorized>(),
          ),
        ),
      );
    });
  });
}

final class FakeAccountRemoteDataSource implements AccountRemoteDataSource {
  int deleteCurrentAccountCalls = 0;
  int updateDisplayNameCalls = 0;
  int uploadCurrentUserAvatarCalls = 0;
  int removeCurrentUserAvatarCalls = 0;
  String? updateDisplayNameValue;
  Object? failure;

  @override
  Future<void> deleteCurrentAccount() async {
    deleteCurrentAccountCalls += 1;

    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<AuthUser> updateDisplayName(String displayName) async {
    updateDisplayNameCalls += 1;
    updateDisplayNameValue = displayName;
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }

    return AuthUser(
      id: 'user-id',
      displayName: displayName,
      avatarUrl: 'https://example.com/avatar.png',
    );
  }

  @override
  Future<AuthUser> uploadCurrentUserAvatar(PreparedPhotoUpload photo) async {
    uploadCurrentUserAvatarCalls += 1;
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }

    return AuthUser(
      id: 'user-id',
      displayName: 'Ada Lovelace',
      avatarUrl: '/api/v1/me/avatar/1',
      hasCustomAvatar: true,
    );
  }

  @override
  Future<AuthUser> removeCurrentUserAvatar() async {
    removeCurrentUserAvatarCalls += 1;
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }

    return AuthUser(
      id: 'user-id',
      displayName: 'Ada Lovelace',
      avatarUrl: 'https://example.com/avatar.png',
    );
  }
}

final photo = PreparedPhotoUpload(
  bytes: Uint8List.fromList(<int>[1, 2, 3]),
  contentType: 'image/jpeg',
);
