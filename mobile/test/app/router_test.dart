import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('Router authentication', () {
    testWidgets('shouldRouteLoadingStateToAuthChecking', (
      WidgetTester tester,
    ) async {
      final restoreCompleter = Completer<AuthSession?>();
      final fakeAuthRepository = FakeAuthRepository()
        ..restoreCompleter = restoreCompleter;
      addTearDown(() {
        if (!restoreCompleter.isCompleted) {
          restoreCompleter.complete(null);
        }
      });

      await pumpApp(tester, fakeAuthRepository);

      expect(find.textContaining('Checking your session'), findsOneWidget);
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
      final fakeAuthRepository = FakeAuthRepository()
        ..loginCompleter = Completer<AuthSession>();

      await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();
      await tapVisibleText(tester, 'Continue with Google');
      await tester.pump();

      expect(find.textContaining('Signing in'), findsOneWidget);

      fakeAuthRepository.loginCompleter?.complete(session);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRouteLoginFailureStateToLogin', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()
        ..loginFailure = const AuthApplicationException(NetworkUnavailable());

      await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();
      await tapVisibleText(tester, 'Continue with Google');
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
      final fakeAuthRepository = FakeAuthRepository()
        ..restoreFailure = const AuthApplicationException(NetworkUnavailable());

      await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();

      expect(find.text('Could not restore your session'), findsOneWidget);
    });

    testWidgets('shouldRouteUnexpectedErrorToUnexpectedErrorScreen', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()
        ..restoreFailure = const UnexpectedAuthException();

      await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('shouldRouteAuthenticatedStateToStoriesLanding', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;

      await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();

      expect(find.text('Hi, Ada Lovelace! 👋'), findsOneWidget);
      expect(find.text('Your stories'), findsOneWidget);
      expect(find.text('Welcome, Ada Lovelace'), findsNothing);
    });

    testWidgets('authenticatedUserCannotRemainOnLoginRoute', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;

      await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go(authLoginRoute);
      await tester.pumpAndSettle();

      expect(find.text('Your stories'), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('homeRouteRedirectsAuthenticatedUserToStories', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;

      await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go(homeRoute);
      await tester.pumpAndSettle();

      expect(find.text('Your stories'), findsOneWidget);
    });

    testWidgets('unauthenticatedUserCannotRemainOnStoryRoutes', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, FakeAuthRepository());
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Continue with Google'));
      for (final route in <String>[
        storiesRoute,
        createStoryRoute,
        '/stories/story-1',
        '/stories/story-1/edit',
        homeRoute,
      ]) {
        GoRouter.of(context).go(route);
        await tester.pumpAndSettle();

        expect(find.text('Continue with Google'), findsOneWidget);
        expect(find.text('Your stories'), findsNothing);
      }
    });

    testWidgets('shouldRouteUnauthenticatedAfterSessionInvalidationToLogin', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final container = await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();

      await container.read(authNotifierProvider.notifier).logout();
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Your stories'), findsNothing);
    });
  });

  group('Router story navigation', () {
    testWidgets('shouldOpenCreateStoryAndCancelBackToStories', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;

      await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();
      await tapButton(
        tester,
        find.byKey(const ValueKey('stories.create.section-action')),
      );

      expect(find.text('New story'), findsOneWidget);

      await tapButton(
        tester,
        find.byKey(const ValueKey('create-story.cancel-action')),
      );

      expect(find.text('Your stories'), findsOneWidget);
    });

    testWidgets('shouldReplaceCreateWithDetailsAfterCreateSuccess', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeStoryRepository = FakeStoryRepository()
        ..createResult = createdStory
        ..storyResult = createdOwnerStory;

      await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
      );
      await tester.pumpAndSettle();
      await tapButton(
        tester,
        find.byKey(const ValueKey('stories.create.section-action')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('create-story.title-field')),
        createdStory.title,
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('create-story.submit-action')),
      );

      expect(find.text('About this story'), findsOneWidget);
      expect(find.text(createdStory.title), findsOneWidget);
      expect(
        fakeStoryRepository.receivedGetStoryIds,
        contains(createdStory.id),
      );

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.back-action')),
      );

      expect(find.text('Your stories'), findsOneWidget);
      expect(find.text('New story'), findsNothing);
    });

    testWidgets('shouldOpenDetailsFromSelectedStoryAndBackToStories', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;

      await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();

      expect(find.text('About this story'), findsOneWidget);
      expect(find.text(ownerStory.story.description!), findsWidgets);

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.back-action')),
      );

      expect(find.text('Your stories'), findsOneWidget);
    });

    testWidgets('shouldOpenEditFromDetailsAndCancelBackToDetails', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;

      await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.edit-action')),
      );

      expect(find.text('Edit story'), findsOneWidget);

      await tapButton(
        tester,
        find.byKey(const ValueKey('edit-story.cancel-action')),
      );

      expect(find.text('About this story'), findsOneWidget);
      expect(find.text('Edit story'), findsNothing);
    });

    testWidgets('shouldSynchronizeDetailsAndStoriesAfterEditSuccess', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeStoryRepository = FakeStoryRepository()
        ..updateStoryResult = updatedOwnerStory;

      await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.edit-action')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit-story.title-field')),
        updatedOwnerStory.story.title,
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit-story.description-field')),
        updatedOwnerStory.story.description!,
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('edit-story.save-action')),
      );

      expect(fakeStoryRepository.updateStoryCalls, 1);
      expect(find.text('Edit story'), findsNothing);
      expect(find.text(updatedOwnerStory.story.title), findsOneWidget);
      expect(find.text(updatedOwnerStory.story.description!), findsWidgets);

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.back-action')),
      );

      expect(find.text('Your stories'), findsOneWidget);
      expect(find.text(updatedOwnerStory.story.title), findsOneWidget);
      expect(find.text(updatedOwnerStory.story.description!), findsOneWidget);
    });

    testWidgets('shouldBuildDirectDetailsRouteWithPathStoryId', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeStoryRepository = FakeStoryRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}');
      await tester.pumpAndSettle();

      expect(find.text('About this story'), findsOneWidget);
      expect(
        fakeStoryRepository.receivedGetStoryIds,
        contains(ownerStory.story.id),
      );
    });

    testWidgets('shouldBuildDirectEditRouteByLoadingStoryDetails', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeStoryRepository = FakeStoryRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/edit');
      await tester.pumpAndSettle();

      expect(find.text('Edit story'), findsOneWidget);
      expect(
        fakeStoryRepository.receivedGetStoryIds,
        contains(ownerStory.story.id),
      );
    });

    testWidgets('shouldNotExposeEditActionForEditorAndViewer', (
      WidgetTester tester,
    ) async {
      for (final role in <StoryRole>[StoryRole.editor, StoryRole.viewer]) {
        final fakeAuthRepository = FakeAuthRepository()
          ..restoreResult = session;
        final fakeStoryRepository = FakeStoryRepository()
          ..storiesResult = <UserStory>[userStory(role: role)]
          ..storyResult = userStory(role: role);

        await pumpApp(
          tester,
          fakeAuthRepository,
          storyRepository: fakeStoryRepository,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(ownerStory.story.title));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('story-details.edit-action')),
          findsNothing,
        );
      }
    });
  });

  group('Router stability', () {
    testWidgets('shouldNotLoopWhenAlreadyOnCorrectDestination', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, FakeAuthRepository());
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
    });

    test('shouldKeepRouterInstanceStableAcrossAuthChanges', () async {
      final fakeAuthRepository = FakeAuthRepository();
      final container = createContainer(fakeAuthRepository);
      addTearDown(container.dispose);

      final firstRouter = container.read(appRouterProvider);
      await container.read(authNotifierProvider.future);
      await container.read(authNotifierProvider.notifier).loginWithGoogle();
      final secondRouter = container.read(appRouterProvider);

      expect(identical(firstRouter, secondRouter), isTrue);
    });

    test('shouldKeepRouterInstanceStableDuringLogoutTransition', () async {
      final fakeAuthRepository = FakeAuthRepository()
        ..restoreResult = session
        ..logoutCompleter = Completer<void>();
      final container = createContainer(fakeAuthRepository);
      addTearDown(container.dispose);

      final firstRouter = container.read(appRouterProvider);
      await container.read(authNotifierProvider.future);
      final logout = container.read(authNotifierProvider.notifier).logout();
      await pumpEventQueue();
      final secondRouter = container.read(appRouterProvider);

      expect(identical(firstRouter, secondRouter), isTrue);

      fakeAuthRepository.logoutCompleter?.complete();
      await logout;
    });
  });
}

