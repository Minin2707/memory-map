import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/invite/application/create_invite_notifier.dart';
import 'package:memory_map/features/invite/application/invite_application_exception.dart';
import 'package:memory_map/features/invite/application/invite_application_providers.dart';
import 'package:memory_map/features/invite/domain/accept_invite_input.dart';
import 'package:memory_map/features/invite/domain/create_invite_input.dart';
import 'package:memory_map/features/invite/domain/invite.dart';
import 'package:memory_map/features/invite/domain/invite_failure.dart';
import 'package:memory_map/features/invite/domain/invite_repository.dart';
import 'package:memory_map/features/invite/presentation/invite_clipboard.dart';
import 'package:memory_map/features/invite/presentation/invite_screen.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('InviteScreen rendering', () {
    testWidgets('shouldRenderEnglishInitialState', (
      WidgetTester tester,
    ) async {
      final repository = FakeInviteRepository();
      await pumpScreen(tester, repository);

      expect(find.text('Invite participant'), findsOneWidget);
      expect(find.text('Invite someone close'), findsOneWidget);
      expect(find.text('Invite link'), findsOneWidget);
      expect(find.text('Create invite'), findsOneWidget);
      expect(find.textContaining(inviteLink), findsNothing);
      expect(find.byKey(const ValueKey('invite.copy-action')), findsNothing);
      expect(find.byKey(const ValueKey('invite.share-action')), findsNothing);
      expect(repository.createCalls, 0);
      expect(repository.acceptCalls, 0);
    });

    testWidgets('shouldRenderRussianInitialState', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeInviteRepository(),
        locale: const Locale('ru'),
      );

      expect(find.text('Пригласить участника'), findsOneWidget);
      expect(find.text('Пригласите близкого человека'), findsOneWidget);
      expect(find.text('Создать приглашение'), findsOneWidget);
    });
  });

  group('InviteScreen create flow', () {
    testWidgets('shouldCreateInviteAndRenderSuccessResult', (
      WidgetTester tester,
    ) async {
      final repository = FakeInviteRepository();
      await pumpScreen(tester, repository);

      await pressButton(
        tester,
        find.byKey(const ValueKey('invite.create-action')),
      );

      expect(repository.createCalls, 1);
      expect(
        repository.receivedCreateInput,
        CreateInviteInput(storyId: defaultStoryId),
      );
      expect(find.text('Invite created'), findsOneWidget);
      expect(find.text('Invite is ready!'), findsOneWidget);
      expect(find.text(inviteLink), findsOneWidget);
      expect(find.text('Feb 9, 2026, 10:00'), findsOneWidget);
      expect(find.byKey(const ValueKey('invite.copy-action')), findsOneWidget);
      expect(find.byKey(const ValueKey('invite.share-action')), findsNothing);
      expect(
        find.text(
          'Copy or share this link before leaving this screen. '
          'It cannot be shown again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shouldShowLoadingAndPreventDuplicateCreate', (
      WidgetTester tester,
    ) async {
      final completer = Completer<Invite>();
      final repository = FakeInviteRepository()
        ..createCompleter = completer;
      await pumpScreen(tester, repository);

      await pressButton(
        tester,
        find.byKey(const ValueKey('invite.create-action')),
        settle: false,
      );
      await tester.pump();
      await pressButton(
        tester,
        find.byKey(const ValueKey('invite.create-action')),
        settle: false,
      );

      expect(find.text('Creating invite...'), findsOneWidget);
      expect(repository.createCalls, 1);

      completer.complete(inviteFixture);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRenderKnownFailuresSafely', (
      WidgetTester tester,
    ) async {
      final cases = <InviteFailure, String>{
        const InviteValidationFailure():
            'The invite request was invalid. Please try again.',
        const InviteUnauthorized():
            'Your session needs attention. Please try again.',
        const InviteNotFound(): 'This story is unavailable for invites.',
        const InviteNetworkUnavailable():
            'No network connection. Check your connection and try again.',
        const InviteRequestTimedOut():
            'The request timed out. Please try again.',
        const InviteServerFailure():
            'The server is temporarily unavailable. Please try again.',
        const UnknownInviteFailure(): 'Something went wrong. Please try again.',
      };

      for (final entry in cases.entries) {
        final repository = FakeInviteRepository()
          ..createFailure = InviteApplicationException(entry.key);
        await pumpScreen(tester, repository);

        await pressButton(
          tester,
          find.byKey(const ValueKey('invite.create-action')),
        );

        expect(find.text(entry.value), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
        expect(find.textContaining(inviteLink), findsNothing);
        expect(find.textContaining('InviteApplicationException'), findsNothing);
        expect(find.textContaining('Dio'), findsNothing);
        expect(find.textContaining('HTTP'), findsNothing);
        expect(find.textContaining('SQL'), findsNothing);
      }
    });

    testWidgets('shouldRenderUnexpectedFailureSafely', (
      WidgetTester tester,
    ) async {
      final repository = FakeInviteRepository()
        ..createFailure = const UnexpectedInviteException();
      await pumpScreen(tester, repository);

      await pressButton(
        tester,
        find.byKey(const ValueKey('invite.create-action')),
      );

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('UnexpectedInviteException'), findsNothing);
      expect(find.textContaining('StackTrace'), findsNothing);
      expect(find.textContaining(inviteLink), findsNothing);

      repository.createFailure = null;
      await pressButton(
        tester,
        find.byKey(const ValueKey('invite.create-action')),
      );

      expect(repository.createCalls, 2);
      expect(find.text(inviteLink), findsOneWidget);
    });
  });

  group('InviteScreen copy and share', () {
    testWidgets('shouldCopyExactInviteLinkAndShowSafeFeedback', (
      WidgetTester tester,
    ) async {
      final clipboard = FakeInviteClipboard();
      await pumpScreen(
        tester,
        FakeInviteRepository(),
        clipboard: clipboard,
      );
      await createInvite(tester);

      await pressButton(
        tester,
        find.byKey(const ValueKey('invite.copy-action')),
      );

      expect(clipboard.writes, <String>[inviteLink]);
      expect(find.text('Invite link copied.'), findsOneWidget);
      expect(find.text(inviteLink), findsOneWidget);
    });

    testWidgets('shouldHandleCopyFailureSafelyAndKeepResultVisible', (
      WidgetTester tester,
    ) async {
      final clipboard = FakeInviteClipboard()
        ..failure = const UnexpectedInviteException();
      await pumpScreen(
        tester,
        FakeInviteRepository(),
        clipboard: clipboard,
      );
      await createInvite(tester);

      await pressButton(
        tester,
        find.byKey(const ValueKey('invite.copy-action')),
      );

      expect(find.text('Could not copy the invite link.'), findsOneWidget);
      expect(find.text(inviteLink), findsOneWidget);
      expect(find.textContaining('UnexpectedInviteException'), findsNothing);
    });

    testWidgets('shouldShareExactInviteLinkWhenCallbackExists', (
      WidgetTester tester,
    ) async {
      final sharedLinks = <String>[];
      await pumpScreen(
        tester,
        FakeInviteRepository(),
        onShareInvite: sharedLinks.add,
      );
      await createInvite(tester);

      expect(find.byKey(const ValueKey('invite.share-action')), findsOneWidget);
      await pressButton(
        tester,
        find.byKey(const ValueKey('invite.share-action')),
      );

      expect(sharedLinks, <String>[inviteLink]);
      expect(find.text('Share options opened.'), findsOneWidget);
    });

    testWidgets('shouldHandleShareFailureSafelyAndKeepResultVisible', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeInviteRepository(),
        onShareInvite: (_) {
          throw const UnexpectedInviteException();
        },
      );
      await createInvite(tester);

      await pressButton(
        tester,
        find.byKey(const ValueKey('invite.share-action')),
      );

      expect(find.text('Could not share the invite link.'), findsOneWidget);
      expect(find.text(inviteLink), findsOneWidget);
      expect(find.textContaining('UnexpectedInviteException'), findsNothing);
    });
  });

  group('InviteScreen back and responsiveness', () {
    testWidgets('shouldCallBackWhenIdleSuccessAndFailure', (
      WidgetTester tester,
    ) async {
      var backCalls = 0;
      await pumpScreen(
        tester,
        FakeInviteRepository(),
        onBack: () {
          backCalls += 1;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('invite.back-action')),
      );

      final successRepository = FakeInviteRepository();
      await pumpScreen(
        tester,
        successRepository,
        onBack: () {
          backCalls += 1;
        },
      );
      await createInvite(tester);
      await pressButton(
        tester,
        find.byKey(const ValueKey('invite.done-action')),
      );

      final failureRepository = FakeInviteRepository()
        ..createFailure =
            const InviteApplicationException(InviteNetworkUnavailable());
      await pumpScreen(
        tester,
        failureRepository,
        onBack: () {
          backCalls += 1;
        },
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('invite.create-action')),
      );
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(backCalls, 3);
    });

    testWidgets('shouldBlockBackWhileCreating', (
      WidgetTester tester,
    ) async {
      final completer = Completer<Invite>();
      var backCalls = 0;
      final repository = FakeInviteRepository()
        ..createCompleter = completer;
      await pumpScreen(
        tester,
        repository,
        onBack: () {
          backCalls += 1;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('invite.create-action')),
        settle: false,
      );
      await tester.pump();
      await pressButton(
        tester,
        find.byKey(const ValueKey('invite.back-action')),
        settle: false,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(backCalls, 0);

      completer.complete(inviteFixture);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldNotOverflowOnSmallPhoneWithLargeText', (
      WidgetTester tester,
    ) async {
      setSurface(tester, const Size(360, 640));

      await pumpScreen(
        tester,
        FakeInviteRepository(),
        textScaler: const TextScaler.linear(1.3),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('shouldNotExposeSecretsBeforeSuccessOrInFailures', (
      WidgetTester tester,
    ) async {
      final repository = FakeInviteRepository()
        ..createFailure =
            const InviteApplicationException(InviteNetworkUnavailable());
      await pumpScreen(tester, repository, storyId: 'private-story-id');

      expect(find.textContaining('private-story-id'), findsNothing);
      expect(find.textContaining(inviteLink), findsNothing);
      expect(find.textContaining('accessToken'), findsNothing);
      expect(find.textContaining('refreshToken'), findsNothing);
      expect(find.textContaining('tokenHash'), findsNothing);

      await pressButton(
        tester,
        find.byKey(const ValueKey('invite.create-action')),
      );

      expect(find.textContaining('private-story-id'), findsNothing);
      expect(find.textContaining(inviteLink), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
      expect(find.textContaining('HTTP'), findsNothing);
      expect(find.textContaining('SQL'), findsNothing);
      expect(find.textContaining('stack'), findsNothing);
    });
  });
}

Future<void> createInvite(WidgetTester tester) async {
  await pressButton(tester, find.byKey(const ValueKey('invite.create-action')));
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

Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  FakeInviteRepository repository, {
  String storyId = defaultStoryId,
  Locale locale = const Locale('en'),
  VoidCallback? onBack,
  InviteShareCallback? onShareInvite,
  InviteClipboard clipboard = const FlutterInviteClipboard(),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final container = ProviderContainer(
    overrides: [
      inviteRepositoryProvider.overrideWithValue(repository),
    ],
  );
  container.listen(createInviteProvider, (_, __) {}, fireImmediately: true);
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
        home: InviteScreen(
          storyId: storyId,
          onBack: onBack,
          onShareInvite: onShareInvite,
          clipboard: clipboard,
          dateFormatter: (_, __) => 'Feb 9, 2026, 10:00',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return container;
}

void setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

const String defaultStoryId = 'story-id';
const String inviteLink = 'https://memorymap.app/invite/share-token-123';

final Invite inviteFixture = Invite(
  inviteLink: Uri.parse(inviteLink),
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
  role: StoryRole.editor,
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
  Completer<Invite>? createCompleter;

  @override
  Future<Invite> createInvite(CreateInviteInput input) async {
    createCalls += 1;
    receivedCreateInput = input;

    final completer = createCompleter;
    if (completer != null) {
      createCompleter = null;
      return completer.future;
    }

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

    final failure = acceptFailure;
    if (failure != null) {
      throw failure;
    }

    return acceptResult;
  }
}

final class FakeInviteClipboard implements InviteClipboard {
  final List<String> writes = <String>[];
  Object? failure;

  @override
  Future<void> writeText(String text) async {
    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }

    writes.add(text);
  }
}

final class UnexpectedInviteException implements Exception {
  const UnexpectedInviteException();
}
