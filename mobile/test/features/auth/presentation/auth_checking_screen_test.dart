import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/presentation/auth_checking_screen.dart';
import 'package:memory_map/features/auth/presentation/memory_map_brand_mark.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  testWidgets('shouldRenderEnglishAuthCheckingScreen', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Memory Map'), findsOneWidget);
    expect(find.byType(MemoryMapHeartPin), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Checking your session…'), findsNothing);
  });

  testWidgets('shouldRenderRussianAuthCheckingScreen', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, locale: const Locale('ru'));

    expect(find.text('Memory Map'), findsOneWidget);
    expect(find.byType(MemoryMapHeartPin), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Проверяем ваш сеанс…'), findsNothing);
  });

  testWidgets('shouldNotRenderLoginOrHomeContent', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Continue with Google'), findsNothing);
    expect(find.textContaining('Welcome'), findsNothing);
    expect(find.text('Authenticated session is ready'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

Future<void> pumpScreen(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthCheckingScreen(),
    ),
  );
}
