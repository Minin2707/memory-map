import 'package:memory_map/features/story/domain/story_role.dart';

final class CreateInviteInput {
  factory CreateInviteInput({
    required String storyId,
    required StoryRole targetRole,
  }) {
    if (storyId.trim().isEmpty) {
      throw ArgumentError('storyId must not be blank');
    }

    if (targetRole == StoryRole.owner) {
      throw ArgumentError('targetRole must not be owner');
    }

    return CreateInviteInput._(
      storyId: storyId,
      targetRole: targetRole,
    );
  }

  const CreateInviteInput._({
    required this.storyId,
    required this.targetRole,
  });

  final String storyId;
  final StoryRole targetRole;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CreateInviteInput &&
            storyId == other.storyId &&
            targetRole == other.targetRole;
  }

  @override
  int get hashCode => Object.hash(storyId, targetRole);

  @override
  String toString() => 'CreateInviteInput';
}
