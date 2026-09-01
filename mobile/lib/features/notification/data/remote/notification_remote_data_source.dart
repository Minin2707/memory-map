import 'package:memory_map/features/notification/domain/notification_item.dart';

abstract interface class NotificationRemoteDataSource {
  Future<List<NotificationItem>> getNotifications({int limit = 50});

  Future<int> getUnreadCount();

  Future<void> markRead(String notificationId);

  Future<void> markAllRead();
}
