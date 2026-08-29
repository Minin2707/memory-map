import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memory_map/app/app.dart';
import 'package:memory_map/app/language/app_language_preference.dart';
import 'package:memory_map/app/language/app_language_preference_storage.dart';
import 'package:memory_map/app/language/file_app_language_preference_storage.dart';
import 'package:memory_map/app/router.dart';
import 'package:memory_map/features/auth/application/auth_application_exception.dart';
import 'package:memory_map/features/auth/application/auth_application_providers.dart';
import 'package:memory_map/features/auth/application/auth_notifier.dart';
import 'package:memory_map/features/auth/domain/auth_failure.dart';
import 'package:memory_map/features/auth/domain/auth_repository.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';
import 'package:memory_map/features/invite/application/invite_application_exception.dart';
import 'package:memory_map/features/invite/application/invite_application_providers.dart';
import 'package:memory_map/features/invite/application/pending_invite_notifier.dart';
import 'package:memory_map/features/invite/domain/accept_invite_input.dart';
import 'package:memory_map/features/invite/domain/create_invite_input.dart';
import 'package:memory_map/features/invite/domain/invite.dart';
import 'package:memory_map/features/invite/domain/invite_failure.dart';
import 'package:memory_map/features/invite/domain/invite_repository.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';
import 'package:memory_map/features/memory/presentation/location_picker_map_configuration.dart';
import 'package:memory_map/features/memory/presentation/location_picker_route.dart';
import 'package:memory_map/features/memory/presentation/memory_details_route.dart';
import 'package:memory_map/features/memory/presentation/memory_details_screen.dart';
import 'package:memory_map/features/memory/presentation/story_map_route.dart';
import 'package:memory_map/features/memory/presentation/story_map_screen.dart';
import 'package:memory_map/features/music/application/music_application_providers.dart';
import 'package:memory_map/features/music/domain/music_repository.dart';
import 'package:memory_map/features/music/domain/music_track.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';
import 'package:memory_map/features/music/domain/story_soundtrack_repository.dart';
import 'package:memory_map/features/participant/application/participant_application_exception.dart';
import 'package:memory_map/features/participant/application/participant_application_providers.dart';
import 'package:memory_map/features/participant/domain/leave_story_input.dart';
import 'package:memory_map/features/participant/domain/participant_failure.dart';
import 'package:memory_map/features/participant/domain/remove_story_participant_input.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/participant/domain/story_participant_repository.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_orchestrator.dart';
import 'package:memory_map/features/playback/application/audio/playback_audio_provider.dart';
import 'package:memory_map/features/playback/presentation/story_playback_route.dart';
import 'package:memory_map/features/playback/presentation/story_playback_screen.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/application/stories_notifier.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

