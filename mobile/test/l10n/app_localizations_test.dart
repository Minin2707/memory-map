import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/app/language/app_language_preference.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  testWidgets('shouldSupportEnglish', (WidgetTester tester) async {
    final l10n = await loadL10n(tester, const Locale('en'));

    expect(l10n.appName, 'Memory Map');
    expect(l10n.loginHeadline, 'Every place has a story');
  });

  testWidgets('shouldSupportRussian', (WidgetTester tester) async {
    final l10n = await loadL10n(tester, const Locale('ru'));

    expect(l10n.appName, 'Memory Map');
    expect(l10n.loginHeadline, 'У каждого места есть история');
  });

  testWidgets('shouldSupportGeorgian', (WidgetTester tester) async {
    final l10n = await loadL10n(tester, const Locale('ka'));

    expect(l10n.appName, 'Memory Map');
    expect(l10n.loginHeadline, 'ყოველ ადგილს თავისი ისტორია აქვს');
    expect(l10n.continueWithGoogle, 'Google-ით გაგრძელება');
    expect(l10n.profileLanguageTitle, 'ენა');
    expect(l10n.languageGeorgianOption, 'ქართული');
  });

  test('shouldListGeorgianAsSupportedLocale', () {
    expect(AppLocalizations.supportedLocales, contains(const Locale('ka')));
  });

  testWidgets('shouldUseEnglishFallbackForUnsupportedLocale', (
    WidgetTester tester,
  ) async {
    final l10n = await loadL10n(tester, const Locale('de'));

    expect(l10n.loginHeadline, 'Every place has a story');
  });

  testWidgets('shouldProvideAllCriticalEnglishAuthStrings', (
    WidgetTester tester,
  ) async {
    final l10n = await loadL10n(tester, const Locale('en'));

    expect(l10n.continueWithGoogle, 'Continue with Google');
    expect(l10n.signingIn, 'Signing in…');
    expect(l10n.restoreSessionTitle, 'Could not restore your session');
    expect(l10n.unexpectedErrorTitle, 'Something went wrong');
    expect(l10n.authenticatedSessionReady, 'Authenticated session is ready');
    expect(l10n.logOut, 'Log out');
    expect(l10n.networkUnavailable, isNotEmpty);
    expect(l10n.secureStorageFailure, isNotEmpty);
    expect(l10n.unknownAuthFailure, isNotEmpty);
  });

  testWidgets('shouldProvideAllCriticalRussianAuthStrings', (
    WidgetTester tester,
  ) async {
    final l10n = await loadL10n(tester, const Locale('ru'));

    expect(l10n.continueWithGoogle, 'Продолжить с Google');
    expect(l10n.signingIn, 'Выполняется вход…');
    expect(l10n.restoreSessionTitle, 'Не удалось восстановить сеанс');
    expect(l10n.unexpectedErrorTitle, 'Что-то пошло не так');
    expect(l10n.authenticatedSessionReady, 'Сеанс авторизации готов');
    expect(l10n.logOut, 'Выйти');
    expect(l10n.networkUnavailable, isNotEmpty);
    expect(l10n.secureStorageFailure, isNotEmpty);
    expect(l10n.unknownAuthFailure, isNotEmpty);
  });

  testWidgets('shouldProvideAllCriticalGeorgianAuthStrings', (
    WidgetTester tester,
  ) async {
    final l10n = await loadL10n(tester, const Locale('ka'));

    expect(l10n.continueWithGoogle, 'Google-ით გაგრძელება');
    expect(l10n.signingIn, 'შესვლა…');
    expect(l10n.restoreSessionTitle, 'სესიის აღდგენა ვერ მოხერხდა');
    expect(l10n.unexpectedErrorTitle, 'რაღაც არასწორად წავიდა');
    expect(l10n.authenticatedSessionReady, 'ავთენტიფიცირებული სესია მზადაა');
    expect(l10n.logOut, 'გასვლა');
    expect(l10n.networkUnavailable, isNotEmpty);
    expect(l10n.secureStorageFailure, isNotEmpty);
    expect(l10n.unknownAuthFailure, isNotEmpty);
  });

  testWidgets('shouldFormatEnglishWelcomeMessage', (
    WidgetTester tester,
  ) async {
    final l10n = await loadL10n(tester, const Locale('en'));

    expect(l10n.welcomeUser('Ada Lovelace'), 'Welcome, Ada Lovelace');
  });

  testWidgets('shouldFormatRussianWelcomeMessage', (
    WidgetTester tester,
  ) async {
    final l10n = await loadL10n(tester, const Locale('ru'));

    expect(
      l10n.welcomeUser('Ada Lovelace'),
      'Добро пожаловать, Ada Lovelace',
    );
  });

  testWidgets('shouldFormatGeorgianWelcomeMessage', (
    WidgetTester tester,
  ) async {
    final l10n = await loadL10n(tester, const Locale('ka'));

    expect(
      l10n.welcomeUser('Ada Lovelace'),
      'მოგესალმებით, Ada Lovelace',
    );
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
      localeResolutionCallback: resolveMemoryStoryLocale,
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
