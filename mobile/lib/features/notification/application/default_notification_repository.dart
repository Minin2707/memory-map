import 'package:memory_map/features/notification/application/notification_application_exception.dart';
import 'package:memory_map/features/notification/data/remote/notification_remote_data_source.dart';
import 'package:memory_map/features/notification/data/remote/notification_remote_exception.dart';
import 'package:memory_map/features/notification/domain/notification_failure.dart';
import 'package:memory_map/features/notification/domain/notification_item.dart';
import 'package:memory_map/features/notification/domain/notification_repository.dart';

final class DefaultNotificationRepository implements NotificationRepository {
  const DefaultNotificationRepository({
    required NotificationRemoteDataSource notificationRemoteDataSource,
  }) : _notificationRemoteDataSource = notificationRemoteDataSource;

  final NotificationRemoteDataSource _notificationRemoteDataSource;

  @override
  Future<List<NotificationItem>> getNotifications({int limit = 50}) async {
    try {
      return await _notificationRemoteDataSource.getNotifications(limit: limit);
    } on NotificationRemoteException catch (exception) {
      throw NotificationApplicationException(
        mapNotificationFailure(exception),
      );
    }
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      return await _notificationRemoteDataSource.getUnreadCount();
    } on NotificationRemoteException catch (exception) {
      throw NotificationApplicationException(
        mapNotificationFailure(exception),
      );
    }
  }

  @override
  Future<void> markRead(String notificationId) async {
    try {
      await _notificationRemoteDataSource.markRead(notificationId);
    } on NotificationRemoteException catch (exception) {
      throw NotificationApplicationException(
        mapNotificationFailure(exception),
      );
    }
  }

  @override
  Future<void> markAllRead() async {
    try {
      await _notificationRemoteDataSource.markAllRead();
    } on NotificationRemoteException catch (exception) {
      throw NotificationApplicationException(
        mapNotificationFailure(exception),
      );
    }
  }
}

NotificationFailure mapNotificationFailure(
  NotificationRemoteException exception,
) {
  return switch (exception) {
    NotificationRemoteValidationException() =>
      const NotificationValidationFailure(),
    NotificationRemoteUnauthorizedException() =>
      const NotificationUnauthorized(),
    NotificationRemoteNotFoundException() => const NotificationNotFound(),
    NotificationRemoteNetworkException() =>
      const NotificationNetworkUnavailable(),
    NotificationRemoteTimeoutException() =>
      const NotificationRequestTimedOut(),
    NotificationRemoteServerException() => const NotificationServerFailure(),
    NotificationRemoteMalformedResponseException() =>
      const UnknownNotificationFailure(),
    NotificationRemoteUnknownException() =>
      const UnknownNotificationFailure(),
  };
}