import '../features/media/media_test_fixtures.dart' as media_fixtures;

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

      expect(find.text('Hi, Ada! 👋'), findsOneWidget);
      expect(find.textContaining('Ada Lovelace!'), findsNothing);
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
        '/stories/story-1/invite',
        '/stories/story-1/memories',
        '/stories/story-1/map',
        '/stories/story-1/memories/create',
        '/memories/memory-1',
        '/memories/memory-1/edit',
        profileRoute,
        profilePhotoRoute,
        profileDisplayNameRoute,
        profileLanguageRoute,
        profilePrivacyRoute,
        profileTermsRoute,
        profileHelpRoute,
        profileAboutRoute,
        memoryLocationPickerRoute,
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
    testWidgets('shouldOpenProfileFromStoriesAvatarAndBack', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;

      await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();
      await tapButton(
        tester,
        find.byKey(const ValueKey('stories.header.profile-action')),
      );

      expect(
        routerLocation(tester.element(find.text('Profile'))),
        profileRoute,
      );
      expect(find.byKey(const ValueKey('profile.screen')), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsWidgets);
      expect(find.textContaining('signed-access-token'), findsNothing);
      expect(find.textContaining('raw-refresh-token'), findsNothing);

      await tapButton(
        tester,
        find.byKey(const ValueKey('profile.back-action')),
      );

      expect(find.text('Your stories'), findsOneWidget);
    });

    testWidgets('shouldOpenProfilePlaceholderRoutes', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;

      await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go(profilePrivacyRoute);
      await tester.pumpAndSettle();

      expect(
        routerLocation(
          tester.element(
            find.byKey(const ValueKey('profile.placeholder.screen')),
          ),
        ),
        profilePrivacyRoute,
      );
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(
        find.text('The full privacy policy will be added before public release.'),
        findsOneWidget,
      );

      await tapButton(
        tester,
        find.byKey(const ValueKey('profile.placeholder.back-action')),
      );

      expect(find.byKey(const ValueKey('profile.screen')), findsOneWidget);
    });

    testWidgets('shouldOpenLanguagePreferenceFromProfileAndBack', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;

      await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();
      await tapButton(
        tester,
        find.byKey(const ValueKey('stories.header.profile-action')),
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('profile.language-action')),
      );

      expect(find.byKey(const ValueKey('profile-language.screen')), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(Dialog), findsNothing);

      await tapButton(
        tester,
        find.byKey(const ValueKey('profile-language.back-action')),
      );

      expect(find.byKey(const ValueKey('profile.screen')), findsOneWidget);
    });

    testWidgets('shouldOpenLanguagePreferenceDirectRouteWhenAuthenticated', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;

      await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go(profileLanguageRoute);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('profile-language.screen')), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
    });

    testWidgets('shouldChangeLanguageWithoutResettingCurrentRoute', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final languageStorage = FakeAppLanguagePreferenceStorage();

      await pumpApp(
        tester,
        fakeAuthRepository,
        languageStorage: languageStorage,
      );
      await tester.pumpAndSettle();
      await tapButton(
        tester,
        find.byKey(const ValueKey('stories.header.profile-action')),
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('profile.language-action')),
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('profile-language.option.ru')),
      );

      expect(languageStorage.storedPreference, AppLanguagePreference.russian);
      expect(find.text('Язык'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-language.screen')), findsOneWidget);
      expect(find.text('Your stories'), findsNothing);

      await tapButton(
        tester,
        find.byKey(const ValueKey('profile-language.back-action')),
      );

      expect(find.byKey(const ValueKey('profile.screen')), findsOneWidget);
      expect(find.text('Русский'), findsOneWidget);
    });

    testWidgets('shouldLogoutFromProfileThroughAuthNotifier', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;

      await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();
      await tapButton(
        tester,
        find.byKey(const ValueKey('stories.header.profile-action')),
      );
      await scrollDownUntilFound(
        tester,
        find.byKey(const ValueKey('profile.logout-action')),
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('profile.logout-action')),
      );

      expect(fakeAuthRepository.logoutCalls, 1);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile.screen')), findsNothing);
    });

    testWidgets('shouldKeepLanguagePreferenceAfterLogout', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final languageStorage = FakeAppLanguagePreferenceStorage()
        ..storedPreference = AppLanguagePreference.russian;

      await pumpApp(
        tester,
        fakeAuthRepository,
        languageStorage: languageStorage,
      );
      await tester.pumpAndSettle();
      await tapButton(
        tester,
        find.byKey(const ValueKey('stories.header.profile-action')),
      );
      await scrollDownUntilFound(
        tester,
        find.byKey(const ValueKey('profile.logout-action')),
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('profile.logout-action')),
      );

      expect(languageStorage.storedPreference, AppLanguagePreference.russian);
      expect(find.text('Продолжить с Google'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile.screen')), findsNothing);
    });

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

      expect(storyDetailsScreenFinder(), findsOneWidget);
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

      expect(storyDetailsScreenFinder(), findsOneWidget);
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

      expect(storyDetailsScreenFinder(), findsOneWidget);
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

      expect(storyDetailsScreenFinder(), findsOneWidget);
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

    testWidgets('shouldShowInviteActionOnlyForOwnerAndCoOwner', (
      WidgetTester tester,
    ) async {
      for (final role in StoryRole.values) {
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

        final inviteAction =
            find.byKey(const ValueKey('story-details.invite-action'));
        if (role.canUpdateStoryMetadata) {
          expect(inviteAction, findsOneWidget);
        } else {
          expect(inviteAction, findsNothing);
        }
      }
    });

    testWidgets('shouldOpenInviteFromDetailsWithoutCreatingInvite', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeInviteRepository = FakeInviteRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        inviteRepository: fakeInviteRepository,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.invite-action')),
      );

      expect(find.text('Invite someone close'), findsOneWidget);
      expect(find.byKey(const ValueKey('invite.create-action')), findsOneWidget);
      expect(fakeInviteRepository.createCalls, 0);
      expect(fakeInviteRepository.acceptCalls, 0);

      await tapButton(
        tester,
        find.byKey(const ValueKey('invite.create-action')),
      );

      expect(fakeInviteRepository.createCalls, 1);
      expect(
        fakeInviteRepository.receivedCreateInput,
        CreateInviteInput(storyId: ownerStory.story.id),
      );

      await tapButton(
        tester,
        find.byKey(const ValueKey('invite.done-action')),
      );

      expect(storyDetailsScreenFinder(), findsOneWidget);
    });

    testWidgets('shouldReturnFromInviteToDetailsWithBackActions', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;

      await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.invite-action')),
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('invite.back-action')),
      );

      expect(storyDetailsScreenFinder(), findsOneWidget);

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.invite-action')),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(storyDetailsScreenFinder(), findsOneWidget);
      expect(find.text('Invite someone close'), findsNothing);
    });

    testWidgets('shouldOpenDirectInviteRouteAndFallbackBackToDetails', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeStoryRepository = FakeStoryRepository();
      final fakeInviteRepository = FakeInviteRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
        inviteRepository: fakeInviteRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/invite');
      await tester.pumpAndSettle();

      expect(find.text('Invite someone close'), findsOneWidget);
      expect(fakeStoryRepository.getStoryCalls, 0);
      expect(fakeInviteRepository.createCalls, 0);

      await tapButton(
        tester,
        find.byKey(const ValueKey('invite.back-action')),
      );

      expect(storyDetailsScreenFinder(), findsOneWidget);
      expect(
        fakeStoryRepository.receivedGetStoryIds,
        contains(ownerStory.story.id),
      );
    });

    testWidgets('shouldKeepAuthenticatedUserOnDirectInviteRoute', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;

      await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/invite');
      await tester.pumpAndSettle();

      expect(find.text('Invite someone close'), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);

      await tapButton(
        tester,
        find.byKey(const ValueKey('invite.back-action')),
      );

      expect(storyDetailsScreenFinder(), findsOneWidget);
    });

    testWidgets('shouldNotMatchInviteRouteWithoutStoryId', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;

      await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories//invite');
      await tester.pumpAndSettle();

      expect(find.text('Invite someone close'), findsNothing);
    });

    testWidgets('shouldRedirectUnauthenticatedParticipantsRouteToLogin', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, FakeAuthRepository());
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Continue with Google'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/participants');
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Participants'), findsNothing);
    });

    testWidgets('shouldOpenAuthenticatedDirectParticipantsRoute', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeParticipantRepository = FakeStoryParticipantRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        participantRepository: fakeParticipantRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/participants');
      await tester.pumpAndSettle();

      expect(find.text('Participants'), findsWidgets);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(fakeParticipantRepository.getParticipantsCalls, 1);
      expect(
        fakeParticipantRepository.receivedStoryIds,
        <String>[ownerStory.story.id],
      );
    });

    testWidgets('shouldOpenParticipantsFromDetailsAndBackToDetails', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeParticipantRepository = FakeStoryParticipantRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        participantRepository: fakeParticipantRepository,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();

      await scrollToStoryDetailsParticipantsAction(tester);
      await tapButton(tester, storyDetailsParticipantsActionFinder());

      expect(find.text('Participants'), findsWidgets);
      expect(
        fakeParticipantRepository.receivedStoryIds,
        contains(ownerStory.story.id),
      );

      await tapButton(
        tester,
        find.byKey(const ValueKey('participants.back-action')),
      );

      expect(storyDetailsScreenFinder(), findsOneWidget);
    });

    testWidgets('shouldFallbackDirectParticipantsBackToStoryDetails', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeStoryRepository = FakeStoryRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
        participantRepository: FakeStoryParticipantRepository(),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/participants');
      await tester.pumpAndSettle();

      await tapButton(
        tester,
        find.byKey(const ValueKey('participants.back-action')),
      );

      expect(storyDetailsScreenFinder(), findsOneWidget);
      expect(
        fakeStoryRepository.receivedGetStoryIds,
        contains(ownerStory.story.id),
      );
    });

    testWidgets('shouldOpenInviteFromParticipantsAndBackToParticipants', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeInviteRepository = FakeInviteRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        inviteRepository: fakeInviteRepository,
        participantRepository: FakeStoryParticipantRepository(),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/participants');
      await tester.pumpAndSettle();

      await tapButton(
        tester,
        find.byKey(const ValueKey('participants.invite-action')),
      );

      expect(find.text('Invite someone close'), findsOneWidget);
      expect(fakeInviteRepository.createCalls, 0);

      await tapButton(
        tester,
        find.byKey(const ValueKey('invite.back-action')),
      );

      expect(find.text('Participants'), findsWidgets);
    });

    testWidgets('shouldRemainOnParticipantsAfterRemoveSuccess', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeParticipantRepository = FakeStoryParticipantRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        participantRepository: fakeParticipantRepository,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await scrollToStoryDetailsParticipantsAction(tester);
      await tapButton(tester, storyDetailsParticipantsActionFinder());

      await tapButton(tester, removeActionFor(viewerParticipant));
      await tapButton(
        tester,
        find.byKey(const ValueKey('participants.remove.confirm-action')),
      );

      expect(fakeParticipantRepository.removeParticipantCalls, 1);
      expect(
        fakeParticipantRepository.receivedRemoveInput,
        RemoveStoryParticipantInput(
          storyId: ownerStory.story.id,
          participantUserId: viewerParticipant.userId,
        ),
      );
      expect(find.text('Participants'), findsWidgets);
      expect(find.text(viewerParticipant.displayName), findsNothing);
      expect(storyDetailsScreenFinder(), findsNothing);

      await tapButton(
        tester,
        find.byKey(const ValueKey('participants.back-action')),
      );

      expect(storyDetailsScreenFinder(), findsOneWidget);
    });

    testWidgets('shouldOpenSoundtrackSelectionFromDetailsAndBack', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeSoundtrackRepository = FakeStorySoundtrackRepository()
        ..getResult = StorySoundtrack.noMusic()
        ..setResult = StorySoundtrack(
          selectedSoundtrack: soundtrackTrack,
          effectiveSoundtrack: soundtrackTrack,
        );

      await pumpApp(
        tester,
        fakeAuthRepository,
        musicRepository: FakeMusicRepository()
          ..tracksResult = <MusicTrack>[soundtrackTrack],
        soundtrackRepository: fakeSoundtrackRepository,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await scrollToStoryDetailsSoundtrackSummary(tester);
      await tapButton(tester, storyDetailsSoundtrackSummaryFinder());

      expect(find.text('Choose soundtrack'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('soundtrack-selection.screen')),
        findsOneWidget,
      );
      expect(storyDetailsScreenFinder(), findsNothing);

      await tapButton(
        tester,
        find.byKey(const ValueKey('soundtrack-selection.track.track-a')),
      );
      expect(fakeSoundtrackRepository.operations, <String>[
        'get:story-1',
        'set:story-1:track-a',
      ]);

      await tapButton(
        tester,
        find.byKey(const ValueKey('soundtrack-selection.back-action')),
      );

      expect(storyDetailsScreenFinder(), findsOneWidget);
      await scrollToStoryDetailsSoundtrackSummary(tester);
      expect(find.text('Autumn Leaves'), findsOneWidget);
    });

    testWidgets('shouldOpenSoundtrackSelectionDirectRouteFromStoryState', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeStoryRepository = FakeStoryRepository()
        ..storyResult = userStory(role: StoryRole.viewer);

      final container = await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
        musicRepository: FakeMusicRepository()
          ..tracksResult = <MusicTrack>[soundtrackTrack],
        soundtrackRepository: FakeStorySoundtrackRepository()
          ..getResult = StorySoundtrack.noMusic(),
      );
      await tester.pumpAndSettle();

      container.read(appRouterProvider).goNamed(
        storySoundtrackRouteName,
        pathParameters: {'storyId': ownerStory.story.id},
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose soundtrack'), findsOneWidget);
      expect(find.text('Read-only'), findsOneWidget);
      expect(fakeStoryRepository.receivedGetStoryIds, <String>['story-1']);
    });

    testWidgets('shouldSynchronizeStoriesAndGoToStoriesAfterLeaveSuccess', (
      WidgetTester tester,
    ) async {
      final storyA = userStory(
        id: 'story-a',
        title: 'Story A',
        description: 'First',
      );
      final storyB = userStory(
        id: ownerStory.story.id,
        title: ownerStory.story.title,
        description: ownerStory.story.description,
      );
      final storyC = userStory(
        id: 'story-c',
        title: 'Story C',
        description: 'Third',
      );
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeStoryRepository = FakeStoryRepository()
        ..storiesResult = <UserStory>[storyA, storyB, storyC]
        ..storyResult = storyB;
      final fakeParticipantRepository = FakeStoryParticipantRepository();
      final container = await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
        participantRepository: fakeParticipantRepository,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(storyB.story.title));
      await tester.pumpAndSettle();
      await scrollToStoryDetailsParticipantsAction(tester);
      await tapButton(tester, storyDetailsParticipantsActionFinder());

      await scrollToLeaveAction(tester);
      await tapButton(tester, leaveActionFinder());
      await tapButton(
        tester,
        find.byKey(const ValueKey('participants.leave.confirm-action')),
      );

      expect(fakeParticipantRepository.leaveStoryCalls, 1);
      expect(
        fakeParticipantRepository.receivedLeaveInput,
        LeaveStoryInput(storyId: storyB.story.id),
      );
      expect(find.text('Your stories'), findsOneWidget);
      expect(find.text(storyA.story.title), findsOneWidget);
      expect(find.text(storyB.story.title), findsNothing);
      expect(find.text(storyC.story.title), findsOneWidget);
      expect(
        container.read(storiesNotifierProvider).asData!.value.stories,
        <UserStory>[storyA, storyC],
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(storyDetailsScreenFinder(), findsNothing);
      expect(find.text('Participants'), findsNothing);
    });

    testWidgets('shouldStayOnParticipantsAndKeepStoriesAfterLeaveFailure', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeStoryRepository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory];
      final fakeParticipantRepository = FakeStoryParticipantRepository()
        ..leaveFailure = const ParticipantApplicationException(
          ParticipantLastOwnerConflict(),
        );
      final container = await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
        participantRepository: fakeParticipantRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/participants');
      await tester.pumpAndSettle();

      await scrollToLeaveAction(tester);
      await tapButton(tester, leaveActionFinder());
      await tapButton(
        tester,
        find.byKey(const ValueKey('participants.leave.confirm-action')),
      );

      expect(fakeParticipantRepository.leaveStoryCalls, 1);
      expect(find.text('Participants'), findsWidgets);
      expect(find.text('Your stories'), findsNothing);
      expect(
        find.text('The last owner cannot leave this story.'),
        findsOneWidget,
      );
      expect(
        container.read(storiesNotifierProvider).asData!.value.stories,
        <UserStory>[ownerStory],
      );
    });

    testWidgets('shouldHandleDirectParticipantsLeaveWithoutLoadedStoryMatch', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;

      await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: FakeStoryRepository()
          ..storiesResult = <UserStory>[],
        participantRepository: FakeStoryParticipantRepository(),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/participants');
      await tester.pumpAndSettle();

      await scrollToLeaveAction(tester);
      await tapButton(tester, leaveActionFinder());
      await tapButton(
        tester,
        find.byKey(const ValueKey('participants.leave.confirm-action')),
      );

      expect(find.text('Your stories'), findsOneWidget);
      expect(find.text('Participants'), findsNothing);
    });

    testWidgets('shouldClearLoadedStoryMapMemoryCacheAfterLeavingStory', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository();
      final fakeParticipantRepository = FakeStoryParticipantRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
        participantRepository: fakeParticipantRepository,
        storyMapBuilder: fakeStoryMapBuilder,
      );
      await tester.pumpAndSettle();

      final storiesContext = tester.element(find.text('Your stories'));
      GoRouter.of(storiesContext).go('/stories/${ownerStory.story.id}/map');
      await tester.pumpAndSettle();

      expect(find.text('Fake story map markers: 2'), findsOneWidget);
      expect(fakeMemoryRepository.getMemoriesCalls, 1);

      final mapContext = tester.element(
        find.byKey(const ValueKey('story-map.header')),
      );
      GoRouter.of(mapContext).go(
        '/stories/${ownerStory.story.id}/participants',
      );
      await tester.pumpAndSettle();
      await scrollToLeaveAction(tester);
      await tapButton(tester, leaveActionFinder());
      await tapButton(
        tester,
        find.byKey(const ValueKey('participants.leave.confirm-action')),
      );

      expect(find.text('Your stories'), findsOneWidget);

      fakeMemoryRepository.memoriesResult = <Memory>[];
      final postLeaveContext = tester.element(find.text('Your stories'));
      GoRouter.of(postLeaveContext).go('/stories/${ownerStory.story.id}/map');
      await tester.pumpAndSettle();

      expect(fakeMemoryRepository.getMemoriesCalls, 2);
      expect(find.text('Fake story map markers: 0'), findsOneWidget);
      expect(find.text(memoryA.title), findsNothing);
    });
  });

  group('Router memory navigation', () {
    testWidgets('shouldOpenStoryMemoriesFromDetailsAndBackToDetails', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await scrollToStoryDetailsMemoriesAction(tester);
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.memories-action')),
      );

      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(find.text(memoryA.title), findsOneWidget);
      expect(fakeMemoryRepository.getMemoriesCalls, 1);

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-memories.back-action')),
      );

      expect(storyDetailsScreenFinder(), findsOneWidget);
      expect(storyDetailsMemoriesActionFinder(), findsOneWidget);
    });

    testWidgets('shouldOpenDirectStoryMemoriesRouteAndFallbackBackToDetails', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository();
      final fakeStoryRepository = FakeStoryRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
        memoryRepository: fakeMemoryRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/memories');
      await tester.pumpAndSettle();

      expect(find.text(ownerStory.story.title), findsOneWidget);

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-memories.back-action')),
      );

      expect(storyDetailsScreenFinder(), findsOneWidget);
      expect(
        fakeStoryRepository.receivedGetStoryIds,
        contains(ownerStory.story.id),
      );
    });

    testWidgets('shouldOpenStoryMapFromDetailsAndBackToDetails', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
        storyMapBuilder: fakeStoryMapBuilder,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await scrollToStoryDetailsMapAction(tester);
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.map-action')),
      );

      expect(find.byKey(const ValueKey('story-map.header')), findsOneWidget);
      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(find.text('Fake story map markers: 2'), findsOneWidget);
      expect(fakeMemoryRepository.getMemoriesCalls, 1);

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-map.back-action')),
      );

      expect(storyDetailsScreenFinder(), findsOneWidget);
      expect(storyDetailsMapActionFinder(), findsOneWidget);
    });

    testWidgets('shouldOpenStoryMapFromMemoryDetailsAndSelectMemory', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
        storyMapBuilder: fakeStoryMapBuilder,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/memories/${memoryA.id}');
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('memory-details.open-map-action')),
        120,
        scrollable: memoryDetailsScrollableFinder(),
      );
      await tester.pumpAndSettle();
      final openMapButton = tester.widget<TextButton>(
        find.byKey(const ValueKey('memory-details.open-map-action')),
      );
      expect(openMapButton.onPressed, isNotNull);
      openMapButton.onPressed!();
      await tester.pumpAndSettle();

      expect(
        routerLocation(
          tester.element(find.byKey(const ValueKey('story-map.header'))),
        ),
        '/stories/${memoryA.storyId}/map',
      );
      expect(find.text('Fake story map markers: 2'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-map.memory-preview')),
        findsOneWidget,
      );
      expect(find.text(memoryA.title), findsOneWidget);
    });

    testWidgets('shouldOpenDirectStoryMapRouteAndFallbackBackToDetails', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository();
      final fakeStoryRepository = FakeStoryRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
        memoryRepository: fakeMemoryRepository,
        storyMapBuilder: fakeStoryMapBuilder,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/map');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('story-map.header')), findsOneWidget);
      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(find.text('Fake story map markers: 2'), findsOneWidget);
      expect(fakeMemoryRepository.receivedStoryIds, <String>[
        ownerStory.story.id,
      ]);

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-map.back-action')),
      );

      expect(storyDetailsScreenFinder(), findsOneWidget);
      expect(
        fakeStoryRepository.receivedGetStoryIds,
        contains(ownerStory.story.id),
      );
    });

    testWidgets('shouldOpenStoryTimelineFromDetailsAndBackToDetails', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await scrollToStoryDetailsTimelineAction(tester);
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.timeline-action')),
      );

      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text(memoryA.title), findsOneWidget);
      expect(fakeMemoryRepository.getMemoriesCalls, 1);
      expect(fakeMemoryRepository.getMemoryCalls, 0);
      expect(
        find.byKey(const ValueKey('story-timeline.tabs')),
        findsOneWidget,
      );

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-timeline.back-action')),
      );

      expect(storyDetailsScreenFinder(), findsOneWidget);
    });

    testWidgets('shouldOpenDirectStoryTimelineRouteAndFallbackBackToDetails', (
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
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/timeline');
      await tester.pumpAndSettle();

      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text(memoryA.title), findsOneWidget);

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-timeline.back-action')),
      );

      expect(storyDetailsScreenFinder(), findsOneWidget);
      expect(
        fakeStoryRepository.receivedGetStoryIds,
        contains(ownerStory.story.id),
      );
    });

    testWidgets('shouldOpenStoryPlaybackFromDetailsAndBackToDetails', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
        storyPlaybackMapBuilder: fakeStoryPlaybackMapBuilder,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await scrollToStoryDetailsPlaybackAction(tester);
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.playback-action')),
      );

      expect(find.byKey(const ValueKey('story-playback.screen')), findsOneWidget);
      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(find.text('Fake playback markers: 2'), findsOneWidget);
      expect(fakeMemoryRepository.receivedStoryIds, <String>[
        ownerStory.story.id,
      ]);

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-playback.close')),
      );

      expect(storyDetailsScreenFinder(), findsOneWidget);
    });

    testWidgets('shouldOpenMemoryDetailsFromPlaybackAndReturnPaused', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository();
      final container = await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
        storyPlaybackMapBuilder: controllableStoryPlaybackMapBuilder,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await scrollToStoryDetailsPlaybackAction(tester);
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.playback-action')),
      );

      expect(find.byKey(const ValueKey('story-playback.screen')), findsOneWidget);
      expect(find.text('Fake playback markers: 2'), findsOneWidget);
      expect(fakeMemoryRepository.getMemoriesCalls, 1);

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-playback.fake-camera-arrived')),
      );

      expect(find.byKey(const ValueKey('story-playback.details')), findsOneWidget);
      expect(find.text(memoryA.title), findsOneWidget);

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-playback.details')),
      );

      expect(find.byKey(const ValueKey('memory-details.hero')), findsOneWidget);
      expect(storyDetailsScreenFinder(), findsNothing);
      expect(find.byKey(const ValueKey('story-playback.screen')), findsNothing);
      expect(fakeMemoryRepository.receivedMemoryIds, contains(memoryA.id));

      container
          .read(storyMemoriesProvider(ownerStory.story.id).notifier)
          .upsertAuthoritativeRead(
            MemoryReadModel.fromMemory(
              memory(
                id: 'memory-c',
                title: 'Fresh shared memory',
                location: memoryLocationA,
                eventDate: MemoryDate(year: 2026, month: 6, day: 1),
              ),
            ),
          );

      await tapButton(
        tester,
        find.byKey(const ValueKey('memory-details.back-action')),
      );

      expect(find.byKey(const ValueKey('story-playback.screen')), findsOneWidget);
      expect(find.byKey(const ValueKey('story-playback.resume')), findsOneWidget);
      expect(find.text(memoryA.title), findsOneWidget);
      expect(find.text('Fake playback markers: 2'), findsOneWidget);
      expect(find.text('Fake playback current: 0'), findsOneWidget);
      expect(find.text('Fresh shared memory'), findsNothing);
      expect(fakeMemoryRepository.getMemoriesCalls, 1);
    });

    testWidgets('shouldOpenStoryPlaybackFromTimelineAndCloseBackToTimeline', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
        storyPlaybackMapBuilder: fakeStoryPlaybackMapBuilder,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await scrollToStoryDetailsTimelineAction(tester);
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.timeline-action')),
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-timeline.playback-action')),
      );

      expect(find.byKey(const ValueKey('story-playback.screen')), findsOneWidget);
      expect(find.text('Fake playback markers: 2'), findsOneWidget);

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-playback.close')),
      );

      expect(
        find.byKey(const ValueKey('story-timeline.tabs')),
        findsOneWidget,
      );
      expect(find.text(memoryA.title), findsOneWidget);

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-timeline.back-action')),
      );

      expect(storyDetailsScreenFinder(), findsOneWidget);
    });

    testWidgets('shouldFallbackDirectStoryPlaybackCloseToDetails', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeStoryRepository = FakeStoryRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
        storyPlaybackMapBuilder: fakeStoryPlaybackMapBuilder,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/playback');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('story-playback.screen')), findsOneWidget);
      expect(find.text('Fake playback markers: 2'), findsOneWidget);

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-playback.close')),
      );

      expect(storyDetailsScreenFinder(), findsOneWidget);
      expect(
        fakeStoryRepository.receivedGetStoryIds,
        contains(ownerStory.story.id),
      );
    });

    testWidgets('shouldRouteUnauthenticatedPlaybackToLogin', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, FakeAuthRepository());
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Continue with Google'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/playback');
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byKey(const ValueKey('story-playback.screen')), findsNothing);
    });

    testWidgets('shouldShowPlaybackForViewerWithoutMutationActions', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeStoryRepository = FakeStoryRepository()
        ..storiesResult = <UserStory>[userStory(role: StoryRole.viewer)]
        ..storyResult = userStory(role: StoryRole.viewer);

      await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
        storyPlaybackMapBuilder: fakeStoryPlaybackMapBuilder,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await scrollToStoryDetailsPlaybackAction(tester);

      expect(
        find.byKey(const ValueKey('story-details.playback-action')),
        findsOneWidget,
      );

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.playback-action')),
      );

      expect(find.byKey(const ValueKey('story-playback.screen')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-timeline.create-action')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('story-details.edit-action')),
        findsNothing,
      );
    });

    testWidgets('shouldOpenEmptyStoryPlaybackState', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository()
        ..readModelsResult = <MemoryReadModel>[];

      await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
        storyPlaybackMapBuilder: fakeStoryPlaybackMapBuilder,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/playback');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('story-playback.empty')), findsOneWidget);
      expect(find.text('Fake playback markers: 0'), findsOneWidget);
    });

    testWidgets('shouldCaptureFreshPlaybackSnapshotAfterRouteReEntry', (
      WidgetTester tester,
    ) async {
      final memoryC = memory(
        id: 'memory-c',
        title: 'Third memory',
        location: memoryLocationA,
        eventDate: MemoryDate(year: 2026, month: 3, day: 1),
      );
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository()
        ..readModelsResult = <MemoryReadModel>[
          MemoryReadModel.fromMemory(memoryA),
          MemoryReadModel.fromMemory(memoryB),
        ];

      final container = await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
        storyPlaybackMapBuilder: fakeStoryPlaybackMapBuilder,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await scrollToStoryDetailsPlaybackAction(tester);
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.playback-action')),
      );

      expect(find.text('Fake playback markers: 2'), findsOneWidget);

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-playback.close')),
      );

      container
          .read(storyMemoriesProvider(ownerStory.story.id).notifier)
          .upsertAuthoritativeRead(MemoryReadModel.fromMemory(memoryC));
      await tester.pumpAndSettle();

      fakeMemoryRepository.readModelsResult = <MemoryReadModel>[
        MemoryReadModel.fromMemory(memoryC),
      ];

      await scrollToStoryDetailsPlaybackAction(tester);
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.playback-action')),
      );

      expect(find.text('Fake playback markers: 3'), findsOneWidget);
      expect(fakeMemoryRepository.getMemoriesCalls, 1);
    });

    testWidgets('shouldRouteUnauthenticatedTimelineToLogin', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, FakeAuthRepository());
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Continue with Google'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/timeline');
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Timeline'), findsNothing);
    });

    testWidgets('shouldOpenMemoryDetailsFromTimelineAndBackToTimeline', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/timeline');
      await tester.pumpAndSettle();
      await tester.tap(find.text(memoryA.title));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('memory-details.hero')), findsOneWidget);
      expect(find.text(memoryA.title), findsOneWidget);
      expect(fakeMemoryRepository.receivedMemoryIds, contains(memoryA.id));

      await tapButton(
        tester,
        find.byKey(const ValueKey('memory-details.back-action')),
      );

      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text(memoryA.title), findsOneWidget);
    });

    testWidgets('shouldRenderTimelineThumbnailWithoutMediaMetadataRequests', (
      WidgetTester tester,
    ) async {
      final preview = previewPhoto('media-a');
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository()
        ..readModelsResult = <MemoryReadModel>[
          MemoryReadModel(memory: memoryA, previewPhoto: preview),
          MemoryReadModel.fromMemory(memoryB),
        ];
      final fakeMediaRepository = media_fixtures.FakeMediaRepository()
        ..thumbnailResult = media_fixtures.validPngBytes
        ..mediaResult = <Media>[];

      await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
        mediaRepository: fakeMediaRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/timeline');
      await tester.pumpAndSettle();

      expect(find.text(memoryA.title), findsOneWidget);
      expect(fakeMemoryRepository.getMemoriesCalls, 1);
      expect(fakeMemoryRepository.getMemoryCalls, 0);
      expect(fakeMediaRepository.getThumbnailByPathCalls, 1);
      expect(fakeMediaRepository.receivedBinaryPaths, <String>[
        preview.thumbnailPath,
      ]);
      expect(fakeMediaRepository.getMediaCalls, 0);
      expect(fakeMediaRepository.getDisplayCalls, 0);
    });

    testWidgets('shouldReflectPhotoPreviewAuthoritativeUpdatesOnTimeline', (
      WidgetTester tester,
    ) async {
      final previewA = previewPhoto('media-a');
      final previewB = previewPhoto('media-b');
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository()
        ..readModelsResult = <MemoryReadModel>[
          MemoryReadModel(memory: memoryA, previewPhoto: previewA),
        ];
      final fakeMediaRepository = media_fixtures.FakeMediaRepository()
        ..thumbnailResult = media_fixtures.validPngBytes
        ..mediaResult = <Media>[];
      final container = await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
        mediaRepository: fakeMediaRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/timeline');
      await tester.pumpAndSettle();
      expect(fakeMediaRepository.receivedBinaryPaths, <String>[
        previewA.thumbnailPath,
      ]);

      container
          .read(storyMemoriesProvider(ownerStory.story.id).notifier)
          .upsertAuthoritativeRead(
            MemoryReadModel(memory: memoryA, previewPhoto: previewB),
          );
      await tester.pumpAndSettle();

      expect(fakeMediaRepository.receivedBinaryPaths, <String>[
        previewA.thumbnailPath,
        previewB.thumbnailPath,
      ]);

      container
          .read(storyMemoriesProvider(ownerStory.story.id).notifier)
          .upsertAuthoritativeRead(MemoryReadModel.fromMemory(memoryA));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('story-timeline.no-photo-visual')),
        findsOneWidget,
      );
      expect(fakeMediaRepository.getMediaCalls, 0);
      expect(fakeMediaRepository.getDisplayCalls, 0);
    });

    testWidgets('shouldRefreshTimelineAuthoritativePreviewReplacementAndNull', (
      WidgetTester tester,
    ) async {
      final previewA = previewPhoto('media-a');
      final previewB = previewPhoto('media-b');
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository()
        ..readModelsResult = <MemoryReadModel>[
          MemoryReadModel(memory: memoryA, previewPhoto: previewA),
        ];
      final fakeMediaRepository = media_fixtures.FakeMediaRepository()
        ..thumbnailResult = media_fixtures.validPngBytes
        ..mediaResult = <Media>[];
      final container = await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
        mediaRepository: fakeMediaRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/timeline');
      await tester.pumpAndSettle();

      fakeMemoryRepository.readModelsResult = <MemoryReadModel>[
        MemoryReadModel(memory: memoryA, previewPhoto: previewB),
      ];
      await container
          .read(storyMemoriesProvider(ownerStory.story.id).notifier)
          .refreshMemories();
      await tester.pumpAndSettle();

      expect(fakeMediaRepository.receivedBinaryPaths, contains(previewB.thumbnailPath));

      fakeMemoryRepository.readModelsResult = <MemoryReadModel>[
        MemoryReadModel.fromMemory(memoryA),
      ];
      await container
          .read(storyMemoriesProvider(ownerStory.story.id).notifier)
          .refreshMemories();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('story-timeline.no-photo-visual')),
        findsOneWidget,
      );
    });

    testWidgets('shouldOpenMemoryDetailsFromStoryMapAndBackToMap', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
        storyMapBuilder: fakeStoryMapBuilder,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await scrollToStoryDetailsMapAction(tester);
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.map-action')),
      );
      await tapButton(
        tester,
        find.byKey(ValueKey('story-map.fake-marker.${memoryA.id}')),
      );
      await tapButton(
        tester,
        find.byKey(
          const ValueKey('story-map.memory-preview.details-action'),
        ),
      );

      expect(find.byKey(const ValueKey('memory-details.hero')), findsOneWidget);
      expect(find.text(memoryA.title), findsOneWidget);
      expect(fakeMemoryRepository.receivedMemoryIds, contains(memoryA.id));

      await tapButton(
        tester,
        find.byKey(const ValueKey('memory-details.back-action')),
      );

      expect(find.text('Fake story map markers: 2'), findsOneWidget);
      expect(find.text(memoryA.title), findsOneWidget);
      expect(fakeMemoryRepository.getMemoriesCalls, 1);
    });

    testWidgets('shouldKeepStoryMapUrlFreeOfMapAndMemoryData', (
      WidgetTester tester,
    ) async {
      const storyId = 'story-secret';
      final secretMemory = memory(
        id: 'memory-secret',
        storyId: storyId,
        title: 'private-title',
        location: MemoryLocation(latitude: 41.715123, longitude: 44.827456),
        eventDate: memoryDateA,
      );
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeStoryRepository = FakeStoryRepository()
        ..storyResult = userStory(
          id: storyId,
          title: 'Secret story',
        );
      final fakeMemoryRepository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[secretMemory];

      await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
        memoryRepository: fakeMemoryRepository,
        storyMapBuilder: fakeStoryMapBuilder,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/$storyId/map');
      await tester.pumpAndSettle();
      await tapButton(
        tester,
        find.byKey(ValueKey('story-map.fake-marker.${secretMemory.id}')),
      );

      final location = routerLocation(
        tester.element(find.byKey(const ValueKey('story-map.header'))),
      );

      expect(location, contains(storyId));
      expect(location, isNot(contains('41.715123')));
      expect(location, isNot(contains('44.827456')));
      expect(location, isNot(contains('private-title')));
      expect(location, isNot(contains(secretMemory.id)));
      expect(location, isNot(contains('openfreemap')));
    });

    testWidgets('shouldShowStoryMapActionForViewer', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeStoryRepository = FakeStoryRepository()
        ..storiesResult = <UserStory>[userStory(role: StoryRole.viewer)]
        ..storyResult = userStory(role: StoryRole.viewer);

      await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
        storyMapBuilder: fakeStoryMapBuilder,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await scrollToStoryDetailsMapAction(tester);

      expect(
        find.byKey(const ValueKey('story-details.map-action')),
        findsOneWidget,
      );
    });

    testWidgets('shouldShowTimelineForViewerAndHideCreateMemory', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeStoryRepository = FakeStoryRepository()
        ..storiesResult = <UserStory>[userStory(role: StoryRole.viewer)]
        ..storyResult = userStory(role: StoryRole.viewer);

      await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await scrollToStoryDetailsTimelineAction(tester);

      expect(
        find.byKey(const ValueKey('story-details.timeline-action')),
        findsOneWidget,
      );

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.timeline-action')),
      );

      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text(memoryA.title), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-timeline.create-action')),
        findsNothing,
      );
    });

    testWidgets('shouldExposeTimelineCreateForOwnerCoOwnerAndEditor', (
      WidgetTester tester,
    ) async {
      for (final role in <StoryRole>[
        StoryRole.owner,
        StoryRole.coOwner,
        StoryRole.editor,
      ]) {
        final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
        final fakeStoryRepository = FakeStoryRepository()
          ..storiesResult = <UserStory>[userStory(role: role)]
          ..storyResult = userStory(role: role);

        await pumpApp(
          tester,
          fakeAuthRepository,
          storyRepository: fakeStoryRepository,
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.text('Your stories'));
        GoRouter.of(context).go('/stories/${ownerStory.story.id}/timeline');
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('story-timeline.create-action')),
          findsOneWidget,
        );
      }
    });

    testWidgets('shouldOpenMemoryDetailsFromStoryMemoriesAndBackToMemories', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await scrollToStoryDetailsMemoriesAction(tester);
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.memories-action')),
      );
      await tester.tap(find.text(memoryA.title));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('memory-details.hero')), findsOneWidget);
      expect(find.text(memoryA.title), findsOneWidget);
      expect(fakeMemoryRepository.receivedMemoryIds, contains(memoryA.id));

      await tapButton(
        tester,
        find.byKey(const ValueKey('memory-details.back-action')),
      );

      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(find.text(memoryA.title), findsOneWidget);
    });

    testWidgets('shouldFallbackDirectMemoryDetailsBackToStoryMemoriesAfterLoad', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/memories/${memoryA.id}');
      await tester.pumpAndSettle();

      expect(find.text(memoryA.title), findsOneWidget);

      await tapButton(
        tester,
        find.byKey(const ValueKey('memory-details.back-action')),
      );

      expect(find.text(ownerStory.story.title), findsOneWidget);
    });

    testWidgets('shouldCreateMemoryThroughLocationPickerAndOpenDetails', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository()
        ..createResult = createdMemory;

      await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await scrollToStoryDetailsMemoriesAction(tester);
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.memories-action')),
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-memories.create-action')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('create-memory.title-field')),
        'Router memory',
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('create-memory.date-action')),
      );
      await tapVisibleText(tester, 'OK');
      await tester.pumpAndSettle();
      await tapButton(
        tester,
        find.byKey(const ValueKey('create-memory.location-action')),
      );

      expect(find.text('Choose a place'), findsOneWidget);
      expect(find.textContaining('41.7151'), findsNothing);
      expect(find.textContaining('44.8271'), findsNothing);

      await tapButton(
        tester,
        find.byKey(const ValueKey('location-picker.fake-map.select-a')),
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('location-picker.confirm-action')),
      );

      expect(find.text('Router memory'), findsOneWidget);
      expect(find.text('Location selected'), findsOneWidget);

      await tapButton(
        tester,
        find.byKey(const ValueKey('create-memory.submit-action')),
      );

      expect(fakeMemoryRepository.createMemoryCalls, 1);
      expect(
        fakeMemoryRepository.receivedCreateInput?.storyId,
        ownerStory.story.id,
      );
      expect(
        fakeMemoryRepository.receivedCreateInput?.location,
        memoryLocationA,
      );
      expect(find.byKey(const ValueKey('memory-details.hero')), findsOneWidget);
      expect(find.text(createdMemory.title), findsOneWidget);

      await tapButton(
        tester,
        find.byKey(const ValueKey('memory-details.back-action')),
      );

      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(find.text(createdMemory.title), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-memories.create-action')),
        findsOneWidget,
      );
    });

    testWidgets('shouldCreateMemoryFromTimelineAndReflectNewYear', (
      WidgetTester tester,
    ) async {
      final newYearMemory = memory(
        id: 'timeline-created-memory',
        title: 'Timeline created',
        createdBy: session.user.id,
        eventDate: MemoryDate(year: 2027, month: 1, day: 2),
        location: memoryLocationA,
      );
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository()
        ..createResult = newYearMemory;

      await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/timeline');
      await tester.pumpAndSettle();
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-timeline.create-action')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('create-memory.title-field')),
        newYearMemory.title,
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('create-memory.date-action')),
      );
      await tapVisibleText(tester, 'OK');
      await tester.pumpAndSettle();
      await tapButton(
        tester,
        find.byKey(const ValueKey('create-memory.location-action')),
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('location-picker.fake-map.select-a')),
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('location-picker.confirm-action')),
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('create-memory.submit-action')),
      );

      expect(fakeMemoryRepository.createMemoryCalls, 1);
      expect(find.byKey(const ValueKey('memory-details.hero')), findsOneWidget);

      await tapButton(
        tester,
        find.byKey(const ValueKey('memory-details.back-action')),
      );

      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text(newYearMemory.title), findsOneWidget);
      expect(find.text('2027'), findsOneWidget);
    });

    testWidgets('shouldHideCreateMemoryForViewer', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeStoryRepository = FakeStoryRepository()
        ..storyResult = userStory(role: StoryRole.viewer);

      await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/memories');
      await tester.pumpAndSettle();

      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-memories.create-action')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('story-memories.empty.create-action')),
        findsNothing,
      );
    });

    testWidgets('shouldOpenDirectEditRouteAndReturnToUpdatedDetails', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository()
        ..updateResult = updatedMemory;

      await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/memories/${memoryA.id}/edit');
      await tester.pumpAndSettle();

      expect(find.text('Edit memory'), findsOneWidget);
      expect(fakeMemoryRepository.receivedMemoryIds, contains(memoryA.id));

      await tester.enterText(
        find.byKey(const ValueKey('edit-memory.title-field')),
        'Updated through router',
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('edit-memory.save-action')),
      );

      expect(fakeMemoryRepository.updateMemoryCalls, 1);
      expect(find.byKey(const ValueKey('memory-details.hero')), findsOneWidget);
      expect(find.text(updatedMemory.title), findsOneWidget);
      expect(find.text('Edit memory'), findsNothing);
    });

    testWidgets('shouldReflectTimelineEditAndPreservePreview', (
      WidgetTester tester,
    ) async {
      final preview = previewPhoto('preview-a');
      final editedIntoNewYear = memory(
        id: memoryA.id,
        title: 'Timeline edited',
        description: 'Timeline edited description',
        placeName: 'Timeline edited place',
        createdBy: memoryA.createdBy,
        eventDate: MemoryDate(year: 2027, month: 3, day: 4),
        location: memoryA.location,
      );
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository()
        ..readModelsResult = <MemoryReadModel>[
          MemoryReadModel(memory: memoryA, previewPhoto: preview),
          MemoryReadModel.fromMemory(memoryB),
        ]
        ..memoryReadResult = MemoryReadModel(
          memory: memoryA,
          previewPhoto: preview,
        )
        ..updateResult = editedIntoNewYear;

      final container = await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/stories/${ownerStory.story.id}/timeline');
      await tester.pumpAndSettle();
      await tester.tap(find.text(memoryA.title));
      await tester.pumpAndSettle();
      await tapButton(
        tester,
        find.byKey(const ValueKey('memory-details.edit-action')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit-memory.title-field')),
        editedIntoNewYear.title,
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('edit-memory.save-action')),
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('memory-details.back-action')),
      );

      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text(editedIntoNewYear.title), findsOneWidget);
      expect(find.text('2027'), findsOneWidget);
      final storyMemories = container
          .read(storyMemoriesProvider(ownerStory.story.id))
          .asData!
          .value;
      final editedReadModel = storyMemories.memoryReadModels.singleWhere(
        (readModel) => readModel.memory.id == editedIntoNewYear.id,
      );
      expect(editedReadModel.previewPhoto, preview);
    });

    testWidgets('shouldNavigateAfterDeleteAndRemoveStaleDetailsFromStack', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ownerStory.story.title));
      await tester.pumpAndSettle();
      await scrollToStoryDetailsMemoriesAction(tester);
      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.memories-action')),
      );
      await tester.tap(find.text(memoryA.title));
      await tester.pumpAndSettle();
      await scrollToMemoryDetailsDeleteAction(tester);
      await tapButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete-action')),
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete.confirm-action')),
      );

      expect(fakeMemoryRepository.deleteMemoryCalls, 1);
      expect(
        fakeMemoryRepository.receivedDeleteInput,
        DeleteMemoryInput(memoryId: memoryA.id),
      );
      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(find.text(memoryA.title), findsNothing);
      expect(find.text(memoryB.title), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(storyDetailsScreenFinder(), findsOneWidget);
      expect(find.text(memoryA.title), findsNothing);
    });

    testWidgets('shouldDeleteMemoryFromTimelineAndRemoveEmptyYear', (
      WidgetTester tester,
    ) async {
      final only2025 = memory(
        id: 'only-2025',
        title: 'Only 2025 memory',
        eventDate: MemoryDate(year: 2025, month: 1, day: 1),
        location: memoryLocationA,
      );
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeMemoryRepository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[only2025, memoryA]
        ..memoryResult = only2025;

      final container = await pumpApp(
        tester,
        fakeAuthRepository,
        memoryRepository: fakeMemoryRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/memories/${only2025.id}?origin=timeline');
      await tester.pumpAndSettle();
      expect(
        routerLocation(
          tester.element(find.byKey(const ValueKey('memory-details.hero'))),
        ),
        '/memories/${only2025.id}?origin=timeline',
      );
      await scrollToMemoryDetailsDeleteAction(tester);
      await tapButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete-action')),
      );
      await tapButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete.confirm-action')),
      );

      expect(fakeMemoryRepository.deleteMemoryCalls, 1);
      expect(
        find.byKey(const ValueKey('story-timeline.tabs')),
        findsOneWidget,
      );
      expect(find.text(only2025.title), findsNothing);
      expect(find.text(memoryA.title), findsOneWidget);
      final storyMemories = container
          .read(storyMemoriesProvider(ownerStory.story.id))
          .asData!
          .value;
      expect(
        storyMemories.memoryReadModels.map((readModel) => readModel.memory.id),
        <String>[memoryA.id],
      );
    });

    testWidgets('shouldHideMemoryMutationsWhenViewerIsNotAuthor', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeStoryRepository = FakeStoryRepository()
        ..storyResult = userStory(role: StoryRole.viewer);
      final fakeMemoryRepository = FakeMemoryRepository()
        ..memoryResult = memoryA;

      await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
        memoryRepository: fakeMemoryRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/memories/${memoryA.id}');
      await tester.pumpAndSettle();

      expect(find.text(memoryA.title), findsOneWidget);
      expect(
        find.byKey(const ValueKey('memory-details.edit-action')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('memory-details.delete-action')),
        findsNothing,
      );
    });
  });

  group('Router invite deep links', () {
    testWidgets('shouldStorePendingInviteAndContinueAfterLogin', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository();
      final fakeStoryRepository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory]
        ..storyResult = acceptedInviteStory;
      final fakeInviteRepository = FakeInviteRepository()
        ..acceptResult = acceptedInviteStory;
      final container = await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
        inviteRepository: fakeInviteRepository,
      );
      await tester.pumpAndSettle();

      final loginContext = tester.element(find.text('Continue with Google'));
      GoRouter.of(loginContext).go('/invite/$validInviteToken');
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(
        container.read(pendingInviteProvider).rawToken,
        validInviteToken,
      );
      expect(fakeInviteRepository.acceptCalls, 0);

      await tapVisibleText(tester, 'Continue with Google');
      await tester.pumpAndSettle();

      expect(find.text('You were invited to a story'), findsOneWidget);
      expect(find.textContaining(validInviteToken), findsNothing);

      await tapButton(
        tester,
        find.byKey(const ValueKey('accept-invite.accept-action')),
      );

      expect(fakeInviteRepository.acceptCalls, 1);
      expect(
        fakeInviteRepository.receivedAcceptInput,
        AcceptInviteInput(rawToken: validInviteToken),
      );
      expect(container.read(pendingInviteProvider).hasInvite, isFalse);
      expect(find.text(acceptedInviteStory.story.title), findsOneWidget);
      expect(find.text('You were invited to a story'), findsNothing);
    });

    testWidgets('shouldRetainPendingInviteDuringAuthLoading', (
      WidgetTester tester,
    ) async {
      final restoreCompleter = Completer<AuthSession?>();
      final fakeAuthRepository = FakeAuthRepository()
        ..restoreCompleter = restoreCompleter;
      final container = await pumpApp(tester, fakeAuthRepository);

      final checkingContext =
          tester.element(find.textContaining('Checking your session'));
      GoRouter.of(checkingContext).go('/invite/$validInviteToken');
      await tester.pump();

      expect(
        container.read(pendingInviteProvider).rawToken,
        validInviteToken,
      );
      expect(find.textContaining('Checking your session'), findsOneWidget);

      restoreCompleter.complete(null);
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(
        container.read(pendingInviteProvider).rawToken,
        validInviteToken,
      );
    });

    testWidgets('shouldOpenAcceptInviteForAuthenticatedDirectRoute', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeStoryRepository = FakeStoryRepository()
        ..storyResult = acceptedInviteStory;
      final fakeInviteRepository = FakeInviteRepository()
        ..acceptResult = acceptedInviteStory;

      await pumpApp(
        tester,
        fakeAuthRepository,
        storyRepository: fakeStoryRepository,
        inviteRepository: fakeInviteRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/invite/$validInviteToken');
      await tester.pumpAndSettle();

      expect(find.text('Invitation'), findsOneWidget);
      expect(find.textContaining(validInviteToken), findsNothing);
      expect(fakeInviteRepository.acceptCalls, 0);

      await tapButton(
        tester,
        find.byKey(const ValueKey('accept-invite.accept-action')),
      );

      expect(fakeInviteRepository.acceptCalls, 1);
      expect(find.text(acceptedInviteStory.story.title), findsOneWidget);
    });

    testWidgets('shouldRenderInvalidInviteRouteSafelyForAuthenticatedUser', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final fakeInviteRepository = FakeInviteRepository();

      await pumpApp(
        tester,
        fakeAuthRepository,
        inviteRepository: fakeInviteRepository,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Your stories'));
      GoRouter.of(context).go('/invite/not-a-valid-token');
      await tester.pumpAndSettle();

      expect(find.text('Invite link is unavailable'), findsOneWidget);
      expect(find.textContaining('not-a-valid-token'), findsNothing);
      expect(fakeInviteRepository.acceptCalls, 0);
    });

    testWidgets('shouldKeepUnavailableInviteFailureSafeAndClearPending', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository();
      final fakeInviteRepository = FakeInviteRepository()
        ..acceptFailure = const InviteApplicationException(InviteNotFound());
      final container = await pumpApp(
        tester,
        fakeAuthRepository,
        inviteRepository: fakeInviteRepository,
      );
      await tester.pumpAndSettle();

      final loginContext = tester.element(find.text('Continue with Google'));
      GoRouter.of(loginContext).go('/invite/$validInviteToken');
      await tester.pumpAndSettle();
      await tapVisibleText(tester, 'Continue with Google');
      await tester.pumpAndSettle();

      await tapButton(
        tester,
        find.byKey(const ValueKey('accept-invite.accept-action')),
      );

      expect(fakeInviteRepository.acceptCalls, 1);
      expect(find.text('This invitation cannot be accepted.'), findsOneWidget);
      expect(find.textContaining(validInviteToken), findsNothing);
      expect(container.read(pendingInviteProvider).hasInvite, isFalse);
    });

    testWidgets('shouldClearPendingInviteWhenCanceled', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository();
      final container = await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();

      final loginContext = tester.element(find.text('Continue with Google'));
      GoRouter.of(loginContext).go('/invite/$validInviteToken');
      await tester.pumpAndSettle();
      await tapVisibleText(tester, 'Continue with Google');
      await tester.pumpAndSettle();

      await tapButton(
        tester,
        find.byKey(const ValueKey('accept-invite.cancel-action')),
      );

      expect(find.text('Your stories'), findsOneWidget);
      expect(container.read(pendingInviteProvider).hasInvite, isFalse);
    });

    testWidgets('shouldClearPendingInviteOnLogout', (
      WidgetTester tester,
    ) async {
      final fakeAuthRepository = FakeAuthRepository()..restoreResult = session;
      final container = await pumpApp(tester, fakeAuthRepository);
      await tester.pumpAndSettle();
      container
          .read(pendingInviteProvider.notifier)
          .setToken(validInviteToken);

      await container.read(authNotifierProvider.notifier).logout();
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(container.read(pendingInviteProvider).hasInvite, isFalse);
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
  await scrollUpUntilFound(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

String routerLocation(BuildContext context) {
  return GoRouter.of(context).routeInformationProvider.value.uri.toString();
}

Future<void> scrollToLeaveAction(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    leaveActionFinder(),
    120,
    scrollable: find.byType(Scrollable),
  );
  await tester.pumpAndSettle();
}

Future<void> scrollToStoryDetailsParticipantsAction(
  WidgetTester tester,
) async {
  await tester.scrollUntilVisible(
    storyDetailsParticipantsActionFinder(),
    120,
    scrollable: storyDetailsScrollableFinder(),
  );
  await tester.pumpAndSettle();
}

Future<void> scrollToStoryDetailsMemoriesAction(
  WidgetTester tester,
) async {
  await tester.scrollUntilVisible(
    storyDetailsMemoriesActionFinder(),
    120,
    scrollable: storyDetailsScrollableFinder(),
  );
  await tester.pumpAndSettle();
}

Future<void> scrollToStoryDetailsMapAction(
  WidgetTester tester,
) async {
  await tester.scrollUntilVisible(
    storyDetailsMapActionFinder(),
    120,
    scrollable: storyDetailsScrollableFinder(),
  );
  await tester.pumpAndSettle();
}

Future<void> scrollToStoryDetailsTimelineAction(
  WidgetTester tester,
) async {
  await tester.scrollUntilVisible(
    storyDetailsTimelineActionFinder(),
    120,
    scrollable: storyDetailsScrollableFinder(),
  );
  await tester.pumpAndSettle();
}

Future<void> scrollToStoryDetailsPlaybackAction(
  WidgetTester tester,
) async {
  await tester.scrollUntilVisible(
    storyDetailsPlaybackActionFinder(),
    120,
    scrollable: storyDetailsScrollableFinder(),
  );
  await tester.pumpAndSettle();
}

Future<void> scrollToStoryDetailsSoundtrackSummary(
  WidgetTester tester,
) async {
  await tester.scrollUntilVisible(
    storyDetailsSoundtrackSummaryFinder(),
    120,
    scrollable: storyDetailsScrollableFinder(),
  );
  await tester.pumpAndSettle();
}

Future<void> scrollDownUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxScrolls = 8,
}) async {
  for (var index = 0; index < maxScrolls; index += 1) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      return;
    }

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
    await tester.pumpAndSettle();
  }

  fail('Expected finder to become visible after scrolling: $finder');
}

