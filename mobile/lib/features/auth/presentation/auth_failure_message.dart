import 'package:memory_map/features/auth/domain/auth_failure.dart';

String authFailureMessage(AuthFailure failure) {
  return switch (failure) {
    AuthCancelled() => 'Sign-in was cancelled.',
    GoogleAuthenticationUnavailable() =>
      'Google sign-in is unavailable on this device.',
    GoogleAuthenticationFailed() =>
      'Could not sign in with Google. Please try again.',
    BackendUnauthorized() =>
      'Authentication was rejected. Please try again.',
    RequestValidationFailed() =>
      'The sign-in request was invalid. Please try again.',
    NetworkUnavailable() =>
      'No network connection. Check your connection and try again.',
    RequestTimedOut() => 'The request timed out. Please try again.',
    ServerFailure() =>
      'The server is temporarily unavailable. Please try again.',
    SecureStorageFailure() =>
      'Could not securely save your session. Please try again.',
    CorruptSession() => 'Local session data was invalid. Please try again.',
    UnknownAuthFailure() => 'Something went wrong. Please try again.',
  };
}
