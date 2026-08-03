final class CreateInviteInput {
  factory CreateInviteInput({
    required String storyId,
  }) {
    if (storyId.trim().isEmpty) {
      throw ArgumentError('storyId must not be blank');
    }

    return CreateInviteInput._(storyId: storyId);
  }

  const CreateInviteInput._({
    required this.storyId,
  });

  final String storyId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CreateInviteInput && storyId == other.storyId;
  }

  @override
  int get hashCode => storyId.hashCode;

  @override
  String toString() => 'CreateInviteInput';
}
