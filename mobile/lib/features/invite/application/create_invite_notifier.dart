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
  int _providerGeneration = 0;

  @override
  Future<CreateInviteState> build() async {
    _providerGeneration += 1;
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
    final providerGeneration = _providerGeneration;
    state = AsyncData<CreateInviteState>(creatingState);

    try {
      final invite = await ref.read(inviteRepositoryProvider).createInvite(
            input,
          );
      if (!_isCurrentProviderGeneration(providerGeneration)) {
        return null;
      }

      state = AsyncData<CreateInviteState>(
        creatingState.copyWith(
          isCreating: false,
          createdInvite: invite,
          clearFailure: true,
        ),
      );
      return invite;
    } on InviteApplicationException catch (error) {
      if (!_isCurrentProviderGeneration(providerGeneration)) {
        return null;
      }

      state = AsyncData<CreateInviteState>(
        creatingState.copyWith(
          isCreating: false,
          failure: error.failure,
          clearCreatedInvite: true,
        ),
      );
      return null;
    } on Object catch (error, stackTrace) {
      if (!_isCurrentProviderGeneration(providerGeneration)) {
        return null;
      }

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

  bool _isCurrentProviderGeneration(int generation) {
    return ref.mounted && generation == _providerGeneration;
  }

  CreateInviteState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<CreateInviteState>) {
      return currentState.value;
    }

    return null;
  }
}
