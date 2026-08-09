import 'package:memory_map/features/participant/domain/participant_failure.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';

final class ParticipantsState {
  factory ParticipantsState({
    List<StoryParticipant> participants = const <StoryParticipant>[],
    bool isRefreshing = false,
    bool isLeaving = false,
    String? removingParticipantUserId,
    ParticipantFailure? loadFailure,
    ParticipantFailure? refreshFailure,
    ParticipantFailure? leaveFailure,
    ParticipantFailure? removeFailure,
  }) {
    return ParticipantsState._(
      participants: List<StoryParticipant>.unmodifiable(participants),
      isRefreshing: isRefreshing,
      isLeaving: isLeaving,
      removingParticipantUserId: removingParticipantUserId,
      loadFailure: loadFailure,
      refreshFailure: refreshFailure,
      leaveFailure: leaveFailure,
      removeFailure: removeFailure,
    );
  }

  const ParticipantsState._({
    required this.participants,
    required this.isRefreshing,
    required this.isLeaving,
    required this.removingParticipantUserId,
    required this.loadFailure,
    required this.refreshFailure,
    required this.leaveFailure,
    required this.removeFailure,
  });

  final List<StoryParticipant> participants;
  final bool isRefreshing;
  final bool isLeaving;
  final String? removingParticipantUserId;
  final ParticipantFailure? loadFailure;
  final ParticipantFailure? refreshFailure;
  final ParticipantFailure? leaveFailure;
  final ParticipantFailure? removeFailure;

  bool get hasLoadFailure => loadFailure != null;

  bool get isLoaded => loadFailure == null;

  bool get isRemoving => removingParticipantUserId != null;

  bool get hasActiveOperation => isRefreshing || isLeaving || isRemoving;

  ParticipantsState copyWith({
    List<StoryParticipant>? participants,
    bool? isRefreshing,
    bool? isLeaving,
    String? removingParticipantUserId,
    ParticipantFailure? loadFailure,
    ParticipantFailure? refreshFailure,
    ParticipantFailure? leaveFailure,
    ParticipantFailure? removeFailure,
    bool clearRemovingParticipantUserId = false,
    bool clearLoadFailure = false,
    bool clearRefreshFailure = false,
    bool clearLeaveFailure = false,
    bool clearRemoveFailure = false,
  }) {
    return ParticipantsState(
      participants: participants ?? this.participants,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLeaving: isLeaving ?? this.isLeaving,
      removingParticipantUserId: clearRemovingParticipantUserId
          ? null
          : removingParticipantUserId ?? this.removingParticipantUserId,
      loadFailure: clearLoadFailure ? null : loadFailure ?? this.loadFailure,
      refreshFailure:
          clearRefreshFailure ? null : refreshFailure ?? this.refreshFailure,
      leaveFailure:
          clearLeaveFailure ? null : leaveFailure ?? this.leaveFailure,
      removeFailure:
          clearRemoveFailure ? null : removeFailure ?? this.removeFailure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ParticipantsState &&
            _listEquals(participants, other.participants) &&
            isRefreshing == other.isRefreshing &&
            isLeaving == other.isLeaving &&
            removingParticipantUserId == other.removingParticipantUserId &&
            loadFailure == other.loadFailure &&
            refreshFailure == other.refreshFailure &&
            leaveFailure == other.leaveFailure &&
            removeFailure == other.removeFailure;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(participants),
        isRefreshing,
        isLeaving,
        removingParticipantUserId,
        loadFailure,
        refreshFailure,
        leaveFailure,
        removeFailure,
      );

  @override
  String toString() {
    return 'ParticipantsState(participantCount: ${participants.length}, '
        'isRefreshing: $isRefreshing, isLeaving: $isLeaving, '
        'isRemoving: $isRemoving, hasLoadFailure: ${loadFailure != null}, '
        'hasRefreshFailure: ${refreshFailure != null}, '
        'hasLeaveFailure: ${leaveFailure != null}, '
        'hasRemoveFailure: ${removeFailure != null})';
  }

  static bool _listEquals<T>(List<T> left, List<T> right) {
    if (identical(left, right)) {
      return true;
    }

    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }

    return true;
  }
}