Future<void> scrollUpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxScrolls = 8,
}) async {
  for (var index = 0; index < maxScrolls; index += 1) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }

    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    if (verticalScrollable.evaluate().isEmpty) {
      break;
    }

    await tester.drag(verticalScrollable.first, const Offset(0, 320));
    await tester.pumpAndSettle();
  }
}

Future<void> scrollToMemoryDetailsDeleteAction(
  WidgetTester tester,
) async {
  await tester.scrollUntilVisible(
    memoryDetailsDeleteActionFinder(),
    120,
    scrollable: memoryDetailsScrollableFinder(),
  );
  await tester.pumpAndSettle();
}

Finder leaveActionFinder() {
  return find.byKey(const ValueKey('participants.leave-action'));
}

Finder storyDetailsMemoriesActionFinder() {
  return find.byKey(const ValueKey('story-details.memories-action'));
}

Finder storyDetailsScreenFinder() {
  return find.byKey(const ValueKey('story-details.screen'));
}

Finder storyDetailsScrollableFinder() {
  return find.descendant(
    of: storyDetailsScreenFinder(),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    ),
  );
}

Finder storyDetailsParticipantsActionFinder() {
  return find.byKey(const ValueKey('story-details.participants.manage-action'));
}

Finder storyDetailsMapActionFinder() {
  return find.byKey(const ValueKey('story-details.map-action'));
}

