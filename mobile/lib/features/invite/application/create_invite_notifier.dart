import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/invite/application/create_invite_state.dart';
import 'package:memory_map/features/invite/application/invite_application_exception.dart';
import 'package:memory_map/features/invite/application/invite_application_providers.dart';
import 'package:memory_map/features/invite/domain/create_invite_input.dart';
import 'package:memory_map/features/invite/domain/invite.dart';
import 'package:memory_map/features/invite/domain/invite_failure.dart';
import 'package:memory_map/features/story/domain/story_role.dart';

final createInviteProvider = AsyncNotifierProvider.autoDispose<
    CreateInviteNotifier, CreateInviteState>(
  CreateInviteNotifier.new,
  retry: (retryCount, error) => null,
);

final class CreateInviteNotifier extends AsyncNotifier<CreateInviteState> {
  @override
  Future<CreateInviteState> build() async {
    return const CreateInviteState();
  }

  Future<Invite?> createInvite(String storyId, StoryRole targetRole) async {
    final currentState = _currentState;
    if (_isLoading || currentState == null || currentState.isCreating) {
      return null;
    }

    late final CreateInviteInput input;
    try {
      input = CreateInviteInput(
        storyId: storyId,
        targetRole: targetRole,
      );
    } on ArgumentError {
      state = AsyncData<CreateInviteState>(
        currentState.copyWith(
          isCreating: false,
          failure: const InviteValidationFailure(),
          clearCreatedInvite: true,
        ),
      );
      return null;
    }

    final creatingState = currentState.copyWith(
      isCreating: true,
      clearCreatedInvite: true,
      clearFailure: true,
    );
    state = AsyncData<CreateInviteState>(creatingState);

    try {
      final invite = await ref.read(inviteRepositoryProvider).createInvite(
            input,
          );
      state = AsyncData<CreateInviteState>(
        creatingState.copyWith(
          isCreating: false,
          createdInvite: invite,
          clearFailure: true,
        ),
      );
      return invite;
    } on InviteApplicationException catch (error) {
      state = AsyncData<CreateInviteState>(
        creatingState.copyWith(
          isCreating: false,
          failure: error.failure,
          clearCreatedInvite: true,
        ),
      );
      return null;
    } on Object catch (error, stackTrace) {
      state = AsyncData<CreateInviteState>(
        creatingState.copyWith(
          isCreating: false,
          clearCreatedInvite: true,
        ),
      );
      state = AsyncError<CreateInviteState>(error, stackTrace);
      return null;
    }
  }

  void reset() {
    state = const AsyncData<CreateInviteState>(CreateInviteState());
  }

  bool get _isLoading => state is AsyncLoading<CreateInviteState>;

  CreateInviteState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<CreateInviteState>) {
      return currentState.value;
    }

    return null;
  }
}
