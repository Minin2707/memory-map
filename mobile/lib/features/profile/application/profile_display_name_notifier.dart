import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/application/authorized_session_exception.dart';
import 'package:memory_map/features/auth/application/auth_network_providers.dart';
import 'package:memory_map/features/auth/application/auth_notifier.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';
import 'package:memory_map/features/profile/application/account_display_name_exception.dart';
import 'package:memory_map/features/profile/application/profile_application_providers.dart';
import 'package:memory_map/features/profile/application/profile_display_name_state.dart';
import 'package:memory_map/features/profile/domain/account_display_name_failure.dart';

final profileDisplayNameProvider = AsyncNotifierProvider.autoDispose<
    ProfileDisplayNameNotifier, ProfileDisplayNameState>(
  ProfileDisplayNameNotifier.new,
);

final class ProfileDisplayNameNotifier
    extends AsyncNotifier<ProfileDisplayNameState> {
  static const int displayNameMaxLength = 255;

  @override
  Future<ProfileDisplayNameState> build() async {
    return const ProfileDisplayNameState();
  }

  Future<bool> saveDisplayName(
    AuthSession session,
    String rawDisplayName,
  ) async {
    final currentState =
        state.asData?.value ?? const ProfileDisplayNameState();
    if (currentState.isBusy) {
      return false;
    }

    final normalized = rawDisplayName.trim();
    final validationFailure = validate(normalized);
    if (validationFailure != null) {
      state = AsyncData(currentState.copyWith(failure: validationFailure));
      return false;
    }

    if (normalized == session.user.displayName.trim()) {
      state = const AsyncData(ProfileDisplayNameState());
      return true;
    }

    state = AsyncData(currentState.copyWith(
      isSaving: true,
      failure: null,
    ));

    try {
      final user = await ref
          .read(accountRepositoryProvider)
          .updateDisplayName(normalized);
      final updatedSession = await _commitUpdatedUser(
        expectedSession: session,
        updatedUser: user,
      );
      if (updatedSession == null) {
        if (ref.mounted) {
          state = const AsyncData(ProfileDisplayNameState());
        }
        return false;
      }
      _publishUpdatedSession(updatedSession);

      if (ref.mounted) {
        state = const AsyncData(ProfileDisplayNameState());
      }
      return true;
    } on AccountDisplayNameApplicationException catch (error) {
      if (ref.mounted) {
        state = AsyncData(currentState.copyWith(
          isSaving: false,
          failure: error.failure,
        ));
      }
      return false;
    }
  }

  static AccountDisplayNameFailure? validate(String normalizedDisplayName) {
    if (normalizedDisplayName.isEmpty) {
      return const AccountDisplayNameValidationFailure();
    }

    if (normalizedDisplayName.length > displayNameMaxLength) {
      return const AccountDisplayNameValidationFailure();
    }

    if (_containsControlCharacter(normalizedDisplayName)) {
      return const AccountDisplayNameValidationFailure();
    }

    return null;
  }

  static bool _containsControlCharacter(String value) {
    return value.runes.any((codePoint) {
      return codePoint <= 0x1F || codePoint == 0x7F;
    });
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
      throw const AccountDisplayNameApplicationException(
        AccountDisplayNameLocalPersistenceFailure(),
      );
    }
  }

  void _publishUpdatedSession(AuthSession session) {
    if (ref.exists(authNotifierProvider)) {
      ref.read(authNotifierProvider.notifier).replaceCurrentSession(session);
    }
  }
}
