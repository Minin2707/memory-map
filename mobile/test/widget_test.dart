import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/app/app.dart';
import 'package:memory_map/features/auth/application/auth_application_providers.dart';
import 'package:memory_map/features/auth/domain/auth_repository.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';

void main() {
  testWidgets('shouldRenderAuthCheckingScreen', (WidgetTester tester) async {
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
    expect(find.text('Checking your session...'), findsOneWidget);
    expect(find.text('Flutter bootstrap is ready'), findsNothing);
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
  FakeAuthRepository fakeRepository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepository),
      ],
      child: const MemoryMapApp(),
    ),
  );
  await tester.pump();
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
