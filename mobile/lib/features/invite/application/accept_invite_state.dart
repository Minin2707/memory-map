import 'package:memory_map/features/invite/domain/invite_failure.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

final class AcceptInviteState {
  const AcceptInviteState({
    this.isAccepting = false,
    this.acceptedStory,
    this.failure,
  });

  final bool isAccepting;
  final UserStory? acceptedStory;
  final InviteFailure? failure;

  bool get hasAcceptedStory => acceptedStory != null;

  AcceptInviteState copyWith({
    bool? isAccepting,
    UserStory? acceptedStory,
    InviteFailure? failure,
    bool clearAcceptedStory = false,
    bool clearFailure = false,
  }) {
    return AcceptInviteState(
      isAccepting: isAccepting ?? this.isAccepting,
      acceptedStory:
          clearAcceptedStory ? null : acceptedStory ?? this.acceptedStory,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AcceptInviteState &&
            isAccepting == other.isAccepting &&
            acceptedStory == other.acceptedStory &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(
        isAccepting,
        acceptedStory,
        failure,
      );

  @override
  String toString() {
    return 'AcceptInviteState(isAccepting: $isAccepting, '
        'hasAcceptedStory: $hasAcceptedStory, failure: $failure)';
  }
}
