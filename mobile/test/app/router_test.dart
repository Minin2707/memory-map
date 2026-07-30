import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memory_map/app/app.dart';
import 'package:memory_map/app/router.dart';
import 'package:memory_map/features/auth/application/auth_application_exception.dart';
import 'package:memory_map/features/auth/application/auth_application_providers.dart';
import 'package:memory_map/features/auth/application/auth_notifier.dart';
import 'package:memory_map/features/auth/domain/auth_failure.dart';
import 'package:memory_map/features/auth/domain/auth_repository.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';

void main() {
  testWidgets('shouldRouteLoadingStateToAuthChecking', (
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

    expect(find.text('Checking your session…'), findsOneWidget);
  });

  testWidgets('shouldRouteUnauthenticatedStateToLogin', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, FakeAuthRepository());
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('shouldKeepAuthenticatingStateOnLogin', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..loginCompleter = Completer<AuthSession>();

    await pumpApp(tester, fakeRepository);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();

    expect(find.text('Signing in…'), findsOneWidget);

    fakeRepository.loginCompleter?.complete(session);
    await tester.pumpAndSettle();
  });

  testWidgets('shouldRouteLoginFailureStateToLogin', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..loginFailure = const AuthApplicationException(NetworkUnavailable());

    await pumpApp(tester, fakeRepository);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(
      find.text('No network connection. Check your connection and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('shouldRouteRestoreFailureStateToRestoreError', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..restoreFailure = const AuthApplicationException(NetworkUnavailable());

    await pumpApp(tester, fakeRepository);
    await tester.pumpAndSettle();

    expect(find.text('Could not restore your session'), findsOneWidget);
  });

  testWidgets('shouldRouteAuthenticatedStateToHome', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..restoreResult = session;

    await pumpApp(tester, fakeRepository);
    await tester.pumpAndSettle();

    expect(find.text('Welcome, Ada Lovelace'), findsOneWidget);
  });

  testWidgets('shouldKeepLoggingOutStateOnHome', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..restoreResult = session
      ..logoutCompleter = Completer<void>();

    await pumpApp(tester, fakeRepository);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pump();

    expect(find.text('Welcome, Ada Lovelace'), findsOneWidget);
    expect(find.text('Logging out…'), findsOneWidget);

    fakeRepository.logoutCompleter?.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shouldKeepLogoutFailureStateOnHome', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..restoreResult = session
      ..logoutFailure = const AuthApplicationException(
        SecureStorageFailure(),
      );

    await pumpApp(tester, fakeRepository);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome, Ada Lovelace'), findsOneWidget);
    expect(
      find.text('Could not securely save your session. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('shouldRouteUnauthenticatedAfterLogoutToLogin', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..restoreResult = session;

    await pumpApp(tester, fakeRepository);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.textContaining('Welcome'), findsNothing);
  });

  testWidgets('authenticatedUserCannotRemainOnLoginRoute', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..restoreResult = session;

    await pumpApp(tester, fakeRepository);
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Welcome, Ada Lovelace'));
    GoRouter.of(context).go(authLoginRoute);
    await tester.pumpAndSettle();

    expect(find.text('Welcome, Ada Lovelace'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('unauthenticatedUserCannotRemainOnHomeRoute', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, FakeAuthRepository());
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Continue with Google'));
    GoRouter.of(context).go(homeRoute);
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.textContaining('Welcome'), findsNothing);
  });

  testWidgets('shouldRouteUnexpectedErrorToUnexpectedErrorScreen', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..restoreFailure = const UnexpectedAuthException();

    await pumpApp(tester, fakeRepository);
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('shouldNotLoopWhenAlreadyOnCorrectDestination', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, FakeAuthRepository());
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
  });

  test('shouldKeepRouterInstanceStableAcrossAuthChanges', () async {
    final fakeRepository = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepository),
      ],
    );
    addTearDown(container.dispose);

    final firstRouter = container.read(appRouterProvider);
    await container.read(authNotifierProvider.future);
    await container.read(authNotifierProvider.notifier).loginWithGoogle();
    final secondRouter = container.read(appRouterProvider);

    expect(identical(firstRouter, secondRouter), isTrue);
  });

  test('shouldKeepRouterInstanceStableDuringLogoutTransition', () async {
    final fakeRepository = FakeAuthRepository()
      ..restoreResult = session
      ..logoutCompleter = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepository),
      ],
    );
    addTearDown(container.dispose);

    final firstRouter = container.read(appRouterProvider);
    await container.read(authNotifierProvider.future);
    final logout = container.read(authNotifierProvider.notifier).logout();
    await pumpEventQueue();
    final secondRouter = container.read(appRouterProvider);

    expect(identical(firstRouter, secondRouter), isTrue);

    fakeRepository.logoutCompleter?.complete();
    await logout;
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
  AuthSession? restoreResult;
  Object? restoreFailure;
  Object? loginFailure;
  Object? logoutFailure;
  Completer<AuthSession?>? restoreCompleter;
  Completer<AuthSession>? loginCompleter;
  Completer<void>? logoutCompleter;

  @override
  Future<AuthSession?> restoreSession() async {
    final completer = restoreCompleter;
    if (completer != null) {
      return completer.future;
    }

    final failure = restoreFailure;
    if (failure != null) {
      throw failure;
    }

    return restoreResult;
  }

  @override
  Future<AuthSession> loginWithGoogle() async {
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
  Future<void> logout(AuthSession session) async {
    final completer = logoutCompleter;
    if (completer != null) {
      return completer.future;
    }

    final failure = logoutFailure;
    if (failure != null) {
      throw failure;
    }
  }
}

final class UnexpectedAuthException implements Exception {
  const UnexpectedAuthException();
}
