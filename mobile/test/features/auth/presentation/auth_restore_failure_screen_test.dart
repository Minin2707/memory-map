import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/application/auth_application_exception.dart';
import 'package:memory_map/features/auth/application/auth_application_providers.dart';
import 'package:memory_map/features/auth/domain/auth_failure.dart';
import 'package:memory_map/features/auth/domain/auth_repository.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/presentation/auth_restore_failure_screen.dart';

void main() {
  testWidgets('shouldRenderRestoreFailureScreen', (WidgetTester tester) async {
    final fakeRepository = FakeAuthRepository()
      ..restoreFailure = const AuthApplicationException(NetworkUnavailable());

    await pumpScreen(tester, fakeRepository);

    expect(find.text('Could not restore your session'), findsOneWidget);
    expect(
      find.text('No network connection. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shouldRetrySessionRestoreWhenPressed', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..restoreFailure = const AuthApplicationException(NetworkUnavailable());

    await pumpScreen(tester, fakeRepository);
    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(fakeRepository.restoreCalls, 2);
  });

  testWidgets('shouldNotExposeInfrastructureDetailsOrTokens', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..restoreFailure = const AuthApplicationException(NetworkUnavailable());

    await pumpScreen(tester, fakeRepository);

    expect(find.textContaining('NetworkUnavailable'), findsNothing);
    expect(find.textContaining('AuthApplicationException'), findsNothing);
    expect(find.textContaining('Dio'), findsNothing);
    expect(find.textContaining('signed-access-token'), findsNothing);
    expect(find.textContaining('raw-refresh-token'), findsNothing);
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
        home: AuthRestoreFailureScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class FakeAuthRepository implements AuthRepository {
  int restoreCalls = 0;
  Object? restoreFailure;

  @override
  Future<AuthSession?> restoreSession() async {
    restoreCalls += 1;

    final failure = restoreFailure;
    if (failure != null) {
      throw failure;
    }

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
