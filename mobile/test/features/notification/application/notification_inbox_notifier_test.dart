import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/notification/application/notification_application_exception.dart';
import 'package:memory_map/features/notification/application/notification_application_providers.dart';
import 'package:memory_map/features/notification/application/notification_inbox_notifier.dart';
import 'package:memory_map/features/notification/application/unread_notification_count_notifier.dart';
import 'package:memory_map/features/notification/domain/notification_failure.dart';
import 'package:memory_map/features/notification/domain/notification_item.dart';
import 'package:memory_map/features/notification/domain/notification_repository.dart';

void main() {
  test('shouldLoadInboxAndUnreadCountSeparately', () async {
    final repository = FakeNotificationRepository()
      ..unreadCount = 1
      ..notificationsResult = <NotificationItem>[notificationItem()];
    final container = createContainer(repository);
    addTearDown(container.dispose);

    final inbox = await container.read(notificationInboxProvider.future);
    final unreadCount =
        await container.read(unreadNotificationCountProvider.future);

    expect(inbox.notifications, <NotificationItem>[notificationItem()]);
    expect(unreadCount, 1);
    expect(repository.getNotificationsCalls, 1);
    expect(repository.getUnreadCountCalls, 1);
  });

  test('shouldSkipDuplicateMarkReadForAlreadyReadNotification', () async {
    final repository = FakeNotificationRepository()
      ..notificationsResult = <NotificationItem>[
        notificationItem(read: true),
      ];
    final container = createContainer(repository);
    addTearDown(container.dispose);
    await container.read(notificationInboxProvider.future);

    final result = await container
        .read(notificationInboxProvider.notifier)
        .markRead('notification-1');

    expect(result, true);
    expect(repository.markReadIds, isEmpty);
  });

  test('shouldMarkOneReadAndRefreshAuthoritativeUnreadCount', () async {
    final repository = FakeNotificationRepository()
      ..unreadCount = 1
      ..notificationsResult = <NotificationItem>[notificationItem()];
    final container = createContainer(repository);
    addTearDown(container.dispose);
    await container.read(notificationInboxProvider.future);
    await container.read(unreadNotificationCountProvider.future);

    final result = await container
        .read(notificationInboxProvider.notifier)
        .markRead('notification-1');

    final inbox = container.read(notificationInboxProvider).asData?.value;
    final unreadCount =
        container.read(unreadNotificationCountProvider).asData?.value;
    expect(result, true);
    expect(repository.markReadIds, <String>['notification-1']);
    expect(inbox?.notifications.single.read, true);
    expect(unreadCount, 0);
  });

  test('shouldRestoreInboxStateWhenMarkReadFails', () async {
    final repository = FakeNotificationRepository()
      ..unreadCount = 1
      ..markReadFailure = const NotificationApplicationException(
        NotificationNetworkUnavailable(),
      )
      ..notificationsResult = <NotificationItem>[notificationItem()];
    final container = createContainer(repository);
    addTearDown(container.dispose);
    await container.read(notificationInboxProvider.future);
    await container.read(unreadNotificationCountProvider.future);

    final result = await container
        .read(notificationInboxProvider.notifier)
        .markRead('notification-1');

    final inbox = container.read(notificationInboxProvider).asData?.value;
    expect(result, false);
    expect(inbox?.notifications.single.read, false);
    expect(inbox?.mutationFailure, const NotificationNetworkUnavailable());
  });

  test('shouldMarkAllReadAndSetUnreadCountToZero', () async {
    final repository = FakeNotificationRepository()
      ..unreadCount = 2
      ..notificationsResult = <NotificationItem>[
        notificationItem(id: 'notification-1'),
        notificationItem(id: 'notification-2'),
      ];
    final container = createContainer(repository);
    addTearDown(container.dispose);
    await container.read(notificationInboxProvider.future);
    await container.read(unreadNotificationCountProvider.future);

    final result =
        await container.read(notificationInboxProvider.notifier).markAllRead();

    final inbox = container.read(notificationInboxProvider).asData?.value;
    final unreadCount =
        container.read(unreadNotificationCountProvider).asData?.value;
    expect(result, true);
    expect(repository.markAllReadCalls, 1);
    expect(inbox?.notifications.every((notification) => notification.read),
        true);
    expect(unreadCount, 0);
  });
}

ProviderContainer createContainer(FakeNotificationRepository repository) {
  return ProviderContainer(
    overrides: [
      notificationRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

NotificationItem notificationItem({
  String id = 'notification-1',
  bool read = false,
}) {
  return NotificationItem(
    id: id,
    type: NotificationType.memoryCreated,
    actor: const NotificationActor(
      userId: 'actor-1',
      displayName: 'Ada',
      avatarUrl: null,
    ),
    story: const NotificationStoryReference(
      storyId: 'story-1',
      title: 'Our story',
    ),
    memory: const NotificationMemoryReference(
      memoryId: 'memory-1',
      title: 'First picnic',
    ),
    createdAt: DateTime.utc(2026, 8, 9, 10),
    read: read,
  );
}

final class FakeNotificationRepository implements NotificationRepository {
  int getNotificationsCalls = 0;
  int getUnreadCountCalls = 0;
  int markAllReadCalls = 0;
  int unreadCount = 0;
  List<NotificationItem> notificationsResult = <NotificationItem>[];
  Object? markReadFailure;
  final List<String> markReadIds = <String>[];

  @override
  Future<List<NotificationItem>> getNotifications({int limit = 50}) async {
    getNotificationsCalls += 1;
    return notificationsResult;
  }

  @override
  Future<int> getUnreadCount() async {
    getUnreadCountCalls += 1;
    return unreadCount;
  }

  @override
  Future<void> markRead(String notificationId) async {
    final failure = markReadFailure;
    if (failure != null) {
      throw failure;
    }

    markReadIds.add(notificationId);
    unreadCount = (unreadCount - 1).clamp(0, 999).toInt();
    notificationsResult = notificationsResult
        .map(
          (notification) => notification.id == notificationId
              ? notification.copyWith(read: true)
              : notification,
        )
        .toList();
  }

  @override
  Future<void> markAllRead() async {
    markAllReadCalls += 1;
    unreadCount = 0;
    notificationsResult = notificationsResult
        .map((notification) => notification.copyWith(read: true))
        .toList();
  }
}
