import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/presentation/auth_checking_screen.dart';

void main() {
  testWidgets('shouldRenderAuthCheckingScreen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthCheckingScreen(),
      ),
    );

    expect(find.text('Memory Map'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Checking your session...'), findsOneWidget);
  });

  testWidgets('shouldNotRenderLoginOrHomeContent', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthCheckingScreen(),
      ),
    );

    expect(find.text('Continue with Google'), findsNothing);
    expect(find.textContaining('Welcome'), findsNothing);
    expect(find.text('Authenticated session is ready'), findsNothing);
  });
}
