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
import 'package:memory_map/features/invite/application/invite_application_exception.dart';
import 'package:memory_map/features/invite/application/invite_application_providers.dart';
import 'package:memory_map/features/invite/application/pending_invite_notifier.dart';
import 'package:memory_map/features/invite/domain/accept_invite_input.dart';
import 'package:memory_map/features/invite/domain/create_invite_input.dart';
import 'package:memory_map/features/invite/domain/invite.dart';
import 'package:memory_map/features/invite/domain/invite_failure.dart';
import 'package:memory_map/features/invite/domain/invite_repository.dart';
import 'package:memory_map/features/participant/application/participant_application_exception.dart';
import 'package:memory_map/features/participant/application/participant_application_providers.dart';
import 'package:memory_map/features/participant/domain/leave_story_input.dart';
import 'package:memory_map/features/participant/domain/participant_failure.dart';
import 'package:memory_map/features/participant/domain/remove_story_participant_input.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/participant/domain/story_participant_repository.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/application/stories_notifier.dart';
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
        '/stories/story-1/invite',
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

      expect(find.text('About this story'), findsOneWidget);
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

      expect(find.text('About this story'), findsOneWidget);

      await tapButton(
        tester,
        find.byKey(const ValueKey('story-details.invite-action')),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('About this story'), findsOneWidget);
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

      expect(find.text('About this story'), findsOneWidget);
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

      expect(find.text('About this story'), findsOneWidget);
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

      expect(find.text('About this story'), findsOneWidget);
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

      expect(find.text('About this story'), findsOneWidget);
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
      expect(find.text('About this story'), findsNothing);

      await tapButton(
        tester,
        find.byKey(const ValueKey('participants.back-action')),
      );

      expect(find.text('About this story'), findsOneWidget);
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

      expect(find.text('About this story'), findsNothing);
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
    scrollable: find.byType(Scrollable),
  );
  await tester.pumpAndSettle();
}

Finder leaveActionFinder() {
  return find.byKey(const ValueKey('participants.leave-action'));
}

Finder storyDetailsParticipantsActionFinder() {
  return find.byKey(const ValueKey('story-details.participants-action'));
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
}) async {
  final container = createContainer(
    fakeAuthRepository,
    storyRepository: storyRepository,
    inviteRepository: inviteRepository,
    participantRepository: participantRepository,
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
}) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(fakeAuthRepository),
      storyRepositoryProvider.overrideWithValue(
        storyRepository ?? FakeStoryRepository(),
      ),
      inviteRepositoryProvider.overrideWithValue(
        inviteRepository ?? FakeInviteRepository(),
      ),
      storyParticipantRepositoryProvider.overrideWithValue(
        participantRepository ?? FakeStoryParticipantRepository(),
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
final UserStory acceptedInviteStory = userStory(
  id: 'accepted-story',
  title: 'Accepted invite story',
  description: 'Joined through an invite',
  role: StoryRole.viewer,
);
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

final class UnexpectedAuthException implements Exception {
  const UnexpectedAuthException();
}
