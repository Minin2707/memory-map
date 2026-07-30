import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/application/auth_application_exception.dart';
import 'package:memory_map/features/auth/application/auth_application_providers.dart';
import 'package:memory_map/features/auth/domain/auth_failure.dart';
import 'package:memory_map/features/auth/domain/auth_repository.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';
import 'package:memory_map/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('shouldRenderLoginScreen', (WidgetTester tester) async {
    final fakeRepository = FakeAuthRepository();

    await pumpScreen(tester, fakeRepository);

    expect(find.text('Memory Map'), findsOneWidget);
    expect(
      find.text('Sign in to continue building your family archive.'),
      findsOneWidget,
    );
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('shouldCallLoginWithGoogleWhenPressed', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository();

    await pumpScreen(tester, fakeRepository);
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();

    expect(fakeRepository.loginCalls, 1);
  });

  testWidgets('shouldDisableButtonWhileAuthenticating', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..loginCompleter = Completer<AuthSession>();

    await pumpScreen(tester, fakeRepository);
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));

    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Signing in...'), findsOneWidget);

    fakeRepository.loginCompleter?.complete(session);
    await tester.pumpAndSettle();
  });

  testWidgets('shouldShowSafeLoginFailureMessage', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..loginFailure = const AuthApplicationException(NetworkUnavailable());

    await pumpScreen(tester, fakeRepository);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(
      find.text('No network connection. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('NetworkUnavailable'), findsNothing);
    expect(find.textContaining('signed-access-token'), findsNothing);
    expect(find.textContaining('raw-refresh-token'), findsNothing);
    expect(find.textContaining('client-id'), findsNothing);
  });
}

Future<void> pumpScreen(
  WidgetTester tester,
  FakeAuthRepository fakeRepository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepository),
      ],
      child: const MaterialApp(
        home: LoginScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final AuthSession session = AuthSession(
  user: AuthUser(
    id: 'user-id',
    displayName: 'Ada Lovelace',
    avatarUrl: 'https://example.com/avatar.png',
  ),
  tokens: AuthTokens(
    accessToken: 'signed-access-token',
    refreshToken: 'raw-refresh-token',
  ),
);

final class FakeAuthRepository implements AuthRepository {
  int loginCalls = 0;

  Object? loginFailure;
  Completer<AuthSession>? loginCompleter;

  @override
  Future<AuthSession?> restoreSession() async {
    return null;
  }

  @override
  Future<AuthSession> loginWithGoogle() async {
    loginCalls += 1;

    final completer = loginCompleter;
    if (completer != null) {
      return completer.future;
    }

    final failure = loginFailure;
    if (failure != null) {
      throw failure;
    }

    return session;
  }

  @override
  Future<void> logout(AuthSession session) {
    throw UnimplementedError();
  }
}
