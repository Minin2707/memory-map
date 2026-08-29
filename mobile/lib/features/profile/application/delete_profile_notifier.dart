import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/application/auth_network_providers.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/profile/application/account_deletion_exception.dart';
import 'package:memory_map/features/profile/application/delete_profile_state.dart';
import 'package:memory_map/features/profile/application/profile_application_providers.dart';

final deleteProfileProvider =
    AsyncNotifierProvider.autoDispose<DeleteProfileNotifier, DeleteProfileState>(
  DeleteProfileNotifier.new,
);

final class DeleteProfileNotifier
    extends AsyncNotifier<DeleteProfileState> {
  @override
  Future<DeleteProfileState> build() async => const DeleteProfileState();

  Future<bool> deleteProfile(AuthSession session) async {
    final currentState = state.asData?.value ?? const DeleteProfileState();
    if (currentState.isDeleting) {
      return false;
    }

    final accountRepository = ref.read(accountRepositoryProvider);
    final sessionManager = ref.read(authorizedSessionManagerProvider);

    state = AsyncData(
      currentState.copyWith(isDeleting: true, failure: null),
    );

    try {
      await accountRepository.deleteCurrentAccount();
      await sessionManager.invalidateCurrentSession(session);

      if (ref.mounted) {
        state = const AsyncData(DeleteProfileState());
      }
      return true;
    } on AccountDeletionApplicationException catch (error) {
      if (ref.mounted) {
        state = AsyncData(
          currentState.copyWith(isDeleting: false, failure: error.failure),
        );
      }
      return false;
    }
  }
}
