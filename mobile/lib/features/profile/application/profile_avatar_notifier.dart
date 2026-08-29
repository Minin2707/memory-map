import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/application/authorized_session_exception.dart';
import 'package:memory_map/features/auth/application/auth_network_providers.dart';
import 'package:memory_map/features/auth/application/auth_notifier.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';
import 'package:memory_map/features/media/application/media_application_exception.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';
import 'package:memory_map/features/profile/application/account_avatar_exception.dart';
import 'package:memory_map/features/profile/application/profile_application_providers.dart';
import 'package:memory_map/features/profile/application/profile_avatar_state.dart';
import 'package:memory_map/features/profile/domain/account_avatar_failure.dart';

final profileAvatarProvider =
    AsyncNotifierProvider.autoDispose<ProfileAvatarNotifier, ProfileAvatarState>(
  ProfileAvatarNotifier.new,
);

final class ProfileAvatarNotifier extends AsyncNotifier<ProfileAvatarState> {
  @override
  Future<ProfileAvatarState> build() async => const ProfileAvatarState();

  Future<bool> chooseAndUploadAvatar(AuthSession session) async {
    final currentState = state.asData?.value ?? const ProfileAvatarState();
    if (currentState.isBusy) {
      return false;
    }

    state = AsyncData(
      currentState.copyWith(isUploading: true, failure: null),
    );

    try {
      final selected = await ref.read(photoSelectionGatewayProvider)
          .selectPhoto();
      if (selected == null) {
        if (ref.mounted) {
          state = const AsyncData(ProfileAvatarState());
        }
        return false;
      }

      final prepared = await ref.read(photoPreprocessorProvider)
          .process(selected);
      final user = await ref
          .read(accountRepositoryProvider)
          .uploadCurrentUserAvatar(prepared);
      final updatedSession = await _commitUpdatedUser(
        expectedSession: session,
        updatedUser: user,
      );
      if (updatedSession == null) {
        if (ref.mounted) {
          state = const AsyncData(ProfileAvatarState());
        }
        return false;
      }
      _publishUpdatedSession(updatedSession);

      if (ref.mounted) {
        state = const AsyncData(ProfileAvatarState());
      }
      return true;
    } on MediaApplicationException catch (error) {
      if (ref.mounted) {
        state = AsyncData(currentState.copyWith(
          isUploading: false,
          failure: _mapPreprocessingFailure(error.failure),
        ));
      }
      return false;
    } on AccountAvatarApplicationException catch (error) {
      if (ref.mounted) {
        state = AsyncData(currentState.copyWith(
          isUploading: false,
          failure: error.failure,
        ));
      }
      return false;
    }
  }

  Future<bool> removeAvatar(AuthSession session) async {
    final currentState = state.asData?.value ?? const ProfileAvatarState();
    if (currentState.isBusy) {
      return false;
    }

    state = AsyncData(
      currentState.copyWith(isRemoving: true, failure: null),
    );

    try {
      final user = await ref
          .read(accountRepositoryProvider)
          .removeCurrentUserAvatar();
      final updatedSession = await _commitUpdatedUser(
        expectedSession: session,
        updatedUser: user,
      );
      if (updatedSession == null) {
        if (ref.mounted) {
          state = const AsyncData(ProfileAvatarState());
        }
        return false;
      }
      _publishUpdatedSession(updatedSession);

      if (ref.mounted) {
        state = const AsyncData(ProfileAvatarState());
      }
      return true;
    } on AccountAvatarApplicationException catch (error) {
      if (ref.mounted) {
        state = AsyncData(currentState.copyWith(
          isRemoving: false,
          failure: error.failure,
        ));
      }
      return false;
    }
  }

  Future<AuthSession?> _commitUpdatedUser({
    required AuthSession expectedSession,
    required AuthUser updatedUser,
  }) async {
    try {
      return await ref
          .read(authorizedSessionManagerProvider)
          .updateCurrentSessionUserIfStillCurrent(
            expectedSession: expectedSession,
            updatedUser: updatedUser,
          );
    } on AuthorizedSessionPersistenceException {
      throw const AccountAvatarApplicationException(
        AccountAvatarLocalPersistenceFailure(),
      );
    }
  }

  void _publishUpdatedSession(AuthSession session) {
    if (ref.exists(authNotifierProvider)) {
      ref.read(authNotifierProvider.notifier).replaceCurrentSession(session);
    }
  }

  AccountAvatarFailure _mapPreprocessingFailure(MediaFailure failure) {
    return switch (failure) {
      MediaPreprocessingFailure() => const AccountAvatarValidationFailure(),
      _ => const AccountAvatarUnknownFailure(),
    };
  }
}
