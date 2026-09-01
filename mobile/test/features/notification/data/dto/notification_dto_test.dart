import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/notification/data/dto/notification_dto.dart';
import 'package:memory_map/features/notification/domain/notification_item.dart';

void main() {
  test('shouldMapApiNotificationDtoToDomain', () {
    final notification = NotificationDto.fromJson(
      notificationJson(),
    ).toDomain();

    expect(notification.id, 'notification-1');
    expect(notification.type, NotificationType.memoryCreated);
    expect(notification.actor.userId, 'actor-1');
    expect(notification.actor.displayName, 'Ada Lovelace');
    expect(notification.actor.avatarUrl, '/api/v1/me/avatar');
    expect(notification.story?.storyId, 'story-1');
    expect(notification.story?.title, 'Our story');
    expect(notification.memory?.memoryId, 'memory-1');
    expect(notification.memory?.title, 'First picnic');
    expect(notification.createdAt, DateTime.parse('2026-08-09T10:00:00Z'));
    expect(notification.read, false);
  });

  test('shouldMapAllSupportedNotificationTypes', () {
    expect(
      NotificationDto.fromJson(
        notificationJson(type: 'PARTICIPANT_JOINED'),
      ).toDomain().type,
      NotificationType.participantJoined,
    );
    expect(
      NotificationDto.fromJson(
        notificationJson(type: 'MEMORY_CREATED'),
      ).toDomain().type,
      NotificationType.memoryCreated,
    );
    expect(
      NotificationDto.fromJson(
        notificationJson(type: 'PHOTOS_ADDED'),
      ).toDomain().type,
      NotificationType.photosAdded,
    );
  });

  test('shouldSupportNullableStoryMemoryAndAvatarReferences', () {
    final notification = NotificationDto.fromJson(
      notificationJson(
        avatarUrl: null,
        story: null,
        memory: null,
      ),
    ).toDomain();

    expect(notification.actor.avatarUrl, isNull);
    expect(notification.story, isNull);
    expect(notification.memory, isNull);
  });

  test('shouldRejectUnknownTypeAndMissingStructuredFields', () {
    expect(
      () => NotificationDto.fromJson(
        notificationJson(type: 'COMMENT_CREATED'),
      ),
      throwsFormatException,
    );

    final missingActor = Map<String, Object?>.from(notificationJson())
      ..remove('actor');
    expect(
      () => NotificationDto.fromJson(missingActor),
      throwsFormatException,
    );
  });

  test('shouldIgnoreEmailFieldWhenPresent', () {
    final json = notificationJson(
      actor: <String, Object?>{
        'userId': 'actor-1',
        'displayName': 'Ada Lovelace',
        'avatarUrl': null,
        'email': 'ada@example.test',
      },
    );

    final notification = NotificationDto.fromJson(json).toDomain();

    expect(notification.actor.displayName, 'Ada Lovelace');
    expect(notification.actor.toString(), isNot(contains('email')));
  });
}

Map<String, Object?> notificationJson({
  String id = 'notification-1',
  String type = 'MEMORY_CREATED',
  Object? actor,
  String? avatarUrl = '/api/v1/me/avatar',
  Object? story = const <String, Object?>{
    'storyId': 'story-1',
    'title': 'Our story',
  },
  Object? memory = const <String, Object?>{
    'memoryId': 'memory-1',
    'title': 'First picnic',
  },
  String createdAt = '2026-08-09T10:00:00Z',
  bool read = false,
}) {
  return <String, Object?>{
    'id': id,
    'type': type,
    'actor': actor ??
        <String, Object?>{
          'userId': 'actor-1',
          'displayName': 'Ada Lovelace',
          'avatarUrl': avatarUrl,
        },
    'story': story,
    'memory': memory,
    'createdAt': createdAt,
    'read': read,
  };
}
