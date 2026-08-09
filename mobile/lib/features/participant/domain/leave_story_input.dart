final class LeaveStoryInput {
  factory LeaveStoryInput({
    required String storyId,
  }) {
    if (storyId.trim().isEmpty) {
      throw ArgumentError('storyId must not be blank');
    }

    return LeaveStoryInput._(storyId: storyId);
  }

  const LeaveStoryInput._({
    required this.storyId,
  });

  final String storyId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LeaveStoryInput && storyId == other.storyId;
  }

  @override
  int get hashCode => storyId.hashCode;

  @override
  String toString() => 'LeaveStoryInput';
}