Future<void> tapVisibleText(WidgetTester tester, String text) async {
  final finder = find.text(text);

  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> tapButton(
  WidgetTester tester,
  Finder finder,
) async {
  await tester.pump();
  final widget = tester.widget<Widget>(finder);
  final onPressed = switch (widget) {
    FilledButton(:final onPressed) => onPressed,
    OutlinedButton(:final onPressed) => onPressed,
    IconButton(:final onPressed) => onPressed,
    TextButton(:final onPressed) => onPressed,
    _ => throw StateError('Unsupported button widget: $widget'),
  };

  onPressed?.call();
  await tester.pumpAndSettle();
}

Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  FakeAuthRepository fakeAuthRepository, {
  FakeStoryRepository? storyRepository,
}) async {
  final container = createContainer(
    fakeAuthRepository,
    storyRepository: storyRepository,
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MemoryMapApp(),
    ),
  );
  await tester.pump();

  return container;
}

ProviderContainer createContainer(
  FakeAuthRepository fakeAuthRepository, {
  FakeStoryRepository? storyRepository,
}) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(fakeAuthRepository),
      storyRepositoryProvider.overrideWithValue(
        storyRepository ?? FakeStoryRepository(),
      ),
    ],
  );
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

Story story({
  String id = 'story-1',
  String title = 'Our story',
  String? description = 'Together since 2021',
}) {
  return Story(
    id: id,
    title: title,
    description: description,
    createdAt: DateTime.utc(2026, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
  );
}

UserStory userStory({
  String id = 'story-1',
  String title = 'Our story',
  String? description = 'Together since 2021',
  StoryRole role = StoryRole.owner,
}) {
  return UserStory(
    story: story(
      id: id,
      title: title,
      description: description,
    ),
    role: role,
  );
}

final UserStory ownerStory = userStory();
final Story createdStory = story(
  id: 'created-story',
  title: 'Created story',
  description: 'Created description',
);
final UserStory createdOwnerStory = UserStory(
  story: createdStory,
  role: StoryRole.owner,
);
final UserStory updatedOwnerStory = userStory(
  title: 'Updated story',
  description: 'Updated description',
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

final class FakeStoryRepository implements StoryRepository {
  int createStoryCalls = 0;
  int getStoriesCalls = 0;
  int getStoryCalls = 0;
  int updateStoryCalls = 0;

  Story createResult = createdStory;
  UserStory storyResult = ownerStory;
  UserStory updateStoryResult = updatedOwnerStory;
  List<UserStory> storiesResult = <UserStory>[ownerStory];
  final List<String> receivedGetStoryIds = <String>[];

  @override
  Future<Story> createStory({
    required String title,
    String? description,
  }) async {
    createStoryCalls += 1;
    return createResult;
  }

  @override
  Future<UserStory> getStory(String storyId) async {
    getStoryCalls += 1;
    receivedGetStoryIds.add(storyId);
    if (storyId == createdStory.id) {
      return createdOwnerStory;
    }

    return storyResult;
  }

  @override
  Future<List<UserStory>> getStories() async {
    getStoriesCalls += 1;
    return storiesResult;
  }

  @override
  Future<UserStory> updateStory(UpdateStoryInput input) async {
    updateStoryCalls += 1;
    return updateStoryResult;
  }
}

final class UnexpectedAuthException implements Exception {
  const UnexpectedAuthException();
}
