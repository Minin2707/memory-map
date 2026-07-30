import 'package:memory_map/features/auth/domain/auth_failure.dart';
import 'package:memory_map/l10n/app_localizations.dart';

String authFailureMessage(AppLocalizations l10n, AuthFailure failure) {
  return switch (failure) {
    AuthCancelled() => l10n.authCancelled,
    GoogleAuthenticationUnavailable() => l10n.googleAuthenticationUnavailable,
    GoogleAuthenticationFailed() => l10n.googleAuthenticationFailed,
    BackendUnauthorized() => l10n.backendUnauthorized,
    RequestValidationFailed() => l10n.requestValidationFailed,
    NetworkUnavailable() => l10n.networkUnavailable,
    RequestTimedOut() => l10n.requestTimedOut,
    ServerFailure() => l10n.serverFailure,
    SecureStorageFailure() => l10n.secureStorageFailure,
    CorruptSession() => l10n.corruptSession,
    UnknownAuthFailure() => l10n.unknownAuthFailure,
  };
}
