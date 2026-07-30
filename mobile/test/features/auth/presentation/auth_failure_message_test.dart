import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/domain/auth_failure.dart';
import 'package:memory_map/features/auth/presentation/auth_failure_message.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('authFailureMessage', () {
    testWidgets('shouldReturnSafeEnglishMessagesForKnownFailures', (
      WidgetTester tester,
    ) async {
      final l10n = await loadL10n(tester, const Locale('en'));

      expect(
        authFailureMessage(l10n, const AuthCancelled()),
        'Sign-in was cancelled.',
      );
      expect(
        authFailureMessage(l10n, const GoogleAuthenticationUnavailable()),
        'Google sign-in is unavailable on this device.',
      );
      expect(
        authFailureMessage(l10n, const GoogleAuthenticationFailed()),
        'Could not sign in with Google. Please try again.',
      );
      expect(
        authFailureMessage(l10n, const BackendUnauthorized()),
        'Authentication was rejected. Please try again.',
      );
      expect(
        authFailureMessage(l10n, const RequestValidationFailed()),
        'The request was invalid. Please try again.',
      );
      expect(
        authFailureMessage(l10n, const NetworkUnavailable()),
        'No network connection. Check your connection and try again.',
      );
      expect(
        authFailureMessage(l10n, const RequestTimedOut()),
        'The request timed out. Please try again.',
      );
      expect(
        authFailureMessage(l10n, const ServerFailure()),
        'The server is temporarily unavailable. Please try again.',
      );
      expect(
        authFailureMessage(l10n, const SecureStorageFailure()),
        'Could not securely save your session. Please try again.',
      );
      expect(
        authFailureMessage(l10n, const CorruptSession()),
        'Local session data was invalid. Please try again.',
      );
      expect(
        authFailureMessage(l10n, const UnknownAuthFailure()),
        'Something went wrong. Please try again.',
      );
    });

    testWidgets('shouldReturnSafeRussianMessagesForKnownFailures', (
      WidgetTester tester,
    ) async {
      final l10n = await loadL10n(tester, const Locale('ru'));

      expect(
        authFailureMessage(l10n, const AuthCancelled()),
        'Вход был отменён.',
      );
      expect(
        authFailureMessage(l10n, const NetworkUnavailable()),
        'Нет подключения к интернету. Проверьте соединение и повторите попытку.',
      );
      expect(
        authFailureMessage(l10n, const UnknownAuthFailure()),
        'Что-то пошло не так. Попробуйте ещё раз.',
      );
    });

    testWidgets('shouldNotExposeFailureTypeNames', (
      WidgetTester tester,
    ) async {
      final l10n = await loadL10n(tester, const Locale('en'));
      final messages = [
        authFailureMessage(l10n, const AuthCancelled()),
        authFailureMessage(l10n, const GoogleAuthenticationUnavailable()),
        authFailureMessage(l10n, const GoogleAuthenticationFailed()),
        authFailureMessage(l10n, const BackendUnauthorized()),
        authFailureMessage(l10n, const RequestValidationFailed()),
        authFailureMessage(l10n, const NetworkUnavailable()),
        authFailureMessage(l10n, const RequestTimedOut()),
        authFailureMessage(l10n, const ServerFailure()),
        authFailureMessage(l10n, const SecureStorageFailure()),
        authFailureMessage(l10n, const CorruptSession()),
        authFailureMessage(l10n, const UnknownAuthFailure()),
      ];

      for (final message in messages) {
        expect(message, isNotEmpty);
        expect(message, isNot(contains('AuthFailure')));
        expect(message, isNot(contains('Exception')));
        expect(message, isNot(contains('Dio')));
        expect(message, isNot(contains('client-id')));
        expect(message, isNot(contains('access-token')));
        expect(message, isNot(contains('refresh-token')));
        expect(message, isNot(contains('StackTrace')));
      }
    });
  });
}

Future<AppLocalizations> loadL10n(
  WidgetTester tester,
  Locale locale,
) async {
  late AppLocalizations l10n;

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          l10n = AppLocalizations.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pump();

  return l10n;
}
