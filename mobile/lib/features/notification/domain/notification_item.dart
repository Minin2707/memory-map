enum NotificationType {
  participantJoined,
  memoryCreated,
  photosAdded,
}

final class NotificationActor {
  const NotificationActor({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is NotificationActor &&
            userId == other.userId &&
            displayName == other.displayName &&
            avatarUrl == other.avatarUrl;
  }

  @override
  int get hashCode => Object.hash(userId, displayName, avatarUrl);

  @override
  String toString() => 'NotificationActor';
}

final class NotificationStoryReference {
  const NotificationStoryReference({
    required this.storyId,
    required this.title,
  });

  final String? storyId;
  final String? title;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is NotificationStoryReference &&
            storyId == other.storyId &&
            title == other.title;
  }

  @override
  int get hashCode => Object.hash(storyId, title);

  @override
  String toString() => 'NotificationStoryReference';
}

final class NotificationMemoryReference {
  const NotificationMemoryReference({
    required this.memoryId,
    required this.title,
  });

  final String? memoryId;
  final String? title;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is NotificationMemoryReference &&
            memoryId == other.memoryId &&
            title == other.title;
  }

  @override
  int get hashCode => Object.hash(memoryId, title);

  @override
  String toString() => 'NotificationMemoryReference';
}

final class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.actor,
    required this.story,
    required this.memory,
    required this.createdAt,
    required this.read,
  });

  final String id;
  final NotificationType type;
  final NotificationActor actor;
  final NotificationStoryReference? story;
  final NotificationMemoryReference? memory;
  final DateTime createdAt;
  final bool read;

  NotificationItem copyWith({
    bool? read,
  }) {
    return NotificationItem(
      id: id,
      type: type,
      actor: actor,
      story: story,
      memory: memory,
      createdAt: createdAt,
      read: read ?? this.read,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is NotificationItem &&
            id == other.id &&
            type == other.type &&
            actor == other.actor &&
            story == other.story &&
            memory == other.memory &&
            createdAt == other.createdAt &&
            read == other.read;
  }

  @override
  int get hashCode => Object.hash(
        id,
        type,
        actor,
        story,
        memory,
        createdAt,
        read,
      );

  @override
  String toString() => 'NotificationItem(id: $id, type: $type, read: $read)';
}