Finder storyDetailsTimelineActionFinder() {
  return find.byKey(const ValueKey('story-details.timeline-action'));
}

Finder storyDetailsPlaybackActionFinder() {
  return find.byKey(const ValueKey('story-details.playback-action'));
}

Finder storyDetailsSoundtrackSummaryFinder() {
  return find.byKey(const ValueKey('story-details.soundtrack-summary'));
}

Finder memoryDetailsDeleteActionFinder() {
  return find.byKey(const ValueKey('memory-details.delete-action'));
}

Finder memoryDetailsScrollableFinder() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );
}

Finder removeActionFor(StoryParticipant participant) {
  return find.byKey(ValueKey('participants.remove-action.${participant.userId}'));
}

Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  FakeAuthRepository fakeAuthRepository, {
  FakeStoryRepository? storyRepository,
  FakeInviteRepository? inviteRepository,
  FakeStoryParticipantRepository? participantRepository,
  FakeMemoryRepository? memoryRepository,
  FakeMusicRepository? musicRepository,
  FakeStorySoundtrackRepository? soundtrackRepository,
  media_fixtures.FakeMediaRepository? mediaRepository,
  StoryMapBuilder? storyMapBuilder,
  PlaybackMapBuilder? storyPlaybackMapBuilder,
  FakeAppLanguagePreferenceStorage? languageStorage,
}) async {
  final container = createContainer(
    fakeAuthRepository,
    storyRepository: storyRepository,
    inviteRepository: inviteRepository,
    participantRepository: participantRepository,
    memoryRepository: memoryRepository,
    musicRepository: musicRepository,
    soundtrackRepository: soundtrackRepository,
    mediaRepository: mediaRepository,
    storyMapBuilder: storyMapBuilder,
    storyPlaybackMapBuilder: storyPlaybackMapBuilder,
    languageStorage: languageStorage,
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
  FakeInviteRepository? inviteRepository,
  FakeStoryParticipantRepository? participantRepository,
  FakeMemoryRepository? memoryRepository,
  FakeMusicRepository? musicRepository,
  FakeStorySoundtrackRepository? soundtrackRepository,
  media_fixtures.FakeMediaRepository? mediaRepository,
  StoryMapBuilder? storyMapBuilder,
  PlaybackMapBuilder? storyPlaybackMapBuilder,
  FakeAppLanguagePreferenceStorage? languageStorage,
}) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(fakeAuthRepository),
      appLanguagePreferenceStorageProvider.overrideWithValue(
        languageStorage ?? FakeAppLanguagePreferenceStorage(),
      ),
      storyRepositoryProvider.overrideWithValue(
        storyRepository ?? FakeStoryRepository(),
      ),
      inviteRepositoryProvider.overrideWithValue(
        inviteRepository ?? FakeInviteRepository(),
      ),
      storyParticipantRepositoryProvider.overrideWithValue(
        participantRepository ?? FakeStoryParticipantRepository(),
      ),
      memoryRepositoryProvider.overrideWithValue(
        memoryRepository ?? FakeMemoryRepository(),
      ),
      musicRepositoryProvider.overrideWithValue(
        musicRepository ?? FakeMusicRepository(),
      ),
      storySoundtrackRepositoryProvider.overrideWithValue(
        soundtrackRepository ?? FakeStorySoundtrackRepository(),
      ),
      mediaRepositoryProvider.overrideWithValue(
        mediaRepository ??
            (media_fixtures.FakeMediaRepository()..mediaResult = <Media>[]),
      ),
      locationPickerMapBuilderProvider.overrideWithValue(
        fakeLocationPickerMapBuilder,
      ),
      memoryDetailsMapBuilderProvider.overrideWithValue(
        fakeMemoryLocationMapBuilder,
      ),
      if (storyMapBuilder != null)
        storyMapBuilderProvider.overrideWithValue(storyMapBuilder),
      if (storyPlaybackMapBuilder != null)
        storyPlaybackMapBuilderProvider.overrideWithValue(
          storyPlaybackMapBuilder,
        ),
      playbackAudioOrchestratorProvider.overrideWith(
        (ref, storyId) => FakePlaybackAudioSessionOrchestrator(),
      ),
    ],
  );
}

