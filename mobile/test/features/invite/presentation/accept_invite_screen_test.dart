import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/invite/application/accept_invite_notifier.dart';
import 'package:memory_map/features/invite/application/invite_application_exception.dart';
import 'package:memory_map/features/invite/application/invite_application_providers.dart';
import 'package:memory_map/features/invite/domain/accept_invite_input.dart';
import 'package:memory_map/features/invite/domain/create_invite_input.dart';
import 'package:memory_map/features/invite/domain/invite.dart';
import 'package:memory_map/features/invite/domain/invite_failure.dart';
import 'package:memory_map/features/invite/domain/invite_repository.dart';
import 'package:memory_map/features/invite/presentation/accept_invite_screen.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('AcceptInviteScreen rendering', () {
    testWidgets('shouldRenderGenericInvitationWithoutTokenOrStoryPreview', (
      WidgetTester tester,
    ) async {
      final repository = FakeInviteRepository();

      await pumpScreen(tester, repository);

      expect(find.text('Invitation'), findsOneWidget);
      expect(find.text('You were invited to a story'), findsOneWidget);
      expect(find.text('Accept invite'), findsOneWidget);
      expect(find.textContaining(rawToken), findsNothing);
      expect(find.textContaining(userStoryFixture.story.title), findsNothing);
      expect(find.textContaining(userStoryFixture.story.description!), findsNothing);
      expect(repository.acceptCalls, 0);
      expect(repository.createCalls, 0);
    });

    testWidgets('shouldRenderInvalidLinkWithoutAcceptAction', (
      WidgetTester tester,
    ) async {
      final repository = FakeInviteRepository();

      await pumpScreen(tester, repository, invalid: true);

      expect(find.text('Invite link is unavailable'), findsOneWidget);
      expect(find.text('This invitation cannot be opened.'), findsWidgets);
      expect(
        find.byKey(const ValueKey('accept-invite.accept-action')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('accept-invite.back-to-stories-action')),
        findsOneWidget,
      );
      expect(repository.acceptCalls, 0);
    });
  });

  group('AcceptInviteScreen accept flow', () {
    testWidgets('shouldAcceptInviteAndCallSuccessWithExactUserStory', (
      WidgetTester tester,
    ) async {
      final repository = FakeInviteRepository();
      UserStory? acceptedStory;

      await pumpScreen(
        tester,
        repository,
        onAccepted: (userStory) {
          acceptedStory = userStory;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('accept-invite.accept-action')),
      );

      expect(repository.acceptCalls, 1);
      expect(repository.createCalls, 0);
      expect(
        repository.receivedAcceptInput,
        AcceptInviteInput(rawToken: rawToken),
      );
      expect(acceptedStory, userStoryFixture);
    });

    testWidgets('shouldShowLoadingAndBlockDuplicateAccept', (
      WidgetTester tester,
    ) async {
      final completer = Completer<UserStory>();
      final repository = FakeInviteRepository()
        ..acceptCompleter = completer;

      await pumpScreen(tester, repository);

      await pressButton(
        tester,
        find.byKey(const ValueKey('accept-invite.accept-action')),
        settle: false,
      );
      await tester.pump();
      await pressButton(
        tester,
        find.byKey(const ValueKey('accept-invite.accept-action')),
        settle: false,
      );

      expect(find.text('Accepting invite...'), findsOneWidget);
      expect(repository.acceptCalls, 1);

      completer.complete(userStoryFixture);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRenderKnownFailuresSafelyAndAllowRetry', (
      WidgetTester tester,
    ) async {
      final repository = FakeInviteRepository()
        ..acceptFailure = const InviteApplicationException(InviteNotFound());

      await pumpScreen(tester, repository);

      await pressButton(
        tester,
        find.byKey(const ValueKey('accept-invite.accept-action')),
      );

      expect(find.text('This invitation cannot be accepted.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining(rawToken), findsNothing);
      expect(find.textContaining('InviteNotFound'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
      expect(find.textContaining('HTTP'), findsNothing);

      repository.acceptFailure = null;
      await pressButton(
        tester,
        find.byKey(const ValueKey('accept-invite.accept-action')),
      );

      expect(repository.acceptCalls, 2);
      expect(find.textContaining(userStoryFixture.story.title), findsNothing);
    });

    testWidgets('shouldRenderUnexpectedFailureSafely', (
      WidgetTester tester,
    ) async {
      final repository = FakeInviteRepository()
        ..acceptFailure = const UnexpectedInviteException();

      await pumpScreen(tester, repository);

      await pressButton(
        tester,
        find.byKey(const ValueKey('accept-invite.accept-action')),
      );

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('UnexpectedInviteException'), findsNothing);
      expect(find.textContaining('StackTrace'), findsNothing);
      expect(find.textContaining(rawToken), findsNothing);
    });
  });

  group('AcceptInviteScreen cancellation', () {
    testWidgets('shouldCallCancelWhenIdle', (WidgetTester tester) async {
      var cancelCalls = 0;
      await pumpScreen(
        tester,
        FakeInviteRepository(),
        onCancel: () {
          cancelCalls += 1;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('accept-invite.cancel-action')),
      );

      expect(cancelCalls, 1);
    });

    testWidgets('shouldBlockCancelWhileAccepting', (WidgetTester tester) async {
      final completer = Completer<UserStory>();
      var cancelCalls = 0;
      final repository = FakeInviteRepository()
        ..acceptCompleter = completer;
      await pumpScreen(
        tester,
        repository,
        onCancel: () {
          cancelCalls += 1;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('accept-invite.accept-action')),
        settle: false,
      );
      await tester.pump();
      await pressButton(
        tester,
        find.byKey(const ValueKey('accept-invite.cancel-action')),
        settle: false,
      );

      expect(cancelCalls, 0);

      completer.complete(userStoryFixture);
      await tester.pumpAndSettle();
    });
  });
}

Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  FakeInviteRepository repository, {
  bool invalid = false,
  VoidCallback? onCancel,
  ValueChanged<UserStory>? onAccepted,
}) async {
  final container = ProviderContainer(
    overrides: [
      inviteRepositoryProvider.overrideWithValue(repository),
    ],
  );
  container.listen(acceptInviteProvider, (_, __) {}, fireImmediately: true);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: invalid
            ? AcceptInviteScreen.invalid(onCancel: onCancel)
            : AcceptInviteScreen(
                rawToken: rawToken,
                onCancel: onCancel,
                onAccepted: onAccepted,
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();

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

const rawToken = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

final Invite inviteFixture = Invite(
  inviteLink: Uri.parse('https://app.memorymap.app/invite/$rawToken'),
  expiresAt: DateTime.utc(2026, 2, 9, 10),
);

final UserStory userStoryFixture = UserStory(
  story: Story(
    id: 'accepted-story-id',
    title: 'Accepted story',
    description: 'Accepted description',
    createdAt: DateTime.utc(2026, 1, 1, 10),
    updatedAt: DateTime.utc(2026, 1, 10, 10),
  ),
  role: StoryRole.viewer,
);

final class FakeInviteRepository implements InviteRepository {
  int createCalls = 0;
  int acceptCalls = 0;
  CreateInviteInput? receivedCreateInput;
  AcceptInviteInput? receivedAcceptInput;
  Invite createResult = inviteFixture;
  UserStory acceptResult = userStoryFixture;
  Object? createFailure;
  Object? acceptFailure;
  Completer<UserStory>? acceptCompleter;

  @override
  Future<Invite> createInvite(CreateInviteInput input) async {
    createCalls += 1;
    receivedCreateInput = input;

    final failure = createFailure;
    if (failure != null) {
      throw failure;
    }

    return createResult;
  }

  @override
  Future<UserStory> acceptInvite(AcceptInviteInput input) async {
    acceptCalls += 1;
    receivedAcceptInput = input;

    final completer = acceptCompleter;
    if (completer != null) {
      acceptCompleter = null;
      return completer.future;
    }

    final failure = acceptFailure;
    if (failure != null) {
      throw failure;
    }

    return acceptResult;
  }
}

final class UnexpectedInviteException implements Exception {
  const UnexpectedInviteException();
}
