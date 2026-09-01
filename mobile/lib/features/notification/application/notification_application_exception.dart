import 'package:memory_map/features/notification/domain/notification_failure.dart';

final class NotificationApplicationException implements Exception {
  const NotificationApplicationException(this.failure);

  final NotificationFailure failure;

  @override
  String toString() => 'NotificationApplicationException';
}
