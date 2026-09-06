import 'dart:async';

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

  test('shouldIgnoreDelayedRefreshAfterProviderInvalidation', () async {
    final refreshCompleter = Completer<List<NotificationItem>>();
    final repository = FakeNotificationRepository()
      ..notificationsResult = <NotificationItem>[
        notificationItem(id: 'old-notification'),
    ];
    final container = createContainer(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(notificationInboxProvider, (_, __) {});
    addTearDown(subscription.close);
    await container.read(notificationInboxProvider.future);
    repository
      ..getNotificationsCompleter = refreshCompleter
      ..notificationsResult = <NotificationItem>[
        notificationItem(id: 'new-notification'),
      ];

    final refresh = container
        .read(notificationInboxProvider.notifier)
        .refreshNotifications();
    await pumpEventQueue();
    container.invalidate(notificationInboxProvider);
    await pumpEventQueue();
    await container.read(notificationInboxProvider.future);

    refreshCompleter.complete(<NotificationItem>[
      notificationItem(id: 'stale-notification'),
    ]);
    await refresh;

    final inbox = container.read(notificationInboxProvider).asData?.value;
    expect(inbox?.notifications.single.id, 'new-notification');
  });

  test('shouldIgnoreDelayedMarkReadAfterProviderInvalidation', () async {
    final markReadCompleter = Completer<void>();
    final repository = FakeNotificationRepository()
      ..unreadCount = 1
      ..notificationsResult = <NotificationItem>[notificationItem()]
      ..markReadCompleter = markReadCompleter;
    final container = createContainer(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(notificationInboxProvider, (_, __) {});
    addTearDown(subscription.close);
    await container.read(notificationInboxProvider.future);
    await container.read(unreadNotificationCountProvider.future);
    final unreadCountCallsBeforeMutationCompletion =
        repository.getUnreadCountCalls;

    final result = container
        .read(notificationInboxProvider.notifier)
        .markRead('notification-1');
    await pumpEventQueue();
    repository.notificationsResult = <NotificationItem>[
      notificationItem(id: 'new-notification'),
    ];
    container.invalidate(notificationInboxProvider);
    await pumpEventQueue();
    await container.read(notificationInboxProvider.future);
    markReadCompleter.complete();

    expect(await result, isFalse);
    final inbox = container.read(notificationInboxProvider).asData?.value;
    expect(inbox?.notifications.single.id, 'new-notification');
    expect(inbox?.notifications.single.read, isFalse);
    expect(
      repository.getUnreadCountCalls,
      unreadCountCallsBeforeMutationCompletion,
    );
  });

  test('shouldIgnoreDelayedMarkAllReadAfterProviderInvalidation', () async {
    final markAllReadCompleter = Completer<void>();
    final repository = FakeNotificationRepository()
      ..unreadCount = 1
      ..notificationsResult = <NotificationItem>[notificationItem()]
      ..markAllReadCompleter = markAllReadCompleter;
    final container = createContainer(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(notificationInboxProvider, (_, __) {});
    addTearDown(subscription.close);
    await container.read(notificationInboxProvider.future);
    await container.read(unreadNotificationCountProvider.future);
    final unreadCountCallsBeforeMutationCompletion =
        repository.getUnreadCountCalls;

    final result =
        container.read(notificationInboxProvider.notifier).markAllRead();
    await pumpEventQueue();
    repository.notificationsResult = <NotificationItem>[
      notificationItem(id: 'new-notification'),
    ];
    container.invalidate(notificationInboxProvider);
    await pumpEventQueue();
    await container.read(notificationInboxProvider.future);
    markAllReadCompleter.complete();

    expect(await result, isFalse);
    final inbox = container.read(notificationInboxProvider).asData?.value;
    expect(inbox?.notifications.single.id, 'new-notification');
    expect(inbox?.notifications.single.read, isFalse);
    expect(
      repository.getUnreadCountCalls,
      unreadCountCallsBeforeMutationCompletion,
    );
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
  Completer<List<NotificationItem>>? getNotificationsCompleter;
  Completer<void>? markReadCompleter;
  Completer<void>? markAllReadCompleter;
  Object? markReadFailure;
  final List<String> markReadIds = <String>[];

  @override
  Future<List<NotificationItem>> getNotifications({int limit = 50}) async {
    getNotificationsCalls += 1;
    final completer = getNotificationsCompleter;
    if (completer != null) {
      getNotificationsCompleter = null;
      return completer.future;
    }

    return notificationsResult;
  }

  @override
  Future<int> getUnreadCount() async {
    getUnreadCountCalls += 1;
    return unreadCount;
  }

  @override
  Future<void> markRead(String notificationId) async {
    final completer = markReadCompleter;
    if (completer != null) {
      markReadCompleter = null;
      await completer.future;
    }

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
    final completer = markAllReadCompleter;
    if (completer != null) {
      markAllReadCompleter = null;
      await completer.future;
    }

    markAllReadCalls += 1;
    unreadCount = 0;
    notificationsResult = notificationsResult
        .map((notification) => notification.copyWith(read: true))
        .toList();
  }
}
