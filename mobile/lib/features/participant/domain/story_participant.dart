import 'package:memory_map/features/story/domain/story_role.dart';

final class StoryParticipant {
  factory StoryParticipant({
    required String userId,
    required String displayName,
    String? avatarUrl,
    required StoryRole role,
    required DateTime joinedAt,
  }) {
    if (userId.trim().isEmpty) {
      throw ArgumentError('userId must not be blank');
    }

    if (displayName.trim().isEmpty) {
      throw ArgumentError('displayName must not be blank');
    }

    return StoryParticipant._(
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      role: role,
      joinedAt: joinedAt.toUtc(),
    );
  }

  const StoryParticipant._({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final StoryRole role;
  final DateTime joinedAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryParticipant &&
            userId == other.userId &&
            displayName == other.displayName &&
            avatarUrl == other.avatarUrl &&
            role == other.role &&
            joinedAt == other.joinedAt;
  }

  @override
  int get hashCode => Object.hash(
        userId,
        displayName,
        avatarUrl,
        role,
        joinedAt,
      );

  @override
  String toString() {
    return 'StoryParticipant(role: $role, '
        'hasAvatar: ${avatarUrl != null}, joinedAt: $joinedAt)';
  }
}
