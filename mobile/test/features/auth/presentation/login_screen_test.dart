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
  testWidgets('shouldRenderCompactHeroSection', (WidgetTester tester) async {
    await setPortraitSurface(tester);
    await pumpScreen(tester, FakeAuthRepository());

    final heroSize = tester.getSize(
      find.byKey(const ValueKey('login.hero.section')),
    );

    expect(heroSize.height, greaterThanOrEqualTo(380));
    expect(heroSize.height, lessThanOrEqualTo(455));
  });

  testWidgets('shouldUseLoginScreenHeroAsset', (WidgetTester tester) async {
    await pumpScreen(tester, FakeAuthRepository());

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('login.hero.image')),
    );

    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName, 'assets/loginscreen.png');
    expect(image.fit, BoxFit.cover);
    expect(image.alignment, const Alignment(0, 0.42));
  });

  testWidgets('shouldRenderMemoryMapLogo', (WidgetTester tester) async {
    await pumpScreen(tester, FakeAuthRepository());

    expect(find.byKey(const ValueKey('login.memory-map.logo')), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('shouldRenderHeroBeforeMainContent', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, FakeAuthRepository());

    final heroTop = tester.getTopLeft(
      find.byKey(const ValueKey('login.hero.section')),
    );
    final logoTop = tester.getTopLeft(
      find.byKey(const ValueKey('login.memory-map.logo')),
    );
    final titleTop = tester.getTopLeft(find.text('Memory Map'));

    expect(heroTop.dy, lessThan(logoTop.dy));
    expect(logoTop.dy, lessThan(titleTop.dy));
  });

  testWidgets('shouldRenderGoogleSvgLogo', (WidgetTester tester) async {
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

  testWidgets('shouldKeepGoogleButtonLargeAndAccessible', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, FakeAuthRepository());

    final buttonBox = tester.getSize(
      find.byKey(const ValueKey('login.google.button.box')),
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));

    expect(buttonBox.height, 62);
    expect(buttonBox.width, greaterThan(300));
    expect(button.onPressed, isNotNull);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('shouldRenderEnglishContent', (WidgetTester tester) async {
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
    expect(
      find.textContaining('By continuing', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('shouldRenderRussianContent', (WidgetTester tester) async {
    await pumpScreen(tester, FakeAuthRepository(), locale: const Locale('ru'));

    expect(find.text('Memory Map'), findsOneWidget);
    expect(find.text('У каждого места есть история'), findsOneWidget);
    expect(
      find.text(
        'Создавайте личную карту воспоминаний и делитесь ею с теми, кто вам дорог.',
      ),
      findsOneWidget,
    );
    expect(find.text('Продолжить с Google'), findsOneWidget);
    expect(
      find.textContaining('Продолжая', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('shouldCallLoginWithGoogle', (WidgetTester tester) async {
    final fakeRepository = FakeAuthRepository();

    await pumpScreen(tester, fakeRepository);
    await tapVisibleText(tester, 'Continue with Google');
    await tester.pump();

    expect(fakeRepository.loginCalls, 1);
  });

  testWidgets('shouldShowLoadingState', (WidgetTester tester) async {
    final fakeRepository = FakeAuthRepository()
      ..loginCompleter = Completer<AuthSession>();

    await pumpScreen(tester, fakeRepository);
    await tapVisibleText(tester, 'Continue with Google');
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));

    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.text('Signing in…'), findsOneWidget);

    fakeRepository.loginCompleter?.complete(session);
    await tester.pumpAndSettle();
  });

  testWidgets('shouldShowRussianLoadingState', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..loginCompleter = Completer<AuthSession>();

    await pumpScreen(tester, fakeRepository, locale: const Locale('ru'));
    await tapVisibleText(tester, 'Продолжить с Google');
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Выполняется вход…'), findsOneWidget);

    fakeRepository.loginCompleter?.complete(session);
    await tester.pumpAndSettle();
  });

  testWidgets('shouldShowSafeFailure', (WidgetTester tester) async {
    final fakeRepository = FakeAuthRepository()
      ..loginFailure = const AuthApplicationException(NetworkUnavailable());

    await pumpScreen(tester, fakeRepository);
    await tapVisibleText(tester, 'Continue with Google');
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

  testWidgets('shouldShowRussianSafeFailure', (
    WidgetTester tester,
  ) async {
    final fakeRepository = FakeAuthRepository()
      ..loginFailure = const AuthApplicationException(NetworkUnavailable());

    await pumpScreen(tester, fakeRepository, locale: const Locale('ru'));
    await tapVisibleText(tester, 'Продолжить с Google');
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Нет подключения к интернету. Проверьте соединение и повторите попытку.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('NetworkUnavailable'), findsNothing);
  });

  testWidgets('shouldNotExposeTokensOrClientId', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, FakeAuthRepository());

    expect(find.textContaining('signed-access-token'), findsNothing);
    expect(find.textContaining('raw-refresh-token'), findsNothing);
    expect(find.textContaining('client-id'), findsNothing);
  });

  testWidgets('shouldNotOverflowOnSmallPortraitScreen', (
    WidgetTester tester,
  ) async {
    await setSmallPortraitSurface(tester);

    await pumpScreen(tester, FakeAuthRepository());

    expect(tester.takeException(), isNull);
  });

  testWidgets('shouldNotOverflowWithLargeTextScale', (
    WidgetTester tester,
  ) async {
    await setSmallPortraitSurface(tester);

    await pumpScreen(
      tester,
      FakeAuthRepository(),
      textScaler: const TextScaler.linear(1.5),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('shouldNotOverflowWithRussianLocale', (
    WidgetTester tester,
  ) async {
    await setSmallPortraitSurface(tester);

    await pumpScreen(
      tester,
      FakeAuthRepository(),
      locale: const Locale('ru'),
      textScaler: const TextScaler.linear(1.3),
    );

    expect(tester.takeException(), isNull);
  });
}

Future<void> tapVisibleText(WidgetTester tester, String text) async {
  final finder = find.text(text);

  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> pumpScreen(
  WidgetTester tester,
  FakeAuthRepository fakeRepository, {
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
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
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const LoginScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> setPortraitSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> setSmallPortraitSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
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
