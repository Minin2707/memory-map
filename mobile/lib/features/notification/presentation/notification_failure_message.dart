import 'package:memory_map/features/notification/domain/notification_failure.dart';
import 'package:memory_map/l10n/app_localizations.dart';

String notificationFailureMessage(
  AppLocalizations l10n,
  NotificationFailure failure,
) {
  return switch (failure) {
    NotificationValidationFailure() => l10n.notificationFailureUnknown,
    NotificationUnauthorized() => l10n.notificationFailureUnauthorized,
    NotificationNotFound() => l10n.notificationFailureNotFound,
    NotificationNetworkUnavailable() => l10n.notificationFailureNetwork,
    NotificationRequestTimedOut() => l10n.notificationFailureTimeout,
    NotificationServerFailure() => l10n.notificationFailureServer,
    UnknownNotificationFailure() => l10n.notificationFailureUnknown,
  };
}
