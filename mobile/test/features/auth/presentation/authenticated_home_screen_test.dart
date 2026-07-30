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
import 'package:memory_map/features/auth/presentation/authenticated_home_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  testWidgets('shouldRenderEnglishAuthenticatedHomeScreen', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, FakeAuthRepository());

    expect(find.text('Memory Map'), findsOneWidget);
    expect(find.text('Welcome, Ada Lovelace'), findsOneWidget);
    expect(find.text('Authenticated session is ready'), findsOneWidget);
  });

  testWidgets('shouldRenderRussianAuthenticatedHomeScreen', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, FakeAuthRepository(), locale: const Locale('ru'));

    expect(find.text('Memory Map'), findsOneWidget);
    expect(find.text('Добро пожаловать, Ada Lovelace'), findsOneWidget);
    expect(find.text('Сеанс авторизации готов'), findsOneWidget);
  });

  testWidgets('shouldShowLogoutButton', (WidgetTester tester) async {
    await pumpScreen(tester, FakeAuthRepository());

    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets('shouldCallNotifierLogout', (WidgetTester tester) async {
    final fakeRepository = FakeAuthRepository();

    await pumpScreen(tester, fakeRepository);
    await tester.tap(find.text('Log out'));
    await tester.pump();

    expect(fakeRepository.logoutCalls, 1);
    expect(fakeRepository.logoutSession, session);
  });

  testWidgets('shouldDisableLogoutWhileLoggingOut', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..logoutCompleter = Completer<void>();

    await pumpScreen(tester, fakeRepository);
    await tester.tap(find.text('Log out'));
    await tester.pump();

    final button = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton),
    );

    expect(button.onPressed, isNull);

    fakeRepository.logoutCompleter?.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shouldShowEnglishLogoutProgress', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..logoutCompleter = Completer<void>();

    await pumpScreen(tester, fakeRepository);
    await tester.tap(find.text('Log out'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Logging out…'), findsOneWidget);

    fakeRepository.logoutCompleter?.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shouldShowRussianLogoutProgress', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..logoutCompleter = Completer<void>();

    await pumpScreen(tester, fakeRepository, locale: const Locale('ru'));
    await tester.tap(find.text('Выйти'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Выполняется выход…'), findsOneWidget);

    fakeRepository.logoutCompleter?.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shouldShowSafeLogoutFailure', (WidgetTester tester) async {
    final fakeRepository = FakeAuthRepository()
      ..logoutFailure = const AuthApplicationException(
        SecureStorageFailure(),
      );

    await pumpScreen(tester, fakeRepository);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not securely save your session. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('AuthApplicationException'), findsNothing);
    expect(find.textContaining('SecureStorageFailure'), findsNothing);
  });

  testWidgets('shouldAllowRetryAfterLogoutFailure', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..logoutFailure = const AuthApplicationException(
        SecureStorageFailure(),
      );

    await pumpScreen(tester, fakeRepository);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    fakeRepository.logoutFailure = null;
    await tester.tap(find.text('Log out'));
    await tester.pump();

    expect(fakeRepository.logoutCalls, 2);
  });

  testWidgets('shouldPreserveDisplayNameWhileLoggingOut', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..logoutCompleter = Completer<void>();

    await pumpScreen(tester, fakeRepository);
    await tester.tap(find.text('Log out'));
    await tester.pump();

    expect(find.text('Welcome, Ada Lovelace'), findsOneWidget);

    fakeRepository.logoutCompleter?.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shouldNotExposeTokensOrUserId', (WidgetTester tester) async {
    await pumpScreen(tester, FakeAuthRepository());

    expect(find.textContaining('signed-access-token'), findsNothing);
    expect(find.textContaining('raw-refresh-token'), findsNothing);
    expect(find.textContaining('user-id'), findsNothing);
  });

  testWidgets('shouldNotShowRemoteFailureAfterSuccessfulLocalLogout', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, FakeAuthRepository());
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No network connection'), findsNothing);
    expect(find.textContaining('The request timed out'), findsNothing);
    expect(
      find.textContaining('The server is temporarily unavailable'),
      findsNothing,
    );
  });
}

Future<void> pumpScreen(
  WidgetTester tester,
  FakeAuthRepository fakeRepository, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepository),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AuthenticatedHomeScreen(),
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
  int logoutCalls = 0;
  AuthSession? logoutSession;
  Object? logoutFailure;
  Completer<void>? logoutCompleter;

  @override
  Future<AuthSession?> restoreSession() async {
    return session;
  }

  @override
  Future<AuthSession> loginWithGoogle() {
    throw UnimplementedError();
  }

  @override
  Future<void> logout(AuthSession session) async {
    logoutCalls += 1;
    logoutSession = session;

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
