import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/invite/application/accept_invite_state.dart';
import 'package:memory_map/features/invite/application/invite_application_exception.dart';
import 'package:memory_map/features/invite/application/invite_application_providers.dart';
import 'package:memory_map/features/invite/domain/accept_invite_input.dart';
import 'package:memory_map/features/invite/domain/invite_failure.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

final acceptInviteProvider = AsyncNotifierProvider.autoDispose<
    AcceptInviteNotifier, AcceptInviteState>(
  AcceptInviteNotifier.new,
  retry: (retryCount, error) => null,
);

final class AcceptInviteNotifier extends AsyncNotifier<AcceptInviteState> {
  @override
  Future<AcceptInviteState> build() async {
    return const AcceptInviteState();
  }

  Future<UserStory?> acceptInvite(String rawToken) async {
    final currentState = _currentState;
    if (_isLoading || currentState == null || currentState.isAccepting) {
      return null;
    }

    late final AcceptInviteInput input;
    try {
      input = AcceptInviteInput(rawToken: rawToken);
    } on ArgumentError {
      state = AsyncData<AcceptInviteState>(
        currentState.copyWith(
          isAccepting: false,
          failure: const InviteValidationFailure(),
          clearAcceptedStory: true,
        ),
      );
      return null;
    }

    final acceptingState = currentState.copyWith(
      isAccepting: true,
      clearAcceptedStory: true,
      clearFailure: true,
    );
    state = AsyncData<AcceptInviteState>(acceptingState);

    try {
      final userStory = await ref.read(inviteRepositoryProvider).acceptInvite(
            input,
          );
      state = AsyncData<AcceptInviteState>(
        acceptingState.copyWith(
          isAccepting: false,
          acceptedStory: userStory,
          clearFailure: true,
        ),
      );
      return userStory;
    } on InviteApplicationException catch (error) {
      state = AsyncData<AcceptInviteState>(
        acceptingState.copyWith(
          isAccepting: false,
          failure: error.failure,
          clearAcceptedStory: true,
        ),
      );
      return null;
    } on Object catch (error, stackTrace) {
      state = AsyncData<AcceptInviteState>(
        acceptingState.copyWith(
          isAccepting: false,
          clearAcceptedStory: true,
        ),
      );
      state = AsyncError<AcceptInviteState>(error, stackTrace);
      return null;
    }
  }

  void reset() {
    state = const AsyncData<AcceptInviteState>(AcceptInviteState());
  }

  bool get _isLoading => state is AsyncLoading<AcceptInviteState>;

  AcceptInviteState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<AcceptInviteState>) {
      return currentState.value;
    }

    return null;
  }
}
