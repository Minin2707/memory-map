import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/application/auth_application_exception.dart';
import 'package:memory_map/features/auth/application/auth_application_providers.dart';
import 'package:memory_map/features/auth/domain/auth_failure.dart';
import 'package:memory_map/features/auth/domain/auth_repository.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';
import 'package:memory_map/features/auth/presentation/login_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  testWidgets('shouldRenderHeroImage', (WidgetTester tester) async {
    await pumpScreen(tester, FakeAuthRepository());

    expect(find.byKey(const ValueKey('login.hero.image')), findsOneWidget);
  });

  testWidgets('shouldRenderGoogleLogoSvg', (WidgetTester tester) async {
    await pumpScreen(tester, FakeAuthRepository());

    final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));

    expect(svgPicture.width, 22);
    expect(svgPicture.height, 22);
    expect(svgPicture.bytesLoader, isA<SvgAssetLoader>());
    expect(
      (svgPicture.bytesLoader as SvgAssetLoader).assetName,
      'assets/google.svg',
    );
  });

  testWidgets('shouldRenderEnglishLoginContent', (WidgetTester tester) async {
    await pumpScreen(tester, FakeAuthRepository());

    expect(find.text('Memory Map'), findsOneWidget);
    expect(find.text('Every place has a story'), findsOneWidget);
    expect(
      find.text(
        'Create your private map of memories and share it with the people you love.',
      ),
      findsOneWidget,
    );
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('shouldCallLoginWithGoogle', (WidgetTester tester) async {
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
    expect(find.byType(SvgPicture), findsNothing);

    fakeRepository.loginCompleter?.complete(session);
    await tester.pumpAndSettle();
  });

  testWidgets('shouldShowEnglishSigningInText', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..loginCompleter = Completer<AuthSession>();

    await pumpScreen(tester, fakeRepository);
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();

    expect(find.text('Signing in…'), findsOneWidget);

    fakeRepository.loginCompleter?.complete(session);
    await tester.pumpAndSettle();
  });

  testWidgets('shouldShowEnglishSafeFailureMessage', (
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

  testWidgets('shouldRenderEnglishLegalFooter', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, FakeAuthRepository());

    expect(
      find.textContaining('By continuing', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Privacy Policy', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Terms of Use', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('shouldNotExposeTokensOrClientId', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, FakeAuthRepository());

    expect(find.textContaining('signed-access-token'), findsNothing);
    expect(find.textContaining('raw-refresh-token'), findsNothing);
    expect(find.textContaining('client-id'), findsNothing);
  });

  testWidgets('shouldRenderRussianLoginContent', (WidgetTester tester) async {
    await pumpScreen(tester, FakeAuthRepository(), locale: const Locale('ru'));

    expect(find.text('Memory Map'), findsOneWidget);
    expect(find.text('У каждого места есть история'), findsOneWidget);
    expect(
      find.text(
        'Создавайте личную карту воспоминаний и делитесь ею с теми, кто вам дорог.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shouldRenderRussianGoogleButton', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, FakeAuthRepository(), locale: const Locale('ru'));

    expect(find.text('Продолжить с Google'), findsOneWidget);
  });

  testWidgets('shouldShowRussianSigningInText', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..loginCompleter = Completer<AuthSession>();

    await pumpScreen(tester, fakeRepository, locale: const Locale('ru'));
    await tester.tap(find.text('Продолжить с Google'));
    await tester.pump();

    expect(find.text('Выполняется вход…'), findsOneWidget);

    fakeRepository.loginCompleter?.complete(session);
    await tester.pumpAndSettle();
  });

  testWidgets('shouldShowRussianSafeFailureMessage', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..loginFailure = const AuthApplicationException(NetworkUnavailable());

    await pumpScreen(tester, fakeRepository, locale: const Locale('ru'));
    await tester.tap(find.text('Продолжить с Google'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Нет подключения к интернету. Проверьте соединение и повторите попытку.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('NetworkUnavailable'), findsNothing);
  });

  testWidgets('shouldRenderRussianLegalFooter', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, FakeAuthRepository(), locale: const Locale('ru'));

    expect(
      find.textContaining('Продолжая', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Политикой конфиденциальности',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Условиями использования', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('shouldNotOverflowWithRussianText', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpScreen(tester, FakeAuthRepository(), locale: const Locale('ru'));

    expect(tester.takeException(), isNull);
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
        home: const LoginScreen(),
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
