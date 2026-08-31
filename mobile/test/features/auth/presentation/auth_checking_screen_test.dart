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

    expect(find.byType(MemoryMapHeartPin), findsOneWidget);
    expect(startupTitleText(tester), isEmpty);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Checking your session…'), findsNothing);

    await pumpStartupBrandingAnimation(tester);

    expect(find.text('Memory Map'), findsOneWidget);
  });

  testWidgets('shouldRenderRussianAuthCheckingScreen', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, locale: const Locale('ru'));

    expect(find.byType(MemoryMapHeartPin), findsOneWidget);
    expect(startupTitleText(tester), isEmpty);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Проверяем ваш сеанс…'), findsNothing);

    await pumpStartupBrandingAnimation(tester);

    expect(find.text('Memory Map'), findsOneWidget);
  });

  testWidgets('shouldRevealPinBeforeTitle', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    expect(startupTitleText(tester), isEmpty);
    expect(startupPinOpacity(tester), 0);

    await tester.pump();

    expect(startupTitleText(tester), isEmpty);
    expect(startupPinOpacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 50));

    expect(startupTitleText(tester), isEmpty);
    expect(startupPinOpacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 200));

    expect(startupTitleText(tester), isEmpty);
    expect(startupPinOpacity(tester), greaterThan(0));

    await tester.pump(const Duration(milliseconds: 300));

    expect(startupTitleText(tester), isNotEmpty);
    expect(startupTitleText(tester), isNot('Memory Map'));

    await pumpStartupBrandingAnimation(tester);

    expect(startupTitleText(tester), 'Memory Map');
  });

  testWidgets('shouldNotifyWhenBrandAnimationCompletes', (
    WidgetTester tester,
  ) async {
    var completedCount = 0;

    await pumpScreen(
      tester,
      onBrandAnimationCompleted: () {
        completedCount += 1;
      },
    );

    expect(completedCount, 0);

    await pumpStartupBrandingAnimation(tester);

    expect(completedCount, 1);

    await tester.pump();

    expect(completedCount, 1);
  });

  testWidgets('shouldShowFinalBrandStateWhenAnimationsAreDisabled', (
    WidgetTester tester,
  ) async {
    var completed = false;

    await pumpScreen(
      tester,
      disableAnimations: true,
      onBrandAnimationCompleted: () {
        completed = true;
      },
    );
    await tester.pump();

    expect(find.byType(MemoryMapHeartPin), findsOneWidget);
    expect(find.text('Memory Map'), findsOneWidget);
    expect(completed, isTrue);
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
  bool disableAnimations = false,
  VoidCallback? onBrandAnimationCompleted,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(disableAnimations: disableAnimations),
            child: AuthCheckingScreen(
              onBrandAnimationCompleted: onBrandAnimationCompleted,
            ),
          );
        },
      ),
    ),
  );
}

Future<void> pumpStartupBrandingAnimation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(
    startupBrandingAnimationDuration + const Duration(milliseconds: 1),
  );
  await tester.pump();
}

String startupTitleText(WidgetTester tester) {
  return tester
          .widget<Text>(
            find.byKey(const ValueKey('auth-checking.memory-map.title')),
          )
          .data ??
      '';
}

double startupPinOpacity(WidgetTester tester) {
  return tester
      .widget<Opacity>(
        find.ancestor(
          of: find.byType(MemoryMapHeartPin),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;
}
