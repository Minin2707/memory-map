import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/notification/application/notification_application_exception.dart';
import 'package:memory_map/features/notification/application/notification_application_providers.dart';
import 'package:memory_map/features/notification/application/notification_inbox_state.dart';
import 'package:memory_map/features/notification/application/unread_notification_count_notifier.dart';
import 'package:memory_map/features/notification/domain/notification_item.dart';

final notificationInboxProvider =
    AsyncNotifierProvider<NotificationInboxNotifier, NotificationInboxState>(
  NotificationInboxNotifier.new,
  retry: (retryCount, error) => null,
);

final class NotificationInboxNotifier
    extends AsyncNotifier<NotificationInboxState> {
  @override
  Future<NotificationInboxState> build() async {
    return _load();
  }

  Future<void> retryLoad() async {
    if (_isLoading) {
      return;
    }

    state = const AsyncLoading<NotificationInboxState>();
    state = await AsyncValue.guard<NotificationInboxState>(_load);
  }

  Future<void> refreshNotifications() async {
    final currentState = _currentState;
    if (_isLoading ||
        currentState == null ||
        currentState.hasLoadFailure ||
        currentState.isRefreshing ||
        currentState.isMutating) {
      return;
    }

    final refreshingState = currentState.copyWith(
      isRefreshing: true,
      clearRefreshFailure: true,
      clearMutationFailure: true,
    );
    state = AsyncData<NotificationInboxState>(refreshingState);

    try {
      final notifications = await ref
          .read(notificationRepositoryProvider)
          .getNotifications(limit: 50);
      state = AsyncData<NotificationInboxState>(
        NotificationInboxState(notifications: notifications),
      );
      await ref
          .read(unreadNotificationCountProvider.notifier)
          .refreshUnreadCount();
    } on NotificationApplicationException catch (error) {
      state = AsyncData<NotificationInboxState>(
        refreshingState.copyWith(
          isRefreshing: false,
          refreshFailure: error.failure,
        ),
      );
    } on Object catch (error, stackTrace) {
      state = AsyncData<NotificationInboxState>(
        refreshingState.copyWith(isRefreshing: false),
      );
      state = AsyncError<NotificationInboxState>(error, stackTrace);
    }
  }

  Future<bool> markRead(String notificationId) async {
    final currentState = _currentState;
    if (_isLoading || currentState == null || currentState.isMutating) {
      return false;
    }

    final index = currentState.notifications.indexWhere(
      (item) => item.id == notificationId,
    );
    if (index < 0) {
      return false;
    }

    final notification = currentState.notifications[index];
    if (notification.read) {
      return true;
    }

    final optimisticNotifications =
        List<NotificationItem>.of(currentState.notifications);
    optimisticNotifications[index] = notification.copyWith(read: true);
    final optimisticState = currentState.copyWith(
      notifications: optimisticNotifications,
      isMutating: true,
      mutatingNotificationId: notificationId,
      clearMutationFailure: true,
    );
    state = AsyncData<NotificationInboxState>(optimisticState);
    ref.read(unreadNotificationCountProvider.notifier).decrementIfPositive();

    try {
      await ref.read(notificationRepositoryProvider).markRead(notificationId);
      state = AsyncData<NotificationInboxState>(
        optimisticState.copyWith(
          isMutating: false,
          clearMutatingNotificationId: true,
        ),
      );
      await ref
          .read(unreadNotificationCountProvider.notifier)
          .refreshUnreadCount();
      return true;
    } on NotificationApplicationException catch (error) {
      state = AsyncData<NotificationInboxState>(
        currentState.copyWith(mutationFailure: error.failure),
      );
      await ref
          .read(unreadNotificationCountProvider.notifier)
          .refreshUnreadCount();
      return false;
    } on Object catch (error, stackTrace) {
      state = AsyncData<NotificationInboxState>(currentState);
      state = AsyncError<NotificationInboxState>(error, stackTrace);
      await ref
          .read(unreadNotificationCountProvider.notifier)
          .refreshUnreadCount();
      return false;
    }
  }

  Future<bool> markAllRead() async {
    final currentState = _currentState;
    final unreadCount = ref.read(unreadNotificationCountProvider).asData?.value;
    if (_isLoading ||
        currentState == null ||
        currentState.isMutating ||
        (!currentState.hasUnread &&
            (unreadCount == null || unreadCount <= 0))) {
      return false;
    }

    final optimisticNotifications = currentState.notifications
        .map((notification) => notification.copyWith(read: true))
        .toList();
    final optimisticState = currentState.copyWith(
      notifications: optimisticNotifications,
      isMutating: true,
      clearMutatingNotificationId: true,
      clearMutationFailure: true,
    );
    state = AsyncData<NotificationInboxState>(optimisticState);
    ref.read(unreadNotificationCountProvider.notifier).setZero();

    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      state = AsyncData<NotificationInboxState>(
        optimisticState.copyWith(isMutating: false),
      );
      await ref
          .read(unreadNotificationCountProvider.notifier)
          .refreshUnreadCount();
      return true;
    } on NotificationApplicationException catch (error) {
      state = AsyncData<NotificationInboxState>(
        currentState.copyWith(mutationFailure: error.failure),
      );
      await ref
          .read(unreadNotificationCountProvider.notifier)
          .refreshUnreadCount();
      return false;
    } on Object catch (error, stackTrace) {
      state = AsyncData<NotificationInboxState>(currentState);
      state = AsyncError<NotificationInboxState>(error, stackTrace);
      await ref
          .read(unreadNotificationCountProvider.notifier)
          .refreshUnreadCount();
      return false;
    }
  }

  Future<NotificationInboxState> _load() async {
    try {
      final notifications = await ref
          .read(notificationRepositoryProvider)
          .getNotifications(limit: 50);
      return NotificationInboxState(notifications: notifications);
    } on NotificationApplicationException catch (error) {
      return NotificationInboxState(loadFailure: error.failure);
    }
  }

  NotificationInboxState? get _currentState => state.asData?.value;

  bool get _isLoading => state.isLoading;
}
