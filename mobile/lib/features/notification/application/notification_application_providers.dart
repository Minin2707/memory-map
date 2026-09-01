import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/notification/application/default_notification_repository.dart';
import 'package:memory_map/features/notification/data/remote/dio_notification_remote_data_source.dart';
import 'package:memory_map/features/notification/domain/notification_repository.dart';

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) {
  return DefaultNotificationRepository(
    notificationRemoteDataSource: ref.watch(notificationRemoteDataSourceProvider),
  );
});
