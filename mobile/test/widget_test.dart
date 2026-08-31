import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/app/language/app_language_preference.dart';
import 'package:memory_map/app/language/app_language_preference_storage.dart';
import 'package:memory_map/app/language/file_app_language_preference_storage.dart';
import 'package:memory_map/app/app.dart';
import 'package:memory_map/features/auth/application/auth_application_providers.dart';
import 'package:memory_map/features/auth/domain/auth_repository.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  testWidgets('shouldRenderEnglishAuthCheckingScreen', (
    WidgetTester tester,
  ) async {
    final restoreCompleter = Completer<AuthSession?>();
    final fakeRepository = FakeAuthRepository()
      ..restoreCompleter = restoreCompleter;
    addTearDown(() {
      if (!restoreCompleter.isCompleted) {
        restoreCompleter.complete(null);
      }
    });

    await pumpApp(tester, fakeRepository);

    expect(find.text('Memory Map'), findsWidgets);
    expect(
      find.byKey(const ValueKey('auth-checking.memory-map.logo')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Checking your session…'), findsNothing);
    expect(find.text('Flutter bootstrap is ready'), findsNothing);
  });

  testWidgets('shouldRenderRussianAuthCheckingScreen', (
    WidgetTester tester,
  ) async {
    final restoreCompleter = Completer<AuthSession?>();
    final fakeRepository = FakeAuthRepository()
      ..restoreCompleter = restoreCompleter;
    addTearDown(() {
      if (!restoreCompleter.isCompleted) {
        restoreCompleter.complete(null);
      }
    });

    await pumpApp(
      tester,
      fakeRepository,
      locale: const Locale('ru'),
    );

    expect(find.text('Memory Map'), findsWidgets);
    expect(
      find.byKey(const ValueKey('auth-checking.memory-map.logo')),
      findsOneWidget,
    );
    expect(find.text('Проверяем ваш сеанс…'), findsNothing);
  });

  testWidgets('shouldUsePersistedRussianLanguagePreference', (
    WidgetTester tester,
  ) async {
    final restoreCompleter = Completer<AuthSession?>();
    final fakeRepository = FakeAuthRepository()
      ..restoreCompleter = restoreCompleter;
    addTearDown(() {
      if (!restoreCompleter.isCompleted) {
        restoreCompleter.complete(null);
      }
    });

    await pumpApp(
      tester,
      fakeRepository,
      locale: const Locale('en'),
      languageStorage: FakeAppLanguagePreferenceStorage()
        ..storedPreference = AppLanguagePreference.russian,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Memory Map'), findsWidgets);
    expect(find.text('Проверяем ваш сеанс…'), findsNothing);
  });

  testWidgets('shouldFallbackUnsupportedSystemLocaleToEnglish', (
    WidgetTester tester,
  ) async {
    final restoreCompleter = Completer<AuthSession?>();
    final fakeRepository = FakeAuthRepository()
      ..restoreCompleter = restoreCompleter;
    addTearDown(() {
      if (!restoreCompleter.isCompleted) {
        restoreCompleter.complete(null);
      }
    });

    await pumpApp(
      tester,
      fakeRepository,
      locale: const Locale('fr'),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Memory Map'), findsWidgets);
    expect(find.text('Checking your session…'), findsNothing);
  });

  testWidgets('shouldUsePersistedEnglishLanguagePreference', (
    WidgetTester tester,
  ) async {
    final restoreCompleter = Completer<AuthSession?>();
    final fakeRepository = FakeAuthRepository()
      ..restoreCompleter = restoreCompleter;
    addTearDown(() {
      if (!restoreCompleter.isCompleted) {
        restoreCompleter.complete(null);
      }
    });

    await pumpApp(
      tester,
      fakeRepository,
      locale: const Locale('ru'),
      languageStorage: FakeAppLanguagePreferenceStorage()
        ..storedPreference = AppLanguagePreference.english,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Memory Map'), findsWidgets);
    expect(find.text('Checking your session…'), findsNothing);
  });

  testWidgets('shouldCreateMaterialAppRouter', (WidgetTester tester) async {
    final restoreCompleter = Completer<AuthSession?>();
    final fakeRepository = FakeAuthRepository()
      ..restoreCompleter = restoreCompleter;
    addTearDown(() {
      if (!restoreCompleter.isCompleted) {
        restoreCompleter.complete(null);
      }
    });

    await pumpApp(tester, fakeRepository);

    final materialApp = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );

    expect(materialApp.routerConfig, isNotNull);
    expect(materialApp.localizationsDelegates, isNotNull);
    expect(
      materialApp.supportedLocales,
      AppLocalizations.supportedLocales,
    );
  });

  testWidgets('shouldRedirectRootFlowToLoginWhenNoSessionExists', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository();

    await pumpApp(tester, fakeRepository);
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}

Future<void> pumpApp(
  WidgetTester tester,
  FakeAuthRepository fakeRepository, {
  Locale? locale,
  FakeAppLanguagePreferenceStorage? languageStorage,
}) async {
  if (locale != null) {
    tester.platformDispatcher.localeTestValue = locale;
    tester.platformDispatcher.localesTestValue = [locale];
    addTearDown(() {
      tester.platformDispatcher.clearLocaleTestValue();
      tester.platformDispatcher.clearLocalesTestValue();
    });
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepository),
        appLanguagePreferenceStorageProvider.overrideWithValue(
          languageStorage ?? FakeAppLanguagePreferenceStorage(),
        ),
      ],
      child: const MemoryMapApp(),
    ),
  );
  await tester.pump();
}

final class FakeAppLanguagePreferenceStorage
    implements AppLanguagePreferenceStorage {
  AppLanguagePreference? storedPreference;

  @override
  Future<AppLanguagePreference?> read() async {
    return storedPreference;
  }

  @override
  Future<void> write(AppLanguagePreference preference) async {
    storedPreference = preference;
  }
}

final class FakeAuthRepository implements AuthRepository {
  Completer<AuthSession?>? restoreCompleter;

  @override
  Future<AuthSession?> restoreSession() {
    final completer = restoreCompleter;
    if (completer != null) {
      return completer.future;
    }

    return Future<AuthSession?>.value();
  }

  @override
  Future<AuthSession> loginWithGoogle() {
    throw UnimplementedError();
  }

  @override
  Future<void> logout(AuthSession session) {
    throw UnimplementedError();
  }
}
