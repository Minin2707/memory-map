// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Memory Map';

  @override
  String get loginHeadline => 'Every place has a story';

  @override
  String get loginDescription =>
      'Create your private map of memories and share it with the people you love.';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get loginLegalPrefix => 'By continuing, you agree to our';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get legalSeparator => 'and';

  @override
  String get authCancelled => 'Sign-in was cancelled.';

  @override
  String get googleAuthenticationUnavailable =>
      'Google sign-in is unavailable on this device.';

  @override
  String get googleAuthenticationFailed =>
      'Could not sign in with Google. Please try again.';

  @override
  String get backendUnauthorized =>
      'Authentication was rejected. Please try again.';

  @override
  String get requestValidationFailed =>
      'The request was invalid. Please try again.';

  @override
  String get networkUnavailable =>
      'No network connection. Check your connection and try again.';

  @override
  String get requestTimedOut => 'The request timed out. Please try again.';

  @override
  String get serverFailure =>
      'The server is temporarily unavailable. Please try again.';

  @override
  String get secureStorageFailure =>
      'Could not securely save your session. Please try again.';

  @override
  String get corruptSession =>
      'Local session data was invalid. Please try again.';

  @override
  String get unknownAuthFailure => 'Something went wrong. Please try again.';

  @override
  String get checkingSession => 'Checking your session…';

  @override
  String get restoreSessionTitle => 'Could not restore your session';

  @override
  String get retry => 'Retry';

  @override
  String get unexpectedErrorTitle => 'Something went wrong';

  @override
  String get unexpectedErrorDescription =>
      'Please restart the app or try again.';

  @override
  String get tryAgain => 'Try again';

  @override
  String welcomeUser(String displayName) {
    return 'Welcome, $displayName';
  }

  @override
  String get fallbackDisplayName => 'friend';

  @override
  String get authenticatedSessionReady => 'Authenticated session is ready';

  @override
  String get logOut => 'Log out';

  @override
  String get loggingOut => 'Logging out…';

  @override
  String get tryLogoutAgain => 'Try to log out again';
}
