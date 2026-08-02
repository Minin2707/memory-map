import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/presentation/widgets/story_role_badge.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  testWidgets('shouldRenderEnglishRoleLabels', (WidgetTester tester) async {
    await pumpBadgeWrap(tester, const Locale('en'));

    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Co-owner'), findsOneWidget);
    expect(find.text('Editor'), findsOneWidget);
    expect(find.text('Viewer'), findsOneWidget);
    expect(find.text('coOwner'), findsNothing);
    expect(find.text('CO_OWNER'), findsNothing);
  });

  testWidgets('shouldRenderRussianRoleLabels', (WidgetTester tester) async {
    await pumpBadgeWrap(tester, const Locale('ru'));

    expect(find.text('Владелец'), findsOneWidget);
    expect(find.text('Совладелец'), findsOneWidget);
    expect(find.text('Редактор'), findsOneWidget);
    expect(find.text('Читатель'), findsOneWidget);
  });

  testWidgets('shouldRenderIconAndTextForEveryRole', (
    WidgetTester tester,
  ) async {
    await pumpBadgeWrap(tester, const Locale('en'));

    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    expect(find.byIcon(Icons.group_rounded), findsOneWidget);
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
  });

  testWidgets('shouldNotOverflowWithLargeTextScale', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpBadgeWrap(
      tester,
      const Locale('ru'),
      textScaler: const TextScaler.linear(1.5),
    );

    expect(tester.takeException(), isNull);
  });
}

Future<void> pumpBadgeWrap(
  WidgetTester tester,
  Locale locale, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const Scaffold(
        body: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StoryRoleBadge(role: StoryRole.owner),
            StoryRoleBadge(role: StoryRole.coOwner),
            StoryRoleBadge(role: StoryRole.editor),
            StoryRoleBadge(role: StoryRole.viewer),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}
