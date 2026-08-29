import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/app/language/app_language_preference.dart';
import 'package:memory_map/app/language/app_language_preference_notifier.dart';
import 'package:memory_map/app/language/app_language_preference_storage.dart';
import 'package:memory_map/app/language/file_app_language_preference_storage.dart';
import 'package:memory_map/features/profile/presentation/profile_language_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('ProfileLanguageScreen rendering', () {
    testWidgets('shouldRenderLanguageOptionsAndSelectedSystemPreference', (
      WidgetTester tester,
    ) async {
      await pumpProfileLanguageScreen(tester, FakeAppLanguagePreferenceStorage());

      expect(find.byKey(const ValueKey('profile-language.screen')), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Use device language'), findsOneWidget);
      expect(find.text('Русский'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-language.selected.system')),
        findsOneWidget,
      );
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('shouldRenderRussianWhenSystemLocaleIsRussian', (
      WidgetTester tester,
    ) async {
      await pumpProfileLanguageScreen(
        tester,
        FakeAppLanguagePreferenceStorage(),
        deviceLocale: const Locale('ru'),
      );

      expect(find.text('Язык'), findsOneWidget);
      expect(find.text('Системный'), findsOneWidget);
      expect(find.text('Использовать язык устройства'), findsOneWidget);
    });
  });

  group('ProfileLanguageScreen actions', () {
    testWidgets('shouldPersistSelectionAndSwitchLocaleImmediately', (
      WidgetTester tester,
    ) async {
      final storage = FakeAppLanguagePreferenceStorage();
      await pumpProfileLanguageScreen(tester, storage);

      await tester.tap(
        find.byKey(const ValueKey('profile-language.option.ru')),
      );
      await tester.pumpAndSettle();

      expect(storage.storedPreference, AppLanguagePreference.russian);
      expect(find.text('Язык'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-language.selected.ru')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('profile-language.screen')), findsOneWidget);
    });

    testWidgets('shouldSwitchToEnglishOverrideImmediately', (
      WidgetTester tester,
    ) async {
      final storage = FakeAppLanguagePreferenceStorage(
        initialPreference: AppLanguagePreference.russian,
      );
      await pumpProfileLanguageScreen(
        tester,
        storage,
        deviceLocale: const Locale('ru'),
      );

      await tester.tap(
        find.byKey(const ValueKey('profile-language.option.en')),
      );
      await tester.pumpAndSettle();

      expect(storage.storedPreference, AppLanguagePreference.english);
      expect(find.text('Language'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-language.selected.en')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('profile-language.screen')), findsOneWidget);
    });

    testWidgets('shouldRestoreSystemModeWithoutPersistingResolvedLocale', (
      WidgetTester tester,
    ) async {
      final storage = FakeAppLanguagePreferenceStorage(
        initialPreference: AppLanguagePreference.english,
      );
      await pumpProfileLanguageScreen(
        tester,
        storage,
        deviceLocale: const Locale('ru'),
      );

      await tester.tap(
        find.byKey(const ValueKey('profile-language.option.system')),
      );
      await tester.pumpAndSettle();

      expect(storage.storedPreference, AppLanguagePreference.system);
      expect(find.text('Язык'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-language.selected.system')),
        findsOneWidget,
      );
    });

    testWidgets('shouldShowPersistenceFailureWithoutChangingPreference', (
      WidgetTester tester,
    ) async {
      final storage = FakeAppLanguagePreferenceStorage()
        ..writeFailure = const AppLanguagePreferenceStorageException();
      await pumpProfileLanguageScreen(tester, storage);

      await tester.tap(
        find.byKey(const ValueKey('profile-language.option.en')),
      );
      await tester.pumpAndSettle();

      expect(storage.storedPreference, isNull);
      expect(find.text('Language could not be saved. Please try again.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-language.selected.system')),
        findsOneWidget,
      );
    });

    testWidgets('shouldCallBackCallbackFromHeaderAction', (
      WidgetTester tester,
    ) async {
      var backCalls = 0;
      await pumpProfileLanguageScreen(
        tester,
        FakeAppLanguagePreferenceStorage(),
        onBack: () {
          backCalls += 1;
        },
      );

      await tester.tap(
        find.byKey(const ValueKey('profile-language.back-action')),
      );
      await tester.pump();

      expect(backCalls, 1);
    });
  });
}

Future<void> pumpProfileLanguageScreen(
  WidgetTester tester,
  FakeAppLanguagePreferenceStorage storage, {
  Locale deviceLocale = const Locale('en'),
  VoidCallback? onBack,
}) async {
  tester.platformDispatcher.localeTestValue = deviceLocale;
  tester.platformDispatcher.localesTestValue = [deviceLocale];
  addTearDown(() {
    tester.platformDispatcher.clearLocaleTestValue();
    tester.platformDispatcher.clearLocalesTestValue();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLanguagePreferenceStorageProvider.overrideWithValue(storage),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          final languageState =
              ref.watch(appLanguagePreferenceProvider).asData?.value;

          return MaterialApp(
            locale: languageState?.preference.toFlutterLocale(),
            localeResolutionCallback: resolveMemoryStoryLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfileLanguageScreen(
              onBack: onBack ?? () {},
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class FakeAppLanguagePreferenceStorage
    implements AppLanguagePreferenceStorage {
  FakeAppLanguagePreferenceStorage({
    AppLanguagePreference? initialPreference,
  }) : storedPreference = initialPreference;

  AppLanguagePreference? storedPreference;
  Object? writeFailure;

  @override
  Future<AppLanguagePreference?> read() async {
    return storedPreference;
  }

  @override
  Future<void> write(AppLanguagePreference preference) async {
    final failure = writeFailure;
    if (failure != null) {
      throw failure;
    }

    storedPreference = preference;
  }
}
