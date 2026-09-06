import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/notification/application/notification_application_providers.dart';
import 'package:memory_map/features/notification/application/unread_notification_count_notifier.dart';
import 'package:memory_map/features/notification/domain/notification_item.dart';
import 'package:memory_map/features/notification/domain/notification_repository.dart';

void main() {
  group('UnreadNotificationCountNotifier refresh ordering', () {
    test('shouldKeepNewerRefreshWhenOlderRefreshCompletesLater', () async {
      final olderRefresh = Completer<int>();
      final newerRefresh = Completer<int>();
      final repository = FakeNotificationRepository()..unreadCount = 1;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(unreadNotificationCountProvider.future);
      repository.unreadCountCompleters.addAll(<Completer<int>>[
        olderRefresh,
        newerRefresh,
      ]);
      final notifier = container.read(
        unreadNotificationCountProvider.notifier,
      );

      final older = notifier.refreshUnreadCount();
      await pumpEventQueue();
      final newer = notifier.refreshUnreadCount();
      await pumpEventQueue();
      newerRefresh.complete(3);
      await newer;
      olderRefresh.complete(9);
      await older;

      expect(container.read(unreadNotificationCountProvider).asData?.value, 3);
    });

    test('shouldIgnoreStaleRefreshAfterDecrement', () async {
      final refreshCompleter = Completer<int>();
      final repository = FakeNotificationRepository()..unreadCount = 2;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(unreadNotificationCountProvider.future);
      repository.unreadCountCompleters.add(refreshCompleter);
      final notifier = container.read(
        unreadNotificationCountProvider.notifier,
      );

      final refresh = notifier.refreshUnreadCount();
      await pumpEventQueue();
      notifier.decrementIfPositive();
      refreshCompleter.complete(9);
      await refresh;

      expect(container.read(unreadNotificationCountProvider).asData?.value, 1);
    });

    test('shouldIgnoreStaleRefreshAfterSetZero', () async {
      final refreshCompleter = Completer<int>();
      final repository = FakeNotificationRepository()..unreadCount = 2;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(unreadNotificationCountProvider.future);
      repository.unreadCountCompleters.add(refreshCompleter);
      final notifier = container.read(
        unreadNotificationCountProvider.notifier,
      );

      final refresh = notifier.refreshUnreadCount();
      await pumpEventQueue();
      notifier.setZero();
      refreshCompleter.complete(9);
      await refresh;

      expect(container.read(unreadNotificationCountProvider).asData?.value, 0);
    });

    test('shouldAllowRefreshStartedAfterOptimisticUpdateToPublish', () async {
      final repository = FakeNotificationRepository()..unreadCount = 2;
      final container = createContainer(repository);
      addTearDown(container.dispose);
      await container.read(unreadNotificationCountProvider.future);
      final notifier = container.read(
        unreadNotificationCountProvider.notifier,
      );
      notifier.setZero();
      repository.unreadCount = 4;

      await notifier.refreshUnreadCount();

      expect(container.read(unreadNotificationCountProvider).asData?.value, 4);
    });
  });
}

ProviderContainer createContainer(FakeNotificationRepository repository) {
  return ProviderContainer(
    overrides: [
      notificationRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

final class FakeNotificationRepository implements NotificationRepository {
  int unreadCount = 0;
  final List<Completer<int>> unreadCountCompleters = <Completer<int>>[];

  @override
  Future<List<NotificationItem>> getNotifications({int limit = 50}) {
    throw UnimplementedError();
  }

  @override
  Future<int> getUnreadCount() async {
    if (unreadCountCompleters.isNotEmpty) {
      return unreadCountCompleters.removeAt(0).future;
    }

    return unreadCount;
  }

  @override
  Future<void> markRead(String notificationId) {
    throw UnimplementedError();
  }

  @override
  Future<void> markAllRead() {
    throw UnimplementedError();
  }
}
