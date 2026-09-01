import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/notification/application/notification_application_providers.dart';

final unreadNotificationCountProvider =
    AsyncNotifierProvider<UnreadNotificationCountNotifier, int>(
  UnreadNotificationCountNotifier.new,
  retry: (retryCount, error) => null,
);

final class UnreadNotificationCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() {
    return ref.watch(notificationRepositoryProvider).getUnreadCount();
  }

  Future<void> refreshUnreadCount() async {
    state = await AsyncValue.guard<int>(() {
      return ref.read(notificationRepositoryProvider).getUnreadCount();
    });
  }

  void decrementIfPositive() {
    final value = state.asData?.value;
    if (value == null || value <= 0) {
      return;
    }

    state = AsyncData<int>(value - 1);
  }

  void setZero() {
    state = const AsyncData<int>(0);
  }
}
