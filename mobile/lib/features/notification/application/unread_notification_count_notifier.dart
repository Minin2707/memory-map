import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/notification/application/notification_application_providers.dart';

final unreadNotificationCountProvider =
    AsyncNotifierProvider<UnreadNotificationCountNotifier, int>(
  UnreadNotificationCountNotifier.new,
  retry: (retryCount, error) => null,
);

final class UnreadNotificationCountNotifier extends AsyncNotifier<int> {
  int _refreshRevision = 0;

  @override
  Future<int> build() {
    return ref.watch(notificationRepositoryProvider).getUnreadCount();
  }

  Future<void> refreshUnreadCount() async {
    final refreshRevision = ++_refreshRevision;

    try {
      final count = await ref
          .read(notificationRepositoryProvider)
          .getUnreadCount();
      if (!_isCurrentRefresh(refreshRevision)) {
        return;
      }

      state = AsyncData<int>(count);
    } on Object catch (error, stackTrace) {
      if (!_isCurrentRefresh(refreshRevision)) {
        return;
      }

      state = AsyncError<int>(error, stackTrace);
    }
  }

  void decrementIfPositive() {
    final value = state.asData?.value;
    if (value == null || value <= 0) {
      return;
    }

    _invalidateRefresh();
    state = AsyncData<int>(value - 1);
  }

  void setZero() {
    _invalidateRefresh();
    state = const AsyncData<int>(0);
  }

  void _invalidateRefresh() {
    _refreshRevision += 1;
  }

  bool _isCurrentRefresh(int refreshRevision) {
    return ref.mounted && _refreshRevision == refreshRevision;
  }
}
