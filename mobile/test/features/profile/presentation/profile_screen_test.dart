import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/app/language/app_language_preference.dart';
import 'package:memory_map/app/language/app_language_preference_storage.dart';
import 'package:memory_map/app/language/file_app_language_preference_storage.dart';
import 'package:memory_map/features/auth/application/auth_application_exception.dart';
import 'package:memory_map/features/auth/application/auth_application_providers.dart';
import 'package:memory_map/features/auth/application/auth_network_providers.dart';
import 'package:memory_map/features/auth/data/storage/auth_session_storage.dart';
import 'package:memory_map/features/auth/data/storage/flutter_secure_auth_session_storage.dart';
import 'package:memory_map/features/auth/domain/auth_failure.dart';
import 'package:memory_map/features/auth/domain/auth_repository.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';
import 'package:memory_map/features/auth/domain/authorized_session_manager.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/profile/application/account_deletion_exception.dart';
import 'package:memory_map/features/profile/application/account_display_name_exception.dart';
import 'package:memory_map/features/profile/application/profile_application_providers.dart';
import 'package:memory_map/features/profile/domain/account_deletion_failure.dart';
import 'package:memory_map/features/profile/domain/account_display_name_failure.dart';
import 'package:memory_map/features/profile/domain/account_repository.dart';
import 'package:memory_map/features/profile/presentation/profile_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('ProfileScreen rendering', () {
    testWidgets('shouldRenderSessionDisplayNameAvatarAndProfileSections', (
      WidgetTester tester,
    ) async {
      await pumpProfileScreen(tester, FakeAuthRepository());

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsWidgets);
      expect(find.text('Memory Creator'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Profile Photo'), findsOneWidget);
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);

      await scrollUntilFound(tester, find.text('LEGAL & SUPPORT'));

      expect(find.text('LEGAL & SUPPORT'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Use'), findsOneWidget);
      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('About Memory Story'), findsOneWidget);

      await scrollUntilFound(tester, find.text('ACCOUNT ACTIONS'));

      expect(find.text('ACCOUNT ACTIONS'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
      expect(find.text('Delete Profile'), findsOneWidget);
      expect(find.textContaining('ada@example'), findsNothing);
      expect(find.textContaining('signed-access-token'), findsNothing);
      expect(find.textContaining('raw-refresh-token'), findsNothing);
      expect(find.textContaining('user-id'), findsNothing);
    });

    testWidgets('shouldRenderRussianProfileLabels', (
      WidgetTester tester,
    ) async {
      await pumpProfileScreen(
        tester,
        FakeAuthRepository(),
        locale: const Locale('ru'),
      );

      expect(find.text('Профиль'), findsOneWidget);
      expect(find.text('Автор воспоминаний'), findsOneWidget);
      expect(find.text('Фото профиля'), findsOneWidget);
      expect(find.text('Отображаемое имя'), findsOneWidget);
      expect(find.text('Язык'), findsOneWidget);
      expect(find.text('Системный'), findsOneWidget);

      await scrollUntilFound(tester, find.text('Выйти'));

      expect(find.text('Выйти'), findsOneWidget);
      expect(find.text('Удалить профиль'), findsOneWidget);
    });

    testWidgets('shouldReuseGoogleAvatarWhenAvailable', (
      WidgetTester tester,
    ) async {
      await pumpProfileScreen(tester, FakeAuthRepository());

      final avatar = tester.widget<CircleAvatar>(
        find.descendant(
          of: find.byKey(const ValueKey('profile.avatar')),
          matching: find.byType(CircleAvatar),
        ),
      );

      expect(avatar.foregroundImage, isA<NetworkImage>());
      expect(
        (avatar.foregroundImage as NetworkImage).url,
        'https://example.com/avatar.png',
      );
    });

    testWidgets('shouldRenderInitialFallbackWhenAvatarIsAbsent', (
      WidgetTester tester,
    ) async {
      await pumpProfileScreen(
        tester,
        FakeAuthRepository()..restoreResult = sessionWithoutAvatar,
      );

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile.avatar')),
          matching: find.text('A'),
        ),
        findsOneWidget,
      );
    });
  });

  group('ProfileScreen actions', () {
    testWidgets('shouldOpenAvatarActionsFromProfilePhotoRow', (
      WidgetTester tester,
    ) async {
      await pumpProfileScreen(tester, FakeAuthRepository());

      await tap(tester, find.byKey(const ValueKey('profile.photo-action')));
      await tester.pumpAndSettle();

      expect(find.text('Choose photo'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile.avatar.choose-action')),
        findsOneWidget,
      );
    });

    testWidgets('shouldOpenLanguageScreenFromLanguageRow', (
      WidgetTester tester,
    ) async {
      var languageCalls = 0;
      await pumpProfileScreen(
        tester,
        FakeAuthRepository(),
        onLanguage: () {
          languageCalls += 1;
        },
      );

      await tap(tester, find.byKey(const ValueKey('profile.language-action')));

      expect(languageCalls, 1);
    });

    testWidgets('shouldRenderPersistedLanguagePreferenceValue', (
      WidgetTester tester,
    ) async {
      await pumpProfileScreen(
        tester,
        FakeAuthRepository(),
        languageStorage: FakeAppLanguagePreferenceStorage(
          initialPreference: AppLanguagePreference.english,
        ),
      );

      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('shouldOpenAvatarActionsFromCameraBadge', (
      WidgetTester tester,
    ) async {
      await pumpProfileScreen(tester, FakeAuthRepository());

      await tap(
        tester,
        find.byKey(const ValueKey('profile.photo.camera-action')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose photo'), findsOneWidget);
    });

    testWidgets('shouldShowReplaceAndRemoveActionsForCustomAvatar', (
      WidgetTester tester,
    ) async {
      await pumpProfileScreen(
        tester,
        FakeAuthRepository()..restoreResult = sessionWithCustomAvatar,
      );

      await tap(tester, find.byKey(const ValueKey('profile.photo-action')));
      await tester.pumpAndSettle();

      expect(find.text('Replace photo'), findsOneWidget);
      expect(find.text('Remove photo'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile.avatar.remove-action')),
        findsOneWidget,
      );
    });

    testWidgets('shouldOpenDisplayNameEditorWithCurrentNamePrefilled', (
      WidgetTester tester,
    ) async {
      final accountRepository = FakeAccountRepository();

      await pumpProfileScreen(
        tester,
        FakeAuthRepository(),
        accountRepository: accountRepository,
      );

      await tap(
        tester,
        find.byKey(const ValueKey('profile.display-name-action')),
      );

      expect(find.text('Edit display name'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile.display-name.input')),
        findsOneWidget,
      );
      expect(find.text('Ada Lovelace'), findsWidgets);
      expect(accountRepository.updateDisplayNameCalls, 0);
    });

    testWidgets('shouldRejectWhitespaceOnlyDisplayNameInEditor', (
      WidgetTester tester,
    ) async {
      final accountRepository = FakeAccountRepository();

      await pumpProfileScreen(
        tester,
        FakeAuthRepository(),
        accountRepository: accountRepository,
      );

      await tap(
        tester,
        find.byKey(const ValueKey('profile.display-name-action')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile.display-name.input')),
        '   ',
      );
      await tester.pump();

      final saveButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('profile.display-name.save-action')),
      );
      expect(saveButton.onPressed, isNull);
      expect(accountRepository.updateDisplayNameCalls, 0);
    });

    testWidgets('shouldCancelDisplayNameEditWithoutSendingRequest', (
      WidgetTester tester,
    ) async {
      final accountRepository = FakeAccountRepository();

      await pumpProfileScreen(
        tester,
        FakeAuthRepository(),
        accountRepository: accountRepository,
      );

      await tap(
        tester,
        find.byKey(const ValueKey('profile.display-name-action')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile.display-name.input')),
        'Grace Hopper',
      );
      await tap(
        tester,
        find.byKey(const ValueKey('profile.display-name.cancel-action')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit display name'), findsNothing);
      expect(accountRepository.updateDisplayNameCalls, 0);
      expect(find.text('Ada Lovelace'), findsWidgets);
    });

    testWidgets('shouldSaveTrimmedDisplayNameAndUpdateProfileSession', (
      WidgetTester tester,
    ) async {
      final accountRepository = FakeAccountRepository()
        ..updatedDisplayNameUser = AuthUser(
          id: 'user-id',
          displayName: 'Анна-Мария',
          avatarUrl: null,
        );
      final sessionStorage = FakeAuthSessionStorage();

      await pumpProfileScreen(
        tester,
        FakeAuthRepository()..restoreResult = sessionWithoutAvatar,
        accountRepository: accountRepository,
        sessionStorage: sessionStorage,
      );

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile.avatar')),
          matching: find.text('A'),
        ),
        findsOneWidget,
      );

      await tap(
        tester,
        find.byKey(const ValueKey('profile.display-name-action')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile.display-name.input')),
        '  Анна-Мария  ',
      );
      await tap(
        tester,
        find.byKey(const ValueKey('profile.display-name.save-action')),
      );
      await tester.pumpAndSettle();

      expect(accountRepository.updateDisplayNameCalls, 1);
      expect(accountRepository.updateDisplayNameValue, 'Анна-Мария');
      expect(sessionStorage.writtenSession?.user.displayName, 'Анна-Мария');
      expect(find.text('Анна-Мария'), findsWidgets);
      await scrollUntilFound(
        tester,
        find.byKey(const ValueKey('profile.avatar')),
        scrollDelta: -120,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile.avatar')),
          matching: find.text('А'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shouldKeepDisplayNameEditorOpenAfterSaveFailure', (
      WidgetTester tester,
    ) async {
      final accountRepository = FakeAccountRepository()
        ..failure = const AccountDisplayNameApplicationException(
          AccountDisplayNameNetworkUnavailable(),
        );

      await pumpProfileScreen(
        tester,
        FakeAuthRepository(),
        accountRepository: accountRepository,
      );

      await tap(
        tester,
        find.byKey(const ValueKey('profile.display-name-action')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile.display-name.input')),
        'Grace Hopper',
      );
      await tap(
        tester,
        find.byKey(const ValueKey('profile.display-name.save-action')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit display name'), findsOneWidget);
      final textField = tester.widget<TextField>(
        find.byKey(const ValueKey('profile.display-name.input')),
      );
      expect(textField.controller?.text, 'Grace Hopper');
      expect(
        find.text(
          'Display name could not be saved. Check your connection and try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shouldCallPlaceholderCallbacksFromLegalRows', (
      WidgetTester tester,
    ) async {
      var privacyCalls = 0;
      var termsCalls = 0;
      var helpCalls = 0;
      var aboutCalls = 0;

      await pumpProfileScreen(
        tester,
        FakeAuthRepository(),
        onPrivacyPolicy: () {
          privacyCalls += 1;
        },
        onTermsOfUse: () {
          termsCalls += 1;
        },
        onHelpSupport: () {
          helpCalls += 1;
        },
        onAbout: () {
          aboutCalls += 1;
        },
      );

      await tap(tester, find.byKey(const ValueKey('profile.privacy-action')));
      await tap(tester, find.byKey(const ValueKey('profile.terms-action')));
      await tap(tester, find.byKey(const ValueKey('profile.help-action')));
      await tap(tester, find.byKey(const ValueKey('profile.about-action')));

      expect(privacyCalls, 1);
      expect(termsCalls, 1);
      expect(helpCalls, 1);
      expect(aboutCalls, 1);
    });

    testWidgets('shouldCallAuthLogoutAndBlockDuplicateWhilePending', (
      WidgetTester tester,
    ) async {
      final repository = FakeAuthRepository()
        ..logoutCompleter = Completer<void>();

      await pumpProfileScreen(tester, repository);
      await tap(tester, find.byKey(const ValueKey('profile.logout-action')));
      await tester.pump();
      await tap(tester, find.byKey(const ValueKey('profile.logout-action')));
      await tester.pump();

      expect(repository.logoutCalls, 1);
      expect(repository.logoutSession, session);
      expect(find.text('Logging out…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repository.logoutCompleter?.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRenderSafeLogoutFailureAndAllowRetry', (
      WidgetTester tester,
    ) async {
      final repository = FakeAuthRepository()
        ..logoutFailure = const AuthApplicationException(
          NetworkUnavailable(),
        );

      await pumpProfileScreen(tester, repository);
      await tap(tester, find.byKey(const ValueKey('profile.logout-action')));
      await tester.pumpAndSettle();

      expect(
        find.text('No network connection. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('AuthApplicationException'), findsNothing);
      expect(find.textContaining('NetworkUnavailable'), findsNothing);

      repository.logoutFailure = null;
      await tap(tester, find.byKey(const ValueKey('profile.logout-action')));
      await tester.pump();

      expect(repository.logoutCalls, 2);
    });

    testWidgets('shouldShowDeleteProfileConfirmationWithoutCallingRepository', (
      WidgetTester tester,
    ) async {
      final accountRepository = FakeAccountRepository();

      await pumpProfileScreen(
        tester,
        FakeAuthRepository(),
        accountRepository: accountRepository,
      );

      await tap(tester, find.byKey(const ValueKey('profile.delete-action')));
      await tester.pumpAndSettle();

      expect(find.text('Delete profile?'), findsOneWidget);
      expect(
        find.text(
          'This permanently deletes your account and removes your access to Memory Story. Stories that still need an owner must be resolved first.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('profile.delete.confirm-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('profile.delete.unavailable-action')),
        findsNothing,
      );
      expect(accountRepository.deleteCurrentAccountCalls, 0);
    });

    testWidgets('shouldDeleteProfileAndInvalidateSessionWithoutLogoutCall', (
      WidgetTester tester,
    ) async {
      final authRepository = FakeAuthRepository();
      final accountRepository = FakeAccountRepository();
      final sessionManager = FakeAuthorizedSessionManager();

      await pumpProfileScreen(
        tester,
        authRepository,
        accountRepository: accountRepository,
        sessionManager: sessionManager,
      );

      await tap(tester, find.byKey(const ValueKey('profile.delete-action')));
      await tap(
        tester,
        find.byKey(const ValueKey('profile.delete.confirm-action')),
      );
      await tester.pumpAndSettle();

      expect(accountRepository.deleteCurrentAccountCalls, 1);
      expect(sessionManager.invalidatedSessions, <AuthSession>[session]);
      expect(authRepository.logoutCalls, 0);
    });

    testWidgets('shouldBlockDuplicateDeleteProfileWhilePending', (
      WidgetTester tester,
    ) async {
      final deleteCompleter = Completer<void>();
      final accountRepository = FakeAccountRepository()
        ..deleteCompleter = deleteCompleter;

      await pumpProfileScreen(
        tester,
        FakeAuthRepository(),
        accountRepository: accountRepository,
      );

      await tap(tester, find.byKey(const ValueKey('profile.delete-action')));
      await tap(
        tester,
        find.byKey(const ValueKey('profile.delete.confirm-action')),
      );
      await tester.pump();

      final action = tester.widget<FilledButton>(
        find.byKey(const ValueKey('profile.delete.confirm-action')),
      );
      expect(action.onPressed, isNull);
      expect(find.text('Deleting...'), findsOneWidget);

      deleteCompleter.complete();
      await tester.pumpAndSettle();
      expect(accountRepository.deleteCurrentAccountCalls, 1);
    });

    testWidgets('shouldKeepProfileAvailableAfterOwnershipConflict', (
      WidgetTester tester,
    ) async {
      final accountRepository = FakeAccountRepository()
        ..failure = const AccountDeletionApplicationException(
          AccountDeletionOwnershipConflict(),
        );
      final sessionManager = FakeAuthorizedSessionManager();

      await pumpProfileScreen(
        tester,
        FakeAuthRepository(),
        accountRepository: accountRepository,
        sessionManager: sessionManager,
      );

      await tap(tester, find.byKey(const ValueKey('profile.delete-action')));
      await tap(
        tester,
        find.byKey(const ValueKey('profile.delete.confirm-action')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('profile.screen')), findsOneWidget);
      expect(
        find.text(
          'One of your shared stories still needs an owner. Resolve story ownership before deleting your profile.',
        ),
        findsWidgets,
      );
      expect(sessionManager.invalidatedSessions, isEmpty);
    });

    testWidgets('shouldKeepProfileAvailableAfterGenericDeleteFailure', (
      WidgetTester tester,
    ) async {
      final accountRepository = FakeAccountRepository()
        ..failure = const AccountDeletionApplicationException(
          AccountDeletionNetworkUnavailable(),
        );

      await pumpProfileScreen(
        tester,
        FakeAuthRepository(),
        accountRepository: accountRepository,
      );

      await tap(tester, find.byKey(const ValueKey('profile.delete-action')));
      await tap(
        tester,
        find.byKey(const ValueKey('profile.delete.confirm-action')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('profile.screen')), findsOneWidget);
      expect(
        find.text(
          'Profile could not be deleted. Check your connection and try again.',
        ),
        findsWidgets,
      );
    });
  });

  testWidgets('ProfilePlaceholderScreen shouldRenderTitleBodyAndBackAction', (
    WidgetTester tester,
  ) async {
    var backCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProfilePlaceholderScreen(
          title: 'Privacy Policy',
          body: 'The full privacy policy will be added before public release.',
          onBack: () {
            backCalls += 1;
          },
        ),
      ),
    );

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(
      find.text('The full privacy policy will be added before public release.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('profile.placeholder.back-action')),
    );
    await tester.pump();

    expect(backCalls, 1);
  });
}

Future<void> pumpProfileScreen(
  WidgetTester tester,
  FakeAuthRepository repository, {
  Locale locale = const Locale('en'),
  VoidCallback? onBack,
  VoidCallback? onProfilePhoto,
  VoidCallback? onDisplayName,
  VoidCallback? onLanguage,
  VoidCallback? onPrivacyPolicy,
  VoidCallback? onTermsOfUse,
  VoidCallback? onHelpSupport,
  VoidCallback? onAbout,
  FakeAccountRepository? accountRepository,
  FakeAuthorizedSessionManager? sessionManager,
  FakeAuthSessionStorage? sessionStorage,
  FakeAppLanguagePreferenceStorage? languageStorage,
}) async {
  final resolvedSessionStorage = sessionStorage ?? FakeAuthSessionStorage();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        authSessionStorageProvider.overrideWithValue(
          resolvedSessionStorage,
        ),
        accountRepositoryProvider.overrideWithValue(
          accountRepository ?? FakeAccountRepository(),
        ),
        authorizedSessionManagerProvider.overrideWithValue(
          sessionManager ??
              FakeAuthorizedSessionManager(
                sessionStorage: resolvedSessionStorage,
              ),
        ),
        appLanguagePreferenceStorageProvider.overrideWithValue(
          languageStorage ?? FakeAppLanguagePreferenceStorage(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProfileScreen(
          onBack: onBack ?? () {},
          onProfilePhoto: onProfilePhoto ?? () {},
          onDisplayName: onDisplayName ?? () {},
          onLanguage: onLanguage ?? () {},
          onPrivacyPolicy: onPrivacyPolicy ?? () {},
          onTermsOfUse: onTermsOfUse ?? () {},
          onHelpSupport: onHelpSupport ?? () {},
          onAbout: onAbout ?? () {},
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

final class FakeAppLanguagePreferenceStorage
    implements AppLanguagePreferenceStorage {
  FakeAppLanguagePreferenceStorage({
    AppLanguagePreference? initialPreference,
  }) : storedPreference = initialPreference;

  AppLanguagePreference? storedPreference;

  @override
  Future<AppLanguagePreference?> read() async {
    return storedPreference;
  }

  @override
  Future<void> write(AppLanguagePreference preference) async {
    storedPreference = preference;
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  if (finder.hitTestable().evaluate().isEmpty) {
    await scrollUntilFound(tester, finder);
  }
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> scrollUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxScrolls = 8,
  double scrollDelta = 120,
}) async {
  if (finder.hitTestable().evaluate().isNotEmpty) {
    return;
  }

  final scrollable = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );
  if (scrollable.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(
      finder,
      scrollDelta,
      scrollable: scrollable.first,
      maxScrolls: maxScrolls,
    );
    await tester.pumpAndSettle();
    return;
  }

  if (finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }
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

final AuthSession sessionWithoutAvatar = AuthSession(
  user: AuthUser(
    id: 'user-id',
    displayName: 'Ada Lovelace',
    avatarUrl: null,
  ),
  tokens: AuthTokens(
    accessToken: 'signed-access-token',
    refreshToken: 'raw-refresh-token',
  ),
);

final AuthSession sessionWithCustomAvatar = AuthSession(
  user: AuthUser(
    id: 'user-id',
    displayName: 'Ada Lovelace',
    avatarUrl: '/api/v1/me/avatar/1',
    hasCustomAvatar: true,
  ),
  tokens: AuthTokens(
    accessToken: 'signed-access-token',
    refreshToken: 'raw-refresh-token',
  ),
);

final class FakeAuthRepository implements AuthRepository {
  int logoutCalls = 0;
  AuthSession? logoutSession;
  AuthSession? restoreResult = session;
  Object? logoutFailure;
  Completer<void>? logoutCompleter;

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

  @override
  Future<AuthSession?> restoreSession() async {
    return restoreResult;
  }
}

final class FakeAccountRepository implements AccountRepository {
  int deleteCurrentAccountCalls = 0;
  int updateDisplayNameCalls = 0;
  int uploadCurrentUserAvatarCalls = 0;
  int removeCurrentUserAvatarCalls = 0;
  String? updateDisplayNameValue;
  Object? failure;
  Completer<void>? deleteCompleter;
  Completer<AuthUser>? displayNameCompleter;
  AuthUser? updatedDisplayNameUser;

  @override
  Future<void> deleteCurrentAccount() async {
    deleteCurrentAccountCalls += 1;

    final completer = deleteCompleter;
    if (completer != null) {
      return completer.future;
    }

    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<AuthUser> updateDisplayName(String displayName) async {
    updateDisplayNameCalls += 1;
    updateDisplayNameValue = displayName;

    final completer = displayNameCompleter;
    if (completer != null) {
      return completer.future;
    }

    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }

    return updatedDisplayNameUser ??
        AuthUser(
          id: 'user-id',
          displayName: displayName,
          avatarUrl: session.user.avatarUrl,
          hasCustomAvatar: session.user.hasCustomAvatar,
        );
  }

  @override
  Future<AuthUser> uploadCurrentUserAvatar(PreparedPhotoUpload photo) async {
    uploadCurrentUserAvatarCalls += 1;
    return AuthUser(
      id: 'user-id',
      displayName: 'Ada Lovelace',
      avatarUrl: '/api/v1/me/avatar/1',
      hasCustomAvatar: true,
    );
  }

  @override
  Future<AuthUser> removeCurrentUserAvatar() async {
    removeCurrentUserAvatarCalls += 1;
    return AuthUser(
      id: 'user-id',
      displayName: 'Ada Lovelace',
      avatarUrl: 'https://example.com/avatar.png',
    );
  }
}

final class FakeAuthSessionStorage implements AuthSessionStorage {
  AuthSession? writtenSession;

  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async => writtenSession;

  @override
  Future<void> write(AuthSession session) async {
    writtenSession = session;
  }
}

final class FakeAuthorizedSessionManager implements AuthorizedSessionManager {
  FakeAuthorizedSessionManager({
    FakeAuthSessionStorage? sessionStorage,
  }) : _sessionStorage = sessionStorage;

  final List<AuthSession> invalidatedSessions = <AuthSession>[];
  final FakeAuthSessionStorage? _sessionStorage;
  AuthSession? currentSession = session;

  @override
  Future<AuthSession?> getCurrentSession() async {
    return currentSession;
  }

  @override
  Future<AuthSession> refreshCurrentSession(AuthSession currentSession) {
    throw UnimplementedError();
  }

  @override
  Future<void> invalidateCurrentSession(AuthSession currentSession) async {
    invalidatedSessions.add(currentSession);
  }

  @override
  Future<AuthSession?> updateCurrentSessionUserIfStillCurrent({
    required AuthSession expectedSession,
    required AuthUser updatedUser,
  }) async {
    final session = currentSession;
    if (session == null || session.user.id != expectedSession.user.id) {
      return null;
    }
    if (updatedUser.id != session.user.id) {
      return null;
    }

    final updatedSession = AuthSession(
      user: updatedUser,
      tokens: session.tokens,
    );
    await _sessionStorage?.write(updatedSession);
    currentSession = updatedSession;
    return updatedSession;
  }
}
