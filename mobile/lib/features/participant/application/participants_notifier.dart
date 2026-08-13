import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/participant/application/participant_application_exception.dart';
import 'package:memory_map/features/participant/application/participant_application_providers.dart';
import 'package:memory_map/features/participant/application/participants_state.dart';
import 'package:memory_map/features/participant/domain/leave_story_input.dart';
import 'package:memory_map/features/participant/domain/participant_failure.dart';
import 'package:memory_map/features/participant/domain/remove_story_participant_input.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/participant/domain/story_participant_repository.dart';
import 'package:memory_map/features/story/application/story_summary_reconciler.dart';

final storyParticipantsProvider = AsyncNotifierProvider.family<
    ParticipantsNotifier, ParticipantsState, String>(
  ParticipantsNotifier.new,
  retry: (retryCount, error) => null,
);

final class ParticipantsNotifier extends AsyncNotifier<ParticipantsState> {
  ParticipantsNotifier(this._storyId);

  final String _storyId;

  @override
  Future<ParticipantsState> build() async {
    return _load(_storyId, ref.watch(storyParticipantRepositoryProvider));
  }

  Future<void> retryLoad() async {
    if (_isLoading) {
      return;
    }

    state = const AsyncLoading<ParticipantsState>();
    state = await AsyncValue.guard<ParticipantsState>(() async {
      return _load(_storyId, ref.read(storyParticipantRepositoryProvider));
    });
  }

  Future<void> refreshParticipants() async {
    final currentState = _currentState;
    if (_isLoading ||
        currentState == null ||
        !currentState.isLoaded ||
        currentState.hasActiveOperation) {
      return;
    }

    final refreshingState = currentState.copyWith(
      isRefreshing: true,
      clearRefreshFailure: true,
    );
    state = AsyncData<ParticipantsState>(refreshingState);

    try {
      final participants = await ref
          .read(storyParticipantRepositoryProvider)
          .getParticipants(_storyId);
      state = AsyncData<ParticipantsState>(
        refreshingState.copyWith(
          participants: participants,
          isRefreshing: false,
          clearRefreshFailure: true,
        ),
      );
    } on ParticipantApplicationException catch (error) {
      state = AsyncData<ParticipantsState>(
        refreshingState.copyWith(
          isRefreshing: false,
          refreshFailure: error.failure,
        ),
      );
    } on Object catch (error, stackTrace) {
      state = AsyncData<ParticipantsState>(
        refreshingState.copyWith(isRefreshing: false),
      );
      state = AsyncError<ParticipantsState>(error, stackTrace);
    }
  }

  Future<bool> leaveStory() async {
    final currentState = _currentState;
    if (_isLoading ||
        currentState == null ||
        !currentState.isLoaded ||
        currentState.hasActiveOperation) {
      return false;
    }

    late final LeaveStoryInput input;
    try {
      input = LeaveStoryInput(storyId: _storyId);
    } on ArgumentError {
      state = AsyncData<ParticipantsState>(
        currentState.copyWith(
          leaveFailure: const ParticipantValidationFailure(),
        ),
      );
      return false;
    }

    final leavingState = currentState.copyWith(
      isLeaving: true,
      clearLeaveFailure: true,
    );
    state = AsyncData<ParticipantsState>(leavingState);

    try {
      await ref.read(storyParticipantRepositoryProvider).leaveStory(input);
      ref.read(storySummaryReconcilerProvider).removeStory(_storyId);
      state = AsyncData<ParticipantsState>(
        leavingState.copyWith(
          isLeaving: false,
          clearLeaveFailure: true,
        ),
      );
      return true;
    } on ParticipantApplicationException catch (error) {
      state = AsyncData<ParticipantsState>(
        leavingState.copyWith(
          isLeaving: false,
          leaveFailure: error.failure,
        ),
      );
      return false;
    } on Object catch (error, stackTrace) {
      state = AsyncData<ParticipantsState>(
        leavingState.copyWith(isLeaving: false),
      );
      state = AsyncError<ParticipantsState>(error, stackTrace);
      return false;
    }
  }

  Future<bool> removeParticipant(String participantUserId) async {
    final currentState = _currentState;
    if (_isLoading ||
        currentState == null ||
        !currentState.isLoaded ||
        currentState.hasActiveOperation) {
      return false;
    }

    late final RemoveStoryParticipantInput input;
    try {
      input = RemoveStoryParticipantInput(
        storyId: _storyId,
        participantUserId: participantUserId,
      );
    } on ArgumentError {
      state = AsyncData<ParticipantsState>(
        currentState.copyWith(
          removeFailure: const ParticipantValidationFailure(),
          clearRemovingParticipantUserId: true,
        ),
      );
      return false;
    }

    final removingState = currentState.copyWith(
      removingParticipantUserId: participantUserId,
      clearRemoveFailure: true,
    );
    state = AsyncData<ParticipantsState>(removingState);

    try {
      await ref.read(storyParticipantRepositoryProvider).removeParticipant(
            input,
          );
      await ref
          .read(storySummaryReconcilerProvider)
          .reconcileAuthoritativeStory(_storyId);
      if (!ref.mounted) {
        return false;
      }

      state = AsyncData<ParticipantsState>(
        removingState.copyWith(
          participants: _withoutParticipant(
            removingState.participants,
            participantUserId,
          ),
          clearRemovingParticipantUserId: true,
          clearRemoveFailure: true,
        ),
      );
      return true;
    } on ParticipantApplicationException catch (error) {
      state = AsyncData<ParticipantsState>(
        removingState.copyWith(
          removeFailure: error.failure,
          clearRemovingParticipantUserId: true,
        ),
      );
      return false;
    } on Object catch (error, stackTrace) {
      state = AsyncData<ParticipantsState>(
        removingState.copyWith(clearRemovingParticipantUserId: true),
      );
      state = AsyncError<ParticipantsState>(error, stackTrace);
      return false;
    }
  }

  Future<ParticipantsState> _load(
    String storyId,
    StoryParticipantRepository repository,
  ) async {
    if (storyId.trim().isEmpty) {
      return ParticipantsState(
        loadFailure: const ParticipantValidationFailure(),
      );
    }

    try {
      final participants = await repository.getParticipants(storyId);
      return ParticipantsState(participants: participants);
    } on ParticipantApplicationException catch (error) {
      return ParticipantsState(loadFailure: error.failure);
    }
  }

  List<StoryParticipant> _withoutParticipant(
    List<StoryParticipant> participants,
    String participantUserId,
  ) {
    return participants
        .where((participant) => participant.userId != participantUserId)
        .toList();
  }

  bool get _isLoading => state is AsyncLoading<ParticipantsState>;

  ParticipantsState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<ParticipantsState>) {
      return currentState.value;
    }

    return null;
  }
}
