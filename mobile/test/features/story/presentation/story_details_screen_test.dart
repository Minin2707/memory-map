import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/features/story/presentation/story_details_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('StoryDetailsScreen rendering', () {
    testWidgets('shouldRenderEnglishStoryDetails', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, FakeStoryRepository()..storyResult = ownerStory);

      expect(find.text('Story'), findsOneWidget);
      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(find.text(ownerStory.story.description!), findsWidgets);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('About this story'), findsOneWidget);
      expect(find.text('Story info'), findsOneWidget);
      expect(find.text('Created'), findsOneWidget);
      expect(find.text('Updated'), findsOneWidget);
    });

    testWidgets('shouldRenderRussianStoryDetails', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        locale: const Locale('ru'),
      );

      expect(find.text('История'), findsOneWidget);
      expect(find.text('Об этой истории'), findsOneWidget);
      expect(find.text('Информация об истории'), findsOneWidget);
      expect(find.text('Владелец'), findsOneWidget);
    });

    testWidgets('shouldRenderNoDescriptionPlaceholder', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = storyWithoutDescription,
      );

      expect(find.text('No description yet.'), findsOneWidget);
    });

    testWidgets('shouldRenderNoDescriptionForBlankDescription', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()
          ..storyResult = userStory(description: '   '),
      );

      expect(find.text('No description yet.'), findsOneWidget);
      expect(find.text('   '), findsNothing);
    });

    testWidgets('shouldRenderAllRoleBadges', (WidgetTester tester) async {
      for (final role in StoryRole.values) {
        await pumpScreen(
          tester,
          FakeStoryRepository()..storyResult = userStory(role: role),
        );

        expect(find.text(roleLabel(role)), findsOneWidget);
      }
    });
  });

  group('StoryDetailsScreen edit and callbacks', () {
    testWidgets('shouldShowEditForOwnerAndPassExactUserStory', (
      WidgetTester tester,
    ) async {
      UserStory? editedStory;
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        onEditStory: (userStory) {
          editedStory = userStory;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-details.edit-action')),
      );

      expect(editedStory, ownerStory);
    });

    testWidgets('shouldShowEditForCoOwner', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = coOwnerStory,
        onEditStory: (_) {},
      );

      expect(
        find.byKey(const ValueKey('story-details.edit-action')),
        findsOneWidget,
      );
    });

    testWidgets('shouldHideEditForEditorAndViewer', (
      WidgetTester tester,
    ) async {
      for (final role in <StoryRole>[StoryRole.editor, StoryRole.viewer]) {
        await pumpScreen(
          tester,
          FakeStoryRepository()..storyResult = userStory(role: role),
          onEditStory: (_) {},
        );

        expect(
          find.byKey(const ValueKey('story-details.edit-action')),
          findsNothing,
        );
      }
    });

    testWidgets('shouldCallBackCallbackFromAppBarAndSystemBack', (
      WidgetTester tester,
    ) async {
      var backCalls = 0;
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        onBack: () {
          backCalls += 1;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-details.back-action')),
      );
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(backCalls, 2);
    });

    testWidgets('shouldRenderFutureSectionsOnlyWhenCallbacksExist', (
      WidgetTester tester,
    ) async {
      setSurface(tester, const Size(390, 1200));
      UserStory? memoriesStory;
      UserStory? participantsStory;
      UserStory? mapStory;
      var inviteCalls = 0;
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        onInvite: () {
          inviteCalls += 1;
        },
        onMemoriesSelected: (userStory) {
          memoriesStory = userStory;
        },
        onParticipantsSelected: (userStory) {
          participantsStory = userStory;
        },
        onMapSelected: (userStory) {
          mapStory = userStory;
        },
      );

      expect(find.text('Explore'), findsOneWidget);
      await pressButton(
        tester,
        find.byKey(const ValueKey('story-details.memories-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('story-details.participants-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('story-details.invite-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('story-details.map-action')),
      );

      expect(memoriesStory, ownerStory);
      expect(participantsStory, ownerStory);
      expect(mapStory, ownerStory);
      expect(inviteCalls, 1);
    });

    testWidgets('shouldShowInviteForOwnerAndCoOwner', (
      WidgetTester tester,
    ) async {
      for (final role in <StoryRole>[StoryRole.owner, StoryRole.coOwner]) {
        await pumpScreen(
          tester,
          FakeStoryRepository()..storyResult = userStory(role: role),
          onInvite: () {},
        );

        expect(
          find.byKey(const ValueKey('story-details.invite-action')),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Invite participant'), findsOneWidget);
      }
    });

    testWidgets('shouldShowParticipantsForEveryRoleWhenCallbackExists', (
      WidgetTester tester,
    ) async {
      setSurface(tester, const Size(390, 1200));

      for (final role in StoryRole.values) {
        UserStory? selectedStory;
        final story = userStory(role: role);
        await pumpScreen(
          tester,
          FakeStoryRepository()..storyResult = story,
          onParticipantsSelected: (userStory) {
            selectedStory = userStory;
          },
        );

        final action =
            find.byKey(const ValueKey('story-details.participants-action'));
        expect(action, findsOneWidget);
        expect(find.text('Participants'), findsOneWidget);

        await pressButton(tester, action);

        expect(selectedStory, story);
        expect(find.textContaining(story.story.id), findsNothing);
      }
    });

    testWidgets('shouldHideInviteForEditorAndViewer', (
      WidgetTester tester,
    ) async {
      for (final role in <StoryRole>[StoryRole.editor, StoryRole.viewer]) {
        await pumpScreen(
          tester,
          FakeStoryRepository()..storyResult = userStory(role: role),
          onInvite: () {},
        );

        expect(
          find.byKey(const ValueKey('story-details.invite-action')),
          findsNothing,
        );
      }
    });

    testWidgets('shouldHideFutureSectionsWhenCallbacksAreAbsent', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, FakeStoryRepository()..storyResult = ownerStory);

      expect(find.text('Memories'), findsNothing);
      expect(find.text('Participants'), findsNothing);
      expect(find.text('Map'), findsNothing);
    });
  });

  group('StoryDetailsScreen loading and failures', () {
    testWidgets('shouldRenderLoadingStructureSafely', (
      WidgetTester tester,
    ) async {
      final completer = Completer<UserStory>();
      final repository = FakeStoryRepository()..getStoryCompleter = completer;

      await pumpScreen(tester, repository, settle: false);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('story-details.loading-view')),
        findsOneWidget,
      );
      expect(find.text(ownerStory.story.title), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);

      completer.complete(ownerStory);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRenderKnownFailureSafelyAndRetry', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..getStoryFailures.add(
          const StoryApplicationException(StoryNetworkUnavailable()),
        )
        ..storyResult = ownerStory;
      await pumpScreen(tester, repository);

      expect(find.text('Could not load story'), findsOneWidget);
      expect(
        find.text('No network connection. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('StoryApplicationException'), findsNothing);

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-details.error.retry-action')),
      );

      expect(repository.getStoryCalls, 2);
      expect(find.text(ownerStory.story.title), findsOneWidget);
    });

    testWidgets('shouldRenderNotFoundAsSafeFailure', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..getStoryFailures.add(
          const StoryApplicationException(StoryNotFound()),
        );
      await pumpScreen(tester, repository);

      expect(find.text('Story is unavailable.'), findsOneWidget);
      expect(find.textContaining('not authorized'), findsNothing);
      expect(find.textContaining('private-story-id'), findsNothing);
    });

    testWidgets('shouldRenderUnexpectedFailureSafely', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..getStoryFailures.add(const UnexpectedStoryException());
      await pumpScreen(tester, repository);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('UnexpectedStoryException'), findsNothing);
      expect(find.textContaining('StackTrace'), findsNothing);
    });
  });

  group('StoryDetailsScreen refresh', () {
    testWidgets('shouldKeepLoadedContentWhileRefreshing', (
      WidgetTester tester,
    ) async {
      final completer = Completer<UserStory>();
      final repository = FakeStoryRepository()..storyResult = ownerStory;
      final container = await pumpScreen(tester, repository);
      repository.getStoryCompleter = completer;

      final refresh = container
          .read(storyDetailsProvider('story-1').notifier)
          .refreshStory();
      await tester.pump();

      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      completer.complete(updatedOwnerStory);
      await refresh;
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRenderRefreshFailureBannerAndRetry', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()..storyResult = ownerStory;
      await pumpScreen(tester, repository);
      repository.getStoryFailures.add(
        const StoryApplicationException(StoryRequestTimedOut()),
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 360));
      await tester.pumpAndSettle();

      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-details.refresh.failure-banner')),
        findsOneWidget,
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-details.refresh.retry-action')),
      );

      expect(repository.getStoryCalls, 3);
    });
  });

  group('StoryDetailsScreen responsiveness and security', () {
    testWidgets('shouldNotOverflowWithLongContentAndLargeTextScale', (
      WidgetTester tester,
    ) async {
      setSurface(tester, const Size(360, 640));

      await pumpScreen(
        tester,
        FakeStoryRepository()
          ..storyResult = userStory(
            id: 'private-story-id',
            title: 'A very long story title that should wrap gracefully',
            description:
                'A long description that should remain readable on a narrow '
                'phone with larger text scale and without layout overflow.',
          ),
        textScaler: const TextScaler.linear(1.25),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('shouldNotRenderUnsupportedBackendFieldsOrSecrets', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()
          ..storyResult = userStory(
            id: 'private-story-id',
            title: 'Private visible title',
            description: 'Visible description',
          ),
      );

      expect(find.textContaining('private-story-id'), findsNothing);
      expect(find.textContaining('24 memories'), findsNothing);
      expect(find.textContaining('2 participants'), findsNothing);
      expect(find.textContaining('cover'), findsNothing);
      expect(find.textContaining('ownerId'), findsNothing);
      expect(find.textContaining('userId'), findsNothing);
      expect(find.textContaining('accessToken'), findsNothing);
      expect(find.textContaining('refreshToken'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
      expect(find.textContaining('raw response'), findsNothing);
    });
  });
}

Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  FakeStoryRepository repository, {
  Locale locale = const Locale('en'),
  String storyId = 'story-1',
  VoidCallback? onBack,
  ValueChanged<UserStory>? onEditStory,
  VoidCallback? onInvite,
  ValueChanged<UserStory>? onMemoriesSelected,
  ValueChanged<UserStory>? onParticipantsSelected,
  ValueChanged<UserStory>? onMapSelected,
  TextScaler textScaler = TextScaler.noScaling,
  bool settle = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      storyRepositoryProvider.overrideWithValue(repository),
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
        home: StoryDetailsScreen(
          storyId: storyId,
          onBack: onBack,
          onEditStory: onEditStory,
          onInvite: onInvite,
          onMemoriesSelected: onMemoriesSelected,
          onParticipantsSelected: onParticipantsSelected,
          onMapSelected: onMapSelected,
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

void setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

String roleLabel(StoryRole role) {
  return switch (role) {
    StoryRole.owner => 'Owner',
    StoryRole.coOwner => 'Co-owner',
    StoryRole.editor => 'Editor',
    StoryRole.viewer => 'Viewer',
  };
}

UserStory userStory({
  String id = 'story-1',
  String title = 'First story',
  String? description = 'First description',
  StoryRole role = StoryRole.owner,
}) {
  return UserStory(
    story: Story(
      id: id,
      title: title,
      description: description,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    ),
    role: role,
  );
}

final UserStory ownerStory = userStory(
  id: 'story-owner',
  title: 'Our story',
  description: 'Together since 2021',
  role: StoryRole.owner,
);
final UserStory coOwnerStory = userStory(
  id: 'story-co-owner',
  title: 'Our travels',
  description: 'Adventures around the world',
  role: StoryRole.coOwner,
);
final UserStory updatedOwnerStory = userStory(
  id: ownerStory.story.id,
  title: 'Updated story',
  description: 'Updated description',
  role: StoryRole.owner,
);
final UserStory storyWithoutDescription = userStory(
  id: 'story-no-description',
  title: 'Quiet archive',
  description: null,
  role: StoryRole.viewer,
);

final class FakeStoryRepository implements StoryRepository {
  int createCalls = 0;
  int getStoriesCalls = 0;
  int getStoryCalls = 0;
  int updateStoryCalls = 0;

  UserStory storyResult = ownerStory;
  final List<Object> getStoryFailures = <Object>[];
  Completer<UserStory>? getStoryCompleter;

  @override
  Future<Story> createStory({
    required String title,
    String? description,
  }) async {
    createCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<UserStory> getStory(String storyId) async {
    getStoryCalls += 1;

    final completer = getStoryCompleter;
    if (completer != null) {
      getStoryCompleter = null;
      return completer.future;
    }

    if (getStoryFailures.isNotEmpty) {
      throw getStoryFailures.removeAt(0);
    }

    return storyResult;
  }

  @override
  Future<List<UserStory>> getStories() async {
    getStoriesCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<UserStory> updateStory(UpdateStoryInput input) async {
    updateStoryCalls += 1;
    throw UnimplementedError();
  }
}

final class UnexpectedStoryException implements Exception {
  const UnexpectedStoryException();
}
