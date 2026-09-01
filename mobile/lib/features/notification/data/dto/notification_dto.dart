import 'package:memory_map/features/notification/domain/notification_item.dart';

final class NotificationDto {
  factory NotificationDto.fromJson(Object? json) {
    final map = notificationRequiredRootMap(json);

    return NotificationDto(
      id: notificationRequiredString(map, 'id'),
      type: notificationTypeFromJson(notificationRequiredString(map, 'type')),
      actor: NotificationActorDto.fromJson(
        notificationRequiredValue(map, 'actor'),
      ),
      story: NotificationStoryReferenceDto.fromNullableJson(
        notificationRequiredNullableValue(map, 'story'),
      ),
      memory: NotificationMemoryReferenceDto.fromNullableJson(
        notificationRequiredNullableValue(map, 'memory'),
      ),
      createdAt: notificationRequiredDateTime(map, 'createdAt'),
      read: notificationRequiredBool(map, 'read'),
    );
  }

  NotificationDto({
    required this.id,
    required this.type,
    required this.actor,
    required this.story,
    required this.memory,
    required this.createdAt,
    required this.read,
  }) {
    try {
      toDomain();
    } on Object {
      throw const FormatException('Malformed notification response');
    }
  }

  final String id;
  final NotificationType type;
  final NotificationActorDto actor;
  final NotificationStoryReferenceDto? story;
  final NotificationMemoryReferenceDto? memory;
  final DateTime createdAt;
  final bool read;

  NotificationItem toDomain() {
    return NotificationItem(
      id: id,
      type: type,
      actor: actor.toDomain(),
      story: story?.toDomain(),
      memory: memory?.toDomain(),
      createdAt: createdAt,
      read: read,
    );
  }
}

final class NotificationActorDto {
  factory NotificationActorDto.fromJson(Object? json) {
    final map = notificationRequiredRootMap(json);

    return NotificationActorDto(
      userId: notificationRequiredString(map, 'userId'),
      displayName: notificationRequiredString(map, 'displayName'),
      avatarUrl: notificationOptionalString(map, 'avatarUrl'),
    );
  }

  const NotificationActorDto({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;

  NotificationActor toDomain() {
    return NotificationActor(
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
  }
}

final class NotificationStoryReferenceDto {
  factory NotificationStoryReferenceDto.fromJson(Object? json) {
    final map = notificationRequiredRootMap(json);

    return NotificationStoryReferenceDto(
      storyId: notificationOptionalString(map, 'storyId'),
      title: notificationOptionalString(map, 'title'),
    );
  }

  static NotificationStoryReferenceDto? fromNullableJson(Object? json) {
    if (json == null) {
      return null;
    }

    return NotificationStoryReferenceDto.fromJson(json);
  }

  const NotificationStoryReferenceDto({
    required this.storyId,
    required this.title,
  });

  final String? storyId;
  final String? title;

  NotificationStoryReference toDomain() {
    return NotificationStoryReference(
      storyId: storyId,
      title: title,
    );
  }
}

final class NotificationMemoryReferenceDto {
  factory NotificationMemoryReferenceDto.fromJson(Object? json) {
    final map = notificationRequiredRootMap(json);

    return NotificationMemoryReferenceDto(
      memoryId: notificationOptionalString(map, 'memoryId'),
      title: notificationOptionalString(map, 'title'),
    );
  }

  static NotificationMemoryReferenceDto? fromNullableJson(Object? json) {
    if (json == null) {
      return null;
    }

    return NotificationMemoryReferenceDto.fromJson(json);
  }

  const NotificationMemoryReferenceDto({
    required this.memoryId,
    required this.title,
  });

  final String? memoryId;
  final String? title;

  NotificationMemoryReference toDomain() {
    return NotificationMemoryReference(
      memoryId: memoryId,
      title: title,
    );
  }
}

NotificationType notificationTypeFromJson(String value) {
  return switch (value) {
    'PARTICIPANT_JOINED' => NotificationType.participantJoined,
    'MEMORY_CREATED' => NotificationType.memoryCreated,
    'PHOTOS_ADDED' => NotificationType.photosAdded,
    _ => throw const FormatException('Malformed notification response'),
  };
}

Map<Object?, Object?> notificationRequiredRootMap(Object? json) {
  if (json is! Map) {
    throw const FormatException('Malformed notification response');
  }

  return json.cast<Object?, Object?>();
}

Object? notificationRequiredValue(Map<Object?, Object?> json, String key) {
  if (!json.containsKey(key) || json[key] == null) {
    throw const FormatException('Malformed notification response');
  }

  return json[key];
}

Object? notificationRequiredNullableValue(
  Map<Object?, Object?> json,
  String key,
) {
  if (!json.containsKey(key)) {
    throw const FormatException('Malformed notification response');
  }

  return json[key];
}

String notificationRequiredString(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw const FormatException('Malformed notification response');
  }

  return value;
}

String? notificationOptionalString(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is! String) {
    throw const FormatException('Malformed notification response');
  }

  return value;
}

bool notificationRequiredBool(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw const FormatException('Malformed notification response');
  }

  return value;
}

DateTime notificationRequiredDateTime(
  Map<Object?, Object?> json,
  String key,
) {
  final value = notificationRequiredString(json, key);
  try {
    return DateTime.parse(value);
  } on Object {
    throw const FormatException('Malformed notification response');
  }
}
