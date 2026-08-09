final class RemoveStoryParticipantInput {
  factory RemoveStoryParticipantInput({
    required String storyId,
    required String participantUserId,
  }) {
    if (storyId.trim().isEmpty) {
      throw ArgumentError('storyId must not be blank');
    }

    if (participantUserId.trim().isEmpty) {
      throw ArgumentError('participantUserId must not be blank');
    }

    return RemoveStoryParticipantInput._(
      storyId: storyId,
      participantUserId: participantUserId,
    );
  }

  const RemoveStoryParticipantInput._({
    required this.storyId,
    required this.participantUserId,
  });

  final String storyId;
  final String participantUserId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RemoveStoryParticipantInput &&
            storyId == other.storyId &&
            participantUserId == other.participantUserId;
  }

  @override
  int get hashCode => Object.hash(
        storyId,
        participantUserId,
      );

  @override
  String toString() => 'RemoveStoryParticipantInput';
}
