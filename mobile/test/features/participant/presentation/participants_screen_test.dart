import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/participant/application/participant_application_exception.dart';
import 'package:memory_map/features/participant/application/participant_application_providers.dart';
import 'package:memory_map/features/participant/application/participants_notifier.dart';
import 'package:memory_map/features/participant/domain/leave_story_input.dart';
import 'package:memory_map/features/participant/domain/participant_failure.dart';
import 'package:memory_map/features/participant/domain/remove_story_participant_input.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/participant/domain/story_participant_repository.dart';
import 'package:memory_map/features/participant/presentation/participants_screen.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('ParticipantsScreen rendering', () {
    testWidgets('shouldRenderEnglishParticipantList', (tester) async {
      await pumpScreen(tester, FakeStoryParticipantRepository());

      expect(find.text('Participants'), findsWidgets);
      expect(find.text('People in this story'), findsOneWidget);
      expect(find.text('4 participants'), findsOneWidget);
      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Mira'), findsOneWidget);
      expect(find.text('Oleg'), findsOneWidget);
      expect(find.text('Owner'), findsWidgets);
      expect(find.text('Co-owner'), findsOneWidget);
      expect(find.text('Editor'), findsOneWidget);
      expect(find.text('Viewer'), findsOneWidget);
    });

    testWidgets('shouldRenderRussianParticipantList', (tester) async {
      await pumpScreen(
        tester,
        FakeStoryParticipantRepository(),
        locale: const Locale('ru'),
      );

      expect(find.text('Участники'), findsWidgets);
      expect(find.text('Люди в этой истории'), findsOneWidget);
      expect(find.text('4 участника'), findsOneWidget);
      expect(find.text('Владелец'), findsWidgets);
      expect(find.text('Совладелец'), findsOneWidget);
    });

    testWidgets('shouldPreserveBackendOrder', (tester) async {
      await pumpScreen(
        tester,
        FakeStoryParticipantRepository()
          ..participantsResult = <StoryParticipant>[
            viewerParticipant,
            ownerParticipant,
            editorParticipant,
          ],
      );

      expect(
        tester.getTopLeft(find.text('Alex')).dy,
        lessThan(tester.getTopLeft(find.text('Anna')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Anna')).dy,
        lessThan(tester.getTopLeft(find.text('Mira')).dy),
      );
    });

    testWidgets('shouldRenderNullableAndNetworkAvatarPaths', (tester) async {
      await pumpScreen(tester, FakeStoryParticipantRepository());

      final avatars = tester.widgetList<CircleAvatar>(
        find.byType(CircleAvatar),
      ).toList();
      final networkAvatar = avatars[0];
      final fallbackAvatar = avatars[3];

      expect(networkAvatar.foregroundImage, isA<NetworkImage>());
      expect(fallbackAvatar.foregroundImage, isNull);
      expect((fallbackAvatar.child! as Text).data, 'A');
    });

    testWidgets('shouldMarkCurrentUserByExactUserId', (tester) async {
      await pumpScreen(
        tester,
        FakeStoryParticipantRepository()
          ..participantsResult = <StoryParticipant>[
            sameNameCurrentUser,
            sameNameOtherUser,
          ],
        currentUserId: 'current-user-id',
      );

      expect(find.text('You'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('You')).dy,
        lessThan(tester.getTopLeft(find.text('Viewer')).dy),
      );
    });
  });

  group('ParticipantsScreen loading and failures', () {
    testWidgets('shouldRenderInitialLoadingWithoutFakeParticipants', (
      tester,
    ) async {
      final completer = Completer<List<StoryParticipant>>();
      final repository = FakeStoryParticipantRepository()
        ..getCompleter = completer;

      await pumpScreen(tester, repository, settle: false);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('participants.loading-view')),
        findsOneWidget,
      );
      expect(find.text('Anna'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);

      completer.complete(<StoryParticipant>[ownerParticipant]);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRenderEmptyStateWithoutPrivilegedActions', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryParticipantRepository()
          ..participantsResult = <StoryParticipant>[],
        onInvite: () {},
        onLeftStory: () {},
        onParticipantRemoved: (_) {},
      );

      expect(find.text('No participants to show'), findsOneWidget);
      expect(find.text('No participants'), findsOneWidget);
      expect(find.byKey(const ValueKey('participants.invite-action')),
          findsNothing);
      expect(find.byKey(const ValueKey('participants.leave-action')),
          findsNothing);
      expect(find.byIcon(Icons.person_remove_alt_1_rounded), findsNothing);
    });

    testWidgets('shouldRenderKnownFailureSafelyAndRetry', (tester) async {
      final repository = FakeStoryParticipantRepository()
        ..getFailures.add(
          const ParticipantApplicationException(
            ParticipantNetworkUnavailable(),
          ),
        )
        ..participantsResult = <StoryParticipant>[ownerParticipant];
      await pumpScreen(tester, repository);

      expect(find.text('Could not load participants'), findsOneWidget);
      expect(
        find.text('No network connection. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('ParticipantApplicationException'),
          findsNothing);

      await pressButton(
        tester,
        find.byKey(const ValueKey('participants.error.retry-action')),
      );

      expect(repository.getCalls, 2);
      expect(find.text('Anna'), findsOneWidget);
    });

    testWidgets('shouldRenderAsyncErrorSafely', (tester) async {
      await pumpScreen(
        tester,
        FakeStoryParticipantRepository()
          ..getFailures.add(const UnexpectedParticipantException()),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('UnexpectedParticipantException'),
          findsNothing);
      expect(find.textContaining('StackTrace'), findsNothing);
    });
  });

  group('ParticipantsScreen refresh', () {
    testWidgets('shouldKeepContentVisibleWhileRefreshing', (tester) async {
      final refreshCompleter = Completer<List<StoryParticipant>>();
      final repository = FakeStoryParticipantRepository();
      final container = await pumpScreen(tester, repository);
      repository.getCompleter = refreshCompleter;

      final refresh = container
          .read(storyParticipantsProvider(defaultStoryId).notifier)
          .refreshParticipants();
      await tester.pump();

      expect(find.text('Anna'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      refreshCompleter.complete(<StoryParticipant>[viewerParticipant]);
      await refresh;
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRenderRefreshFailureBannerAndRetry', (tester) async {
      final repository = FakeStoryParticipantRepository();
      await pumpScreen(tester, repository);
      repository.getFailures.add(
        const ParticipantApplicationException(ParticipantRequestTimedOut()),
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 360));
      await tester.pumpAndSettle();

      expect(find.text('Anna'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('participants.refresh.failure-banner')),
        findsOneWidget,
      );
      expect(find.text('Could not refresh participants. The request timed out. '
          'Please try again.'), findsOneWidget);

      await pressButton(
        tester,
        find.byKey(const ValueKey('participants.refresh.retry-action')),
      );

      expect(repository.getCalls, 3);
    });
  });

  group('ParticipantsScreen actions', () {
    testWidgets('shouldShowInviteForOwnerAndCoOwnerOnlyAndCallCallback', (
      tester,
    ) async {
      for (final role in StoryRole.values) {
        var calls = 0;
        await pumpScreen(
          tester,
          FakeStoryParticipantRepository()
            ..participantsResult = participantsWithCurrentRole(role),
          currentUserId: 'current-user-id',
          onInvite: () {
            calls += 1;
          },
        );

        final action = find.byKey(const ValueKey('participants.invite-action'));
        if (role == StoryRole.owner || role == StoryRole.coOwner) {
          expect(action, findsOneWidget);
          await pressButton(tester, action);
          expect(calls, 1);
        } else {
          expect(action, findsNothing);
          expect(calls, 0);
        }
      }
    });

    testWidgets('shouldOpenLeaveConfirmationAndCancelWithoutBackendCall', (
      tester,
    ) async {
      var leftCalls = 0;
      final repository = FakeStoryParticipantRepository();
      await pumpScreen(
        tester,
        repository,
        currentUserId: 'owner-user-id',
        onLeftStory: () {
          leftCalls += 1;
        },
      );

      await scrollToLeaveAction(tester);
      await pressButton(tester, leaveActionFinder());

      expect(find.text('Leave story?'), findsOneWidget);
      expect(
        find.textContaining('You will lose access to this story.'),
        findsOneWidget,
      );
      expect(repository.leaveCalls, 0);

      await pressButton(
        tester,
        find.byKey(const ValueKey('participants.leave.cancel-action')),
      );

      expect(find.text('Leave story?'), findsNothing);
      expect(repository.leaveCalls, 0);
      expect(leftCalls, 0);
    });

    testWidgets('shouldShowLeaveForEveryCurrentParticipantRole', (
      tester,
    ) async {
      for (final role in StoryRole.values) {
        await pumpScreen(
          tester,
          FakeStoryParticipantRepository()
            ..participantsResult = participantsWithCurrentRole(role),
          currentUserId: 'current-user-id',
          onLeftStory: () {},
        );

        expect(
          leaveActionFinder(),
          findsOneWidget,
        );
      }
    });

    testWidgets('shouldConfirmLeaveAndCallSuccessCallbackOnce', (
      tester,
    ) async {
      var leftCalls = 0;
      final repository = FakeStoryParticipantRepository();
      await pumpScreen(
        tester,
        repository,
        currentUserId: 'owner-user-id',
        onLeftStory: () {
          leftCalls += 1;
        },
      );

      await scrollToLeaveAction(tester);
      await pressButton(tester, leaveActionFinder());
      await pressButton(
        tester,
        find.byKey(const ValueKey('participants.leave.confirm-action')),
      );

      expect(repository.leaveCalls, 1);
      expect(
        repository.receivedLeaveInput,
        LeaveStoryInput(storyId: defaultStoryId),
      );
      expect(leftCalls, 1);
      await scrollToParticipantName(tester, 'Anna');
      expect(find.text('Anna'), findsOneWidget);
    });

    testWidgets('shouldShowLeavePendingAndBlockDuplicateAndBack', (
      tester,
    ) async {
      final leaveCompleter = Completer<void>();
      var backCalls = 0;
      var leftCalls = 0;
      final repository = FakeStoryParticipantRepository()
        ..leaveCompleter = leaveCompleter;
      await pumpScreen(
        tester,
        repository,
        currentUserId: 'owner-user-id',
        onBack: () {
          backCalls += 1;
        },
        onInvite: () {},
        onLeftStory: () {
          leftCalls += 1;
        },
        onParticipantRemoved: (_) {},
      );

      await scrollToLeaveAction(tester);
      await pressButton(tester, leaveActionFinder());
      await pressButton(
        tester,
        find.byKey(const ValueKey('participants.leave.confirm-action')),
        settle: false,
      );
      await tester.pump();

      expect(find.text('Leaving story...'), findsOneWidget);
      expect(repository.leaveCalls, 1);
      await pressButton(
        tester,
        leaveActionFinder(),
        settle: false,
      );
      await scrollToBackAction(tester, settle: false);
      await pressButton(
        tester,
        find.byKey(const ValueKey('participants.back-action')),
        settle: false,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(repository.leaveCalls, 1);
      expect(backCalls, 0);
      expect(
        tester.widget<FilledButton>(
          find.byKey(const ValueKey('participants.invite-action')),
        ).onPressed,
        isNull,
      );
      expect(leftCalls, 0);

      leaveCompleter.complete();
      await tester.pumpAndSettle();
      expect(leftCalls, 1);
    });

    testWidgets('shouldRenderLeaveFailuresSafelyWithoutCallingSuccessCallback', (
      tester,
    ) async {
      final failures = <ParticipantFailure, String>{
        const ParticipantLastOwnerConflict():
            'The last owner cannot leave this story.',
        const ParticipantNotFound(): 'Participants are unavailable.',
        const ParticipantUnauthorized():
            'Your session needs attention. Please try again.',
        const ParticipantRequestTimedOut():
            'The request timed out. Please try again.',
        const ParticipantServerFailure():
            'The server is temporarily unavailable. Please try again.',
        const UnknownParticipantFailure():
            'Something went wrong. Please try again.',
      };

      for (final entry in failures.entries) {
        var leftCalls = 0;
        final repository = FakeStoryParticipantRepository()
          ..leaveFailure = ParticipantApplicationException(entry.key);
        await pumpScreen(
          tester,
          repository,
          currentUserId: 'owner-user-id',
          onLeftStory: () {
            leftCalls += 1;
          },
        );

        await scrollToLeaveAction(tester);
        await pressButton(tester, leaveActionFinder());
        await pressButton(
          tester,
          find.byKey(const ValueKey('participants.leave.confirm-action')),
        );

        await scrollToParticipantName(tester, 'Anna', settle: false);
        expect(find.text(entry.value), findsOneWidget);
        expect(find.text('Anna'), findsOneWidget);
        expect(find.textContaining('ParticipantApplicationException'),
            findsNothing);
        expect(find.textContaining('private-story-id'), findsNothing);
        expect(find.textContaining('owner-user-id'), findsNothing);
        expect(leftCalls, 0);
      }
    });

    testWidgets('shouldNotBlockOwnerLeaveClientSideWhenLastOwner', (
      tester,
    ) async {
      final repository = FakeStoryParticipantRepository()
        ..participantsResult = <StoryParticipant>[ownerParticipant]
        ..leaveFailure = const ParticipantApplicationException(
          ParticipantLastOwnerConflict(),
        );
      await pumpScreen(
        tester,
        repository,
        currentUserId: 'owner-user-id',
        onLeftStory: () {},
      );

      await scrollToLeaveAction(tester);
      await pressButton(tester, leaveActionFinder());
      await pressButton(
        tester,
        find.byKey(const ValueKey('participants.leave.confirm-action')),
      );

      expect(repository.leaveCalls, 1);
      expect(
        find.text('The last owner cannot leave this story.'),
        findsOneWidget,
      );
    });

    testWidgets('shouldHideLeaveWhenCurrentParticipantIsAbsent', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryParticipantRepository(),
        currentUserId: 'missing-user-id',
        onLeftStory: () {},
      );

      expect(find.byKey(const ValueKey('participants.leave-action')),
          findsNothing);
    });

    testWidgets('shouldShowRemoveOnlyForOwnerEligibleTargets', (tester) async {
      await pumpScreen(
        tester,
        FakeStoryParticipantRepository(),
        currentUserId: 'owner-user-id',
        onParticipantRemoved: (_) {},
      );

      expect(removeActionFor(coOwnerParticipant), findsOneWidget);
      expect(removeActionFor(editorParticipant), findsOneWidget);
      expect(removeActionFor(viewerParticipant), findsOneWidget);
      expect(removeActionFor(ownerParticipant), findsNothing);
    });

    testWidgets('shouldHideRemoveForNonOwnerActors', (tester) async {
      for (final role in <StoryRole>[
        StoryRole.coOwner,
        StoryRole.editor,
        StoryRole.viewer,
      ]) {
        await pumpScreen(
          tester,
          FakeStoryParticipantRepository()
            ..participantsResult = participantsWithCurrentRole(role),
          currentUserId: 'current-user-id',
          onParticipantRemoved: (_) {},
        );

        expect(find.byIcon(Icons.person_remove_alt_1_rounded), findsNothing);
      }
    });

    testWidgets('shouldOpenRemoveConfirmationAndCancelWithoutBackendCall', (
      tester,
    ) async {
      StoryParticipant? removedParticipant;
      final repository = FakeStoryParticipantRepository();
      await pumpScreen(
        tester,
        repository,
        currentUserId: 'owner-user-id',
        onParticipantRemoved: (participant) {
          removedParticipant = participant;
        },
      );

      await pressButton(tester, removeActionFor(viewerParticipant));

      expect(find.text('Remove Alex?'), findsOneWidget);
      expect(find.textContaining('Alex will lose access to this story.'),
          findsOneWidget);
      expect(find.textContaining('viewer-user-id'), findsNothing);
      expect(repository.removeCalls, 0);

      await pressButton(
        tester,
        find.byKey(const ValueKey('participants.remove.cancel-action')),
      );

      expect(find.text('Remove Alex?'), findsNothing);
      expect(repository.removeCalls, 0);
      expect(removedParticipant, isNull);
      expect(find.text('Alex'), findsOneWidget);
    });

    testWidgets('shouldConfirmRemoveAfterBackendSuccessAndCallCallback', (
      tester,
    ) async {
      StoryParticipant? removedParticipant;
      final repository = FakeStoryParticipantRepository();
      await pumpScreen(
        tester,
        repository,
        currentUserId: 'owner-user-id',
        onParticipantRemoved: (participant) {
          removedParticipant = participant;
        },
      );

      await pressButton(tester, removeActionFor(viewerParticipant));
      await pressButton(
        tester,
        find.byKey(const ValueKey('participants.remove.confirm-action')),
      );

      expect(repository.removeCalls, 1);
      expect(
        repository.receivedRemoveInput,
        RemoveStoryParticipantInput(
          storyId: defaultStoryId,
          participantUserId: viewerParticipant.userId,
        ),
      );
      expect(find.text('Alex'), findsNothing);
      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Mira'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Anna')).dy,
        lessThan(tester.getTopLeft(find.text('Mira')).dy),
      );
      expect(removedParticipant, viewerParticipant);
      expect(find.text('Alex was removed.'), findsOneWidget);
    });

    testWidgets('shouldNotOptimisticallyRemoveTargetWhilePending', (
      tester,
    ) async {
      final removeCompleter = Completer<void>();
      var backCalls = 0;
      final repository = FakeStoryParticipantRepository()
        ..removeCompleter = removeCompleter;
      await pumpScreen(
        tester,
        repository,
        currentUserId: 'owner-user-id',
        onBack: () {
          backCalls += 1;
        },
        onInvite: () {},
        onLeftStory: () {},
        onParticipantRemoved: (_) {},
      );

      await pressButton(tester, removeActionFor(viewerParticipant));
      await pressButton(
        tester,
        find.byKey(const ValueKey('participants.remove.confirm-action')),
        settle: false,
      );
      await tester.pump();

      expect(repository.removeCalls, 1);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(
          find.byKey(const ValueKey('participants.invite-action')),
        ).onPressed,
        isNull,
      );
      expect(
        tester.widget<IconButton>(removeActionFor(editorParticipant)).onPressed,
        isNull,
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('participants.back-action')),
        settle: false,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(backCalls, 0);
      await scrollToLeaveAction(tester, settle: false);
      expect(
        tester.widget<OutlinedButton>(leaveActionFinder()).onPressed,
        isNull,
      );

      removeCompleter.complete();
      await tester.pumpAndSettle();

      expect(find.text('Alex'), findsNothing);
    });

    testWidgets('shouldKeepTargetAndShowSafeRemoveFailures', (tester) async {
      final failures = <ParticipantFailure, String>{
        const ParticipantOwnerCannotBeRemoved():
            'Owners cannot be removed from here.',
        const ParticipantCannotRemoveSelf():
            'Use Leave story to remove yourself.',
        const ParticipantNotFound(): 'Participants are unavailable.',
        const ParticipantNetworkUnavailable():
            'No network connection. Check your connection and try again.',
        const ParticipantServerFailure():
            'The server is temporarily unavailable. Please try again.',
      };

      for (final entry in failures.entries) {
        final repository = FakeStoryParticipantRepository()
          ..removeFailure = ParticipantApplicationException(entry.key);
        StoryParticipant? removedParticipant;
        await pumpScreen(
          tester,
          repository,
          currentUserId: 'owner-user-id',
          onParticipantRemoved: (participant) {
            removedParticipant = participant;
          },
        );

        await pressButton(tester, removeActionFor(viewerParticipant));
        await pressButton(
          tester,
          find.byKey(const ValueKey('participants.remove.confirm-action')),
        );

        expect(find.text('Alex'), findsOneWidget);
        expect(find.text(entry.value), findsOneWidget);
        expect(find.textContaining('ParticipantApplicationException'),
            findsNothing);
        expect(find.textContaining('viewer-user-id'), findsNothing);
        expect(removedParticipant, isNull);
        expect(
          tester
              .widget<IconButton>(removeActionFor(viewerParticipant))
              .onPressed,
          isNotNull,
        );
      }
    });

    testWidgets('shouldHideActionsWhenCallbacksAreNull', (tester) async {
      await pumpScreen(tester, FakeStoryParticipantRepository());

      expect(find.byKey(const ValueKey('participants.invite-action')),
          findsNothing);
      expect(find.byKey(const ValueKey('participants.leave-action')),
          findsNothing);
      expect(find.byIcon(Icons.person_remove_alt_1_rounded), findsNothing);
    });
  });

  group('ParticipantsScreen responsiveness and confidentiality', () {
    testWidgets('shouldNotOverflowOnSmallPhoneWithLargeTextAndLongNames', (
      tester,
    ) async {
      setSurface(tester, const Size(360, 640));

      await pumpScreen(
        tester,
        FakeStoryParticipantRepository()
          ..participantsResult = <StoryParticipant>[
            longNameOwnerParticipant,
            longNameViewerParticipant,
          ],
        currentUserId: 'long-owner-user-id',
        onParticipantRemoved: (_) {},
        textScaler: const TextScaler.linear(1.3),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('shouldNotRenderIdsOrRawBackendDetails', (tester) async {
      await pumpScreen(
        tester,
        FakeStoryParticipantRepository()
          ..participantsResult = <StoryParticipant>[
            privateParticipant,
          ],
        storyId: 'private-story-id',
        currentUserId: 'private-user-id',
      );

      expect(find.textContaining('private-story-id'), findsNothing);
      expect(find.textContaining('private-user-id'), findsNothing);
      expect(find.textContaining('ownerId'), findsNothing);
      expect(find.textContaining('accessToken'), findsNothing);
      expect(find.textContaining('refreshToken'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
      expect(find.textContaining('HTTP'), findsNothing);
      expect(find.textContaining('ProblemDetail'), findsNothing);
    });
  });
}

Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  FakeStoryParticipantRepository repository, {
  String storyId = defaultStoryId,
  String currentUserId = 'owner-user-id',
  Locale locale = const Locale('en'),
  VoidCallback? onBack,
  VoidCallback? onInvite,
  VoidCallback? onLeftStory,
  ValueChanged<StoryParticipant>? onParticipantRemoved,
  TextScaler textScaler = TextScaler.noScaling,
  bool settle = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      storyParticipantRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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
        home: ParticipantsScreen(
          storyId: storyId,
          currentUserId: currentUserId,
          onBack: onBack,
          onInvite: onInvite,
          onLeftStory: onLeftStory,
          onParticipantRemoved: onParticipantRemoved,
        ),
      ),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  }

  return container;
}

Future<void> pressButton(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  final widget = tester.widget<Widget>(finder);
  final onPressed = switch (widget) {
    FilledButton(:final onPressed) => onPressed,
    OutlinedButton(:final onPressed) => onPressed,
    IconButton(:final onPressed) => onPressed,
    TextButton(:final onPressed) => onPressed,
    _ => throw StateError('Unsupported button widget: $widget'),
  };

  onPressed?.call();

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> scrollToLeaveAction(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await tester.scrollUntilVisible(
    leaveActionFinder(),
    120,
    scrollable: scrollableFinder(),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> scrollToBackAction(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('participants.back-action')),
    -120,
    scrollable: scrollableFinder(),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> scrollToParticipantName(
  WidgetTester tester,
  String name, {
  bool settle = true,
}) async {
  await tester.scrollUntilVisible(
    find.text(name),
    -120,
    scrollable: scrollableFinder(),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Finder removeActionFor(StoryParticipant participant) {
  return find.byKey(ValueKey('participants.remove-action.${participant.userId}'));
}

Finder leaveActionFinder() {
  return find.byKey(const ValueKey('participants.leave-action'));
}

Finder scrollableFinder() {
  return find.byType(Scrollable);
}

List<StoryParticipant> participantsWithCurrentRole(StoryRole role) {
  return <StoryParticipant>[
    StoryParticipant(
      userId: 'current-user-id',
      displayName: 'Current user',
      avatarUrl: null,
      role: role,
      joinedAt: DateTime.utc(2026, 8, 9, 10),
    ),
    viewerParticipant,
  ];
}

const String defaultStoryId = 'story-id';

final StoryParticipant ownerParticipant = StoryParticipant(
  userId: 'owner-user-id',
  displayName: 'Anna',
  avatarUrl: 'https://cdn.memorymap.app/anna.png',
  role: StoryRole.owner,
  joinedAt: DateTime.utc(2026, 8, 9, 10),
);

final StoryParticipant coOwnerParticipant = StoryParticipant(
  userId: 'co-owner-user-id',
  displayName: 'Oleg',
  avatarUrl: null,
  role: StoryRole.coOwner,
  joinedAt: DateTime.utc(2026, 8, 9, 11),
);

final StoryParticipant editorParticipant = StoryParticipant(
  userId: 'editor-user-id',
  displayName: 'Mira',
  avatarUrl: 'https://cdn.memorymap.app/mira.png',
  role: StoryRole.editor,
  joinedAt: DateTime.utc(2026, 8, 9, 12),
);

final StoryParticipant viewerParticipant = StoryParticipant(
  userId: 'viewer-user-id',
  displayName: 'Alex',
  avatarUrl: null,
  role: StoryRole.viewer,
  joinedAt: DateTime.utc(2026, 8, 9, 13),
);

final StoryParticipant sameNameCurrentUser = StoryParticipant(
  userId: 'current-user-id',
  displayName: 'Sam',
  avatarUrl: null,
  role: StoryRole.editor,
  joinedAt: DateTime.utc(2026, 8, 9, 14),
);

final StoryParticipant sameNameOtherUser = StoryParticipant(
  userId: 'other-user-id',
  displayName: 'Sam',
  avatarUrl: null,
  role: StoryRole.viewer,
  joinedAt: DateTime.utc(2026, 8, 9, 15),
);

final StoryParticipant longNameOwnerParticipant = StoryParticipant(
  userId: 'long-owner-user-id',
  displayName: 'Alexandria Catherine Very Long Participant Name',
  avatarUrl: null,
  role: StoryRole.owner,
  joinedAt: DateTime.utc(2026, 8, 9, 16),
);

final StoryParticipant longNameViewerParticipant = StoryParticipant(
  userId: 'long-viewer-user-id',
  displayName: 'Maximilian Christopher Another Very Long Participant Name',
  avatarUrl: null,
  role: StoryRole.viewer,
  joinedAt: DateTime.utc(2026, 8, 9, 17),
);

final StoryParticipant privateParticipant = StoryParticipant(
  userId: 'private-user-id',
  displayName: 'Private Person',
  avatarUrl: 'https://cdn.memorymap.app/private.png',
  role: StoryRole.owner,
  joinedAt: DateTime.utc(2026, 8, 9, 18),
);

final class FakeStoryParticipantRepository
    implements StoryParticipantRepository {
  int getCalls = 0;
  int leaveCalls = 0;
  int removeCalls = 0;
  String? receivedGetStoryId;
  LeaveStoryInput? receivedLeaveInput;
  RemoveStoryParticipantInput? receivedRemoveInput;
  List<StoryParticipant> participantsResult = <StoryParticipant>[
    ownerParticipant,
    coOwnerParticipant,
    editorParticipant,
    viewerParticipant,
  ];
  final List<Object> getFailures = <Object>[];
  Object? leaveFailure;
  Object? removeFailure;
  Completer<List<StoryParticipant>>? getCompleter;
  Completer<void>? leaveCompleter;
  Completer<void>? removeCompleter;

  @override
  Future<List<StoryParticipant>> getParticipants(String storyId) async {
    getCalls += 1;
    receivedGetStoryId = storyId;

    final completer = getCompleter;
    if (completer != null) {
      getCompleter = null;
      return completer.future;
    }

    if (getFailures.isNotEmpty) {
      throw getFailures.removeAt(0);
    }

    return participantsResult;
  }

  @override
  Future<void> leaveStory(LeaveStoryInput input) async {
    leaveCalls += 1;
    receivedLeaveInput = input;

    final completer = leaveCompleter;
    if (completer != null) {
      leaveCompleter = null;
      return completer.future;
    }

    final configuredFailure = leaveFailure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }
  }

  @override
  Future<void> removeParticipant(RemoveStoryParticipantInput input) async {
    removeCalls += 1;
    receivedRemoveInput = input;

    final completer = removeCompleter;
    if (completer != null) {
      removeCompleter = null;
      return completer.future;
    }

    final configuredFailure = removeFailure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }
  }
}

final class UnexpectedParticipantException implements Exception {
  const UnexpectedParticipantException();
}
