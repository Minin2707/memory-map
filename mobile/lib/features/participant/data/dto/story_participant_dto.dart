import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/story/domain/story_role.dart';

final class StoryParticipantDto {
  factory StoryParticipantDto.fromJson(Object? json) {
    final map = participantRequiredRootMap(json);

    return StoryParticipantDto(
      userId: participantRequiredString(map, 'userId'),
      displayName: participantRequiredString(map, 'displayName'),
      avatarUrl: participantOptionalString(map, 'avatarUrl'),
      role: participantRequiredRole(map, 'role'),
      joinedAt: participantRequiredDate(map, 'joinedAt'),
    );
  }

  StoryParticipantDto({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
  }) {
    if (userId.trim().isEmpty) {
      throw const FormatException('Malformed participant response');
    }

    if (displayName.trim().isEmpty) {
      throw const FormatException('Malformed participant response');
    }
  }

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final StoryRole role;
  final DateTime joinedAt;

  StoryParticipant toDomain() {
    return StoryParticipant(
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      role: role,
      joinedAt: joinedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryParticipantDto &&
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
  String toString() => 'StoryParticipantDto';
}

Map<Object?, Object?> participantRequiredRootMap(Object? json) {
  if (json is! Map) {
    throw const FormatException('Malformed participant response');
  }

  return json.cast<Object?, Object?>();
}

String participantRequiredString(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw const FormatException('Malformed participant response');
  }

  return value;
}

String? participantOptionalString(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is String) {
    return value;
  }

  throw const FormatException('Malformed participant response');
}

DateTime participantRequiredDate(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw const FormatException('Malformed participant response');
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw const FormatException('Malformed participant response');
  }

  return parsed;
}

StoryRole participantRequiredRole(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw const FormatException('Malformed participant response');
  }

  return switch (value) {
    'OWNER' => StoryRole.owner,
    'CO_OWNER' => StoryRole.coOwner,
    'EDITOR' => StoryRole.editor,
    'VIEWER' => StoryRole.viewer,
    _ => throw const FormatException('Malformed participant response'),
  };
}
