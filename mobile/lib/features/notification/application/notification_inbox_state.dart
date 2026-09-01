import 'package:memory_map/features/notification/domain/notification_failure.dart';
import 'package:memory_map/features/notification/domain/notification_item.dart';

final class NotificationInboxState {
  factory NotificationInboxState({
    List<NotificationItem> notifications = const <NotificationItem>[],
    bool isRefreshing = false,
    bool isMutating = false,
    String? mutatingNotificationId,
    NotificationFailure? loadFailure,
    NotificationFailure? refreshFailure,
    NotificationFailure? mutationFailure,
  }) {
    return NotificationInboxState._(
      notifications: List<NotificationItem>.unmodifiable(notifications),
      isRefreshing: isRefreshing,
      isMutating: isMutating,
      mutatingNotificationId: mutatingNotificationId,
      loadFailure: loadFailure,
      refreshFailure: refreshFailure,
      mutationFailure: mutationFailure,
    );
  }

  const NotificationInboxState._({
    required this.notifications,
    required this.isRefreshing,
    required this.isMutating,
    required this.mutatingNotificationId,
    required this.loadFailure,
    required this.refreshFailure,
    required this.mutationFailure,
  });

  final List<NotificationItem> notifications;
  final bool isRefreshing;
  final bool isMutating;
  final String? mutatingNotificationId;
  final NotificationFailure? loadFailure;
  final NotificationFailure? refreshFailure;
  final NotificationFailure? mutationFailure;

  bool get hasLoadFailure => loadFailure != null;

  bool get hasUnread => notifications.any((item) => !item.read);

  NotificationInboxState copyWith({
    List<NotificationItem>? notifications,
    bool? isRefreshing,
    bool? isMutating,
    String? mutatingNotificationId,
    NotificationFailure? loadFailure,
    NotificationFailure? refreshFailure,
    NotificationFailure? mutationFailure,
    bool clearMutatingNotificationId = false,
    bool clearLoadFailure = false,
    bool clearRefreshFailure = false,
    bool clearMutationFailure = false,
  }) {
    return NotificationInboxState(
      notifications: notifications ?? this.notifications,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isMutating: isMutating ?? this.isMutating,
      mutatingNotificationId: clearMutatingNotificationId
          ? null
          : mutatingNotificationId ?? this.mutatingNotificationId,
      loadFailure: clearLoadFailure ? null : loadFailure ?? this.loadFailure,
      refreshFailure:
          clearRefreshFailure ? null : refreshFailure ?? this.refreshFailure,
      mutationFailure:
          clearMutationFailure ? null : mutationFailure ?? this.mutationFailure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is NotificationInboxState &&
            _listEquals(notifications, other.notifications) &&
            isRefreshing == other.isRefreshing &&
            isMutating == other.isMutating &&
            mutatingNotificationId == other.mutatingNotificationId &&
            loadFailure == other.loadFailure &&
            refreshFailure == other.refreshFailure &&
            mutationFailure == other.mutationFailure;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(notifications),
        isRefreshing,
        isMutating,
        mutatingNotificationId,
        loadFailure,
        refreshFailure,
        mutationFailure,
      );

  @override
  String toString() {
    return 'NotificationInboxState(count: ${notifications.length}, '
        'isRefreshing: $isRefreshing, isMutating: $isMutating)';
  }

  static bool _listEquals<T>(List<T> left, List<T> right) {
    if (identical(left, right)) {
      return true;
    }

    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }

    return true;
  }
}