final class FakeAppLanguagePreferenceStorage
    implements AppLanguagePreferenceStorage {
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
final UserStory acceptedInviteStory = userStory(
  id: 'accepted-story',
  title: 'Accepted invite story',
  description: 'Joined through an invite',
  role: StoryRole.viewer,
);
final MemoryLocation memoryLocationA = MemoryLocation(
  latitude: 41.7151,
  longitude: 44.8271,
);
final MemoryLocation memoryLocationB = MemoryLocation(
  latitude: 41.6168,
  longitude: 41.6367,
);
final MemoryDate memoryDateA = MemoryDate(
  year: 2026,
  month: 8,
  day: 9,
);
final Memory memoryA = memory(
  id: 'memory-a',
  title: 'First picnic',
  createdBy: 'author-id',
  eventDate: memoryDateA,
  location: memoryLocationA,
);
final Memory memoryB = memory(
  id: 'memory-b',
  title: 'Beach morning',
  createdBy: session.user.id,
  eventDate: MemoryDate(year: 2026, month: 8, day: 15),
  location: memoryLocationB,
);
final Memory createdMemory = memory(
  id: 'created-memory',
  title: 'Created memory',
  createdBy: session.user.id,
  eventDate: MemoryDate(year: 2026, month: 8, day: 10),
  location: memoryLocationA,
);
final Memory updatedMemory = memory(
  id: memoryA.id,
  title: 'Updated memory',
  description: 'Updated description',
  placeName: 'Updated place',
  createdBy: memoryA.createdBy,
  eventDate: memoryA.eventDate,
  location: memoryA.location,
);
MemoryPhotoPreview previewPhoto(String mediaId) {
  return MemoryPhotoPreview(
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}

const String validInviteToken = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
final Invite invite = Invite(
  inviteLink: Uri.parse('https://app.memorymap.app/invite/$validInviteToken'),
  expiresAt: DateTime.utc(2026, 2, 9, 10),
);
final StoryParticipant currentUserParticipant = StoryParticipant(
  userId: session.user.id,
  displayName: session.user.displayName,
  avatarUrl: session.user.avatarUrl,
  role: StoryRole.owner,
  joinedAt: DateTime.utc(2026, 8, 9, 10),
);
final StoryParticipant viewerParticipant = StoryParticipant(
  userId: 'viewer-user-id',
  displayName: 'Grace Hopper',
  avatarUrl: null,
  role: StoryRole.viewer,
  joinedAt: DateTime.utc(2026, 8, 9, 11),
);

final MusicTrack soundtrackTrack = MusicTrack(
  id: 'track-a',
  title: 'Autumn Leaves',
  artist: 'LofCosmos',
  durationSeconds: 270,
);

final class FakeAuthRepository implements AuthRepository {
  int logoutCalls = 0;
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
    logoutCalls += 1;

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

final class FakeInviteRepository implements InviteRepository {
  int createCalls = 0;
  int acceptCalls = 0;
  CreateInviteInput? receivedCreateInput;
  AcceptInviteInput? receivedAcceptInput;
  UserStory acceptResult = ownerStory;
  Object? acceptFailure;

  @override
  Future<Invite> createInvite(CreateInviteInput input) async {
    createCalls += 1;
    receivedCreateInput = input;
    return invite;
  }

  @override
  Future<UserStory> acceptInvite(AcceptInviteInput input) async {
    acceptCalls += 1;
    receivedAcceptInput = input;

    final failure = acceptFailure;
    if (failure != null) {
      throw failure;
    }

    return acceptResult;
  }
}

final class FakeStoryParticipantRepository
    implements StoryParticipantRepository {
  int getParticipantsCalls = 0;
  int leaveStoryCalls = 0;
  int removeParticipantCalls = 0;
  LeaveStoryInput? receivedLeaveInput;
  RemoveStoryParticipantInput? receivedRemoveInput;
  List<StoryParticipant> participantsResult = <StoryParticipant>[
    currentUserParticipant,
    viewerParticipant,
  ];
  final List<String> receivedStoryIds = <String>[];
  Object? leaveFailure;
  Object? removeFailure;

  @override
  Future<List<StoryParticipant>> getParticipants(String storyId) async {
    getParticipantsCalls += 1;
    receivedStoryIds.add(storyId);
    return participantsResult;
  }

  @override
  Future<void> leaveStory(LeaveStoryInput input) async {
    leaveStoryCalls += 1;
    receivedLeaveInput = input;

    final failure = leaveFailure;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<void> removeParticipant(RemoveStoryParticipantInput input) async {
    removeParticipantCalls += 1;
    receivedRemoveInput = input;

    final failure = removeFailure;
    if (failure != null) {
      throw failure;
    }
  }
}

final class FakeMusicRepository implements MusicRepository {
  int getAvailableTracksCalls = 0;
  List<MusicTrack> tracksResult = const <MusicTrack>[];

  @override
  Future<List<MusicTrack>> getAvailableTracks() async {
    getAvailableTracksCalls += 1;
    return tracksResult;
  }
}

final class FakeStorySoundtrackRepository
    implements StorySoundtrackRepository {
  final List<String> operations = <String>[];
  StorySoundtrack getResult = StorySoundtrack.noMusic();
  StorySoundtrack setResult = StorySoundtrack.noMusic();

  @override
  Future<StorySoundtrack> getStorySoundtrack(String storyId) async {
    operations.add('get:$storyId');
    return getResult;
  }

  @override
  Future<StorySoundtrack> setStorySoundtrack(
    String storyId,
    String musicTrackId,
  ) async {
    operations.add('set:$storyId:$musicTrackId');
    getResult = setResult;
    return setResult;
  }

  @override
  Future<StorySoundtrack> removeStorySoundtrack(String storyId) async {
    operations.add('remove:$storyId');
    getResult = StorySoundtrack.noMusic();
    return getResult;
  }
}

final class FakeMemoryRepository implements MemoryRepository {
  int getMemoriesCalls = 0;
  int getMemoryCalls = 0;
  int createMemoryCalls = 0;
  int updateMemoryCalls = 0;
  int deleteMemoryCalls = 0;

  List<Memory> memoriesResult = <Memory>[memoryA, memoryB];
  List<MemoryReadModel>? readModelsResult;
  Memory memoryResult = memoryA;
  MemoryReadModel? memoryReadResult;
  Memory createResult = createdMemory;
  Memory updateResult = updatedMemory;
  final List<String> receivedStoryIds = <String>[];
  final List<String> receivedMemoryIds = <String>[];
  CreateMemoryInput? receivedCreateInput;
  UpdateMemoryInput? receivedUpdateInput;
  DeleteMemoryInput? receivedDeleteInput;

  @override
  Future<List<MemoryReadModel>> getMemories(String storyId) async {
    getMemoriesCalls += 1;
    receivedStoryIds.add(storyId);
    final readModels = readModelsResult;
    if (readModels != null) {
      return readModels;
    }

    return memoriesResult.map(MemoryReadModel.fromMemory).toList();
  }

  @override
  Future<MemoryReadModel> getMemory(String memoryId) async {
    getMemoryCalls += 1;
    receivedMemoryIds.add(memoryId);
    final readModel = memoryReadResult;
    if (readModel != null && readModel.memory.id == memoryId) {
      return readModel;
    }

    if (memoryId == memoryB.id) {
      return MemoryReadModel.fromMemory(memoryB);
    }
    if (memoryId == createResult.id) {
      return MemoryReadModel.fromMemory(createResult);
    }
    if (memoryId == updateResult.id && updateMemoryCalls > 0) {
      return MemoryReadModel.fromMemory(updateResult);
    }

    return MemoryReadModel.fromMemory(memoryResult);
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    createMemoryCalls += 1;
    receivedCreateInput = input;
    return createResult;
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    updateMemoryCalls += 1;
    receivedUpdateInput = input;
    memoryResult = updateResult;
    return updateResult;
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) async {
    deleteMemoryCalls += 1;
    receivedDeleteInput = input;
    memoriesResult = memoriesResult
        .where((memory) => memory.id != input.memoryId)
        .toList();
    readModelsResult = readModelsResult
        ?.where((readModel) => readModel.memory.id != input.memoryId)
        .toList();
  }
}

final class UnexpectedAuthException implements Exception {
  const UnexpectedAuthException();
}

Memory memory({
  required String id,
  String storyId = 'story-1',
  String createdBy = 'author-id',
  String title = 'Memory title',
  String? description = 'Memory description',
  String? placeName = 'Memory place',
  required MemoryLocation location,
  required MemoryDate eventDate,
}) {
  return Memory(
    id: id,
    storyId: storyId,
    createdBy: createdBy,
    title: title,
    description: description,
    placeName: placeName,
    location: location,
    eventDate: eventDate,
    createdAt: DateTime.utc(2026, 8, 9, 10),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

Widget fakeLocationPickerMapBuilder(
  BuildContext context,
  LocationPickerMapConfiguration configuration,
  MemoryLocation? selectedLocation,
  ValueChanged<MemoryLocation> onPointSelected,
) {
  return Column(
    key: const ValueKey('location-picker.fake-map'),
    children: [
      Expanded(
        child: Center(
          child: Text(
            selectedLocation == null ? 'Fake map idle' : 'Fake map selected',
          ),
        ),
      ),
      TextButton(
        key: const ValueKey('location-picker.fake-map.select-a'),
        onPressed: () {
          onPointSelected(memoryLocationA);
        },
        child: const Text('Select point A'),
      ),
      TextButton(
        key: const ValueKey('location-picker.fake-map.select-b'),
        onPressed: () {
          onPointSelected(memoryLocationB);
        },
        child: const Text('Select point B'),
      ),
    ],
  );
}

Widget fakeStoryMapBuilder(
  BuildContext context,
  StoryMapViewConfiguration configuration,
) {
  return Column(
    key: const ValueKey('story-map.fake-map'),
    children: [
      Expanded(
        child: Center(
          child: Text('Fake story map markers: ${configuration.markers.length}'),
        ),
      ),
      for (final marker in configuration.markers)
        TextButton(
          key: ValueKey('story-map.fake-marker.${marker.id}'),
          onPressed: () {
            configuration.onMarkerSelected(marker.id);
          },
          child: Text('Select marker ${marker.id}'),
        ),
    ],
  );
}

Widget fakeMemoryLocationMapBuilder(
  BuildContext context,
  MemoryLocationMapConfiguration configuration,
) {
  return const SizedBox(
    key: ValueKey('memory-details.fake-map'),
  );
}

Widget fakeStoryPlaybackMapBuilder(
  BuildContext context,
  PlaybackMapPresentation presentation,
) {
  return ColoredBox(
    key: const ValueKey('story-playback.fake-map'),
    color: const Color(0xFF101820),
    child: Center(
      child: Text(
        'Fake playback markers: ${presentation.markers.length}',
        style: const TextStyle(color: Colors.white),
      ),
    ),
  );
}

Widget controllableStoryPlaybackMapBuilder(
  BuildContext context,
  PlaybackMapPresentation presentation,
) {
  return ColoredBox(
    key: const ValueKey('story-playback.fake-map'),
    color: const Color(0xFF101820),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Fake playback markers: ${presentation.markers.length}',
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            'Fake playback current: ${presentation.currentIndex ?? -1}',
            style: const TextStyle(color: Colors.white),
          ),
          TextButton(
            key: const ValueKey('story-playback.fake-camera-arrived'),
            onPressed: () {
              final command = presentation.cameraCommand;
              if (command != null) {
                presentation.onCameraArrived(command.revision);
              }
            },
            child: const Text('Arrive camera'),
          ),
        ],
      ),
    ),
  );
}

final class FakePlaybackAudioSessionOrchestrator
    implements PlaybackAudioSessionOrchestrator {
  @override
  PlaybackAudioSessionStatus status = PlaybackAudioSessionStatus.idle;

  @override
  Future<void> cameraFailed() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> finish() async {}

  @override
  void invalidateSession() {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> playbackStarted() async {}

  @override
  Future<void> replay() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> startSession({required String storyId}) async {}
}
