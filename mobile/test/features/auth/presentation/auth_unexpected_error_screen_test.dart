import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/application/auth_application_providers.dart';
import 'package:memory_map/features/auth/domain/auth_repository.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/presentation/auth_unexpected_error_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  testWidgets('shouldRenderEnglishUnexpectedErrorScreen', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, FakeAuthRepository());

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Please restart the app or try again.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('shouldRenderRussianUnexpectedErrorScreen', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, FakeAuthRepository(), locale: const Locale('ru'));

    expect(find.text('Что-то пошло не так'), findsOneWidget);
    expect(
      find.text('Перезапустите приложение или попробуйте ещё раз.'),
      findsOneWidget,
    );
    expect(find.text('Попробовать снова'), findsOneWidget);
  });

  testWidgets('shouldRetrySessionRestoreWhenPressed', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository();

    await pumpScreen(tester, fakeRepository);
    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(fakeRepository.restoreCalls, 1);
  });

  testWidgets('shouldNotExposeInfrastructureDetailsOrTokens', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, FakeAuthRepository());

    expect(find.textContaining('UnexpectedAuthException'), findsNothing);
    expect(find.textContaining('AuthApplicationException'), findsNothing);
    expect(find.textContaining('Dio'), findsNothing);
    expect(find.textContaining('signed-access-token'), findsNothing);
    expect(find.textContaining('raw-refresh-token'), findsNothing);
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
        home: const AuthUnexpectedErrorScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class FakeAuthRepository implements AuthRepository {
  int restoreCalls = 0;

  @override
  Future<AuthSession?> restoreSession() async {
    restoreCalls += 1;
    return null;
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
