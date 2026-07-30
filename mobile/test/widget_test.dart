import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/app/app.dart';

void main() {
  testWidgets('shouldRenderBootstrapScreen', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('Memory Map'), findsWidgets);
    expect(find.text('Flutter bootstrap is ready'), findsOneWidget);
  });

  testWidgets('shouldCreateMaterialAppRouter', (WidgetTester tester) async {
    await pumpApp(tester);

    final materialApp = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );

    expect(materialApp.routerConfig, isNotNull);
  });

  testWidgets('shouldOpenRootRoute', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Flutter bootstrap is ready'), findsOneWidget);
  });
}

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MemoryMapApp(),
    ),
  );
  await tester.pumpAndSettle();
}
