import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/notification/application/notification_application_providers.dart';
import 'package:memory_map/features/notification/domain/notification_item.dart';
import 'package:memory_map/features/notification/domain/notification_repository.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/story_photo_preview.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/features/story/presentation/stories_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

import '../../media/media_test_fixtures.dart' as media_fixtures;

void main() {
  group('StoriesScreen header', () {
    testWidgets('shouldRenderEnglishHeader', (WidgetTester tester) async {
      await pumpScreen(tester, FakeStoryRepository());

      expect(find.text('Hi, Anna! 👋'), findsOneWidget);
      expect(find.text('Your shared memories live here'), findsOneWidget);
      expect(find.text('Your stories'), findsOneWidget);
    });

    testWidgets('shouldUseFirstDisplayNameTokenForFriendlyGreeting', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository(),
        displayName: 'Anna Petrova',
      );

      expect(find.text('Hi, Anna! 👋'), findsOneWidget);
      expect(find.textContaining('Anna Petrova!'), findsNothing);
    });

    testWidgets('shouldRenderRussianHeader', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        FakeStoryRepository(),
        locale: const Locale('ru'),
      );

      expect(find.text('Привет, Anna! 👋'), findsOneWidget);
      expect(
        find.text('Здесь живут ваши совместные воспоминания'),
        findsOneWidget,
      );
      expect(find.text('Ваши истории'), findsOneWidget);
    });

    testWidgets('shouldUseAvatarNetworkImageWhenProvided', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository(),
        avatarUrl: 'https://example.com/avatar.png',
      );

      final avatar = tester.widget<CircleAvatar>(
        find.descendant(
          of: find.byKey(const ValueKey('stories.header.avatar')),
          matching: find.byType(CircleAvatar),
        ),
      );

      expect(avatar.foregroundImage, isA<NetworkImage>());
      expect(
        (avatar.foregroundImage as NetworkImage).url,
        'https://example.com/avatar.png',
      );
    });

    testWidgets('shouldRenderAvatarFallbackWhenUrlIsAbsent', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, FakeStoryRepository(), avatarUrl: null);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('stories.header.avatar')),
          matching: find.text('A'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shouldCallProfileCallbackFromAvatar', (
      WidgetTester tester,
    ) async {
      var profileCalls = 0;
      await pumpScreen(
        tester,
        FakeStoryRepository(),
        onProfileSelected: () {
          profileCalls += 1;
        },
      );

      await tester.tap(
        find.byKey(const ValueKey('stories.header.profile-action')),
      );
      await tester.pump();

      expect(profileCalls, 1);
    });

    testWidgets('shouldCallNotificationCallbackFromBell', (
      WidgetTester tester,
    ) async {
      var notificationCalls = 0;
      await pumpScreen(
        tester,
        FakeStoryRepository(),
        onNotificationsSelected: () {
          notificationCalls += 1;
        },
      );

      await tester.tap(
        find.byKey(const ValueKey('stories.notification.action')),
      );
      await tester.pump();

      expect(notificationCalls, 1);
    });

    testWidgets('shouldRenderUnreadNotificationBadge', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository(),
        notificationRepository: FakeNotificationRepository()..unreadCount = 2,
      );

      expect(find.byKey(const ValueKey('stories.notification.badge')),
          findsOneWidget);
    });

    testWidgets('shouldHideNotificationBadgeWhenUnreadCountIsZero', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, FakeStoryRepository());

      expect(find.byKey(const ValueKey('stories.notification.badge')),
          findsNothing);
    });
  });

  group('StoriesScreen loading and failures', () {
    testWidgets('shouldRenderLoadingWithoutEmptyTextOrRawError', (
      WidgetTester tester,
    ) async {
      final completer = Completer<List<UserStory>>();
      final repository = FakeStoryRepository()
        ..getStoriesCompleter = completer;

      await pumpScreen(tester, repository, settle: false);
      await tester.pump();

      expect(find.byKey(const ValueKey('stories.loading.view')), findsOneWidget);
      expect(find.text('No stories yet'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);

      completer.complete(<UserStory>[]);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRenderKnownLoadFailureSafelyAndRetry', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..getStoriesFailures.add(
          const StoryApplicationException(StoryNetworkUnavailable()),
        )
        ..storiesResult = <UserStory>[ownerStory];
      await pumpScreen(tester, repository);

      expect(find.text('Could not load stories'), findsOneWidget);
      expect(
        find.text('No network connection. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('StoryApplicationException'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('stories.error.retry-action')));
      await tester.pumpAndSettle();

      expect(repository.getStoriesCalls, 2);
      expect(find.text(ownerStory.story.title), findsOneWidget);
    });

    testWidgets('shouldRenderAsyncErrorAsSafeUnknownFailure', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..getStoriesFailures.add(const UnexpectedStoryException());
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

  group('StoriesScreen loaded list', () {
    testWidgets('shouldRenderStoriesInExactOrder', (
      WidgetTester tester,
    ) async {
      setSurface(tester, const Size(390, 1200));
      await pumpScreen(
        tester,
        FakeStoryRepository()
          ..storiesResult = <UserStory>[
            ownerStory,
            coOwnerStory,
            editorStory,
            viewerStory,
          ],
      );

      final ownerTop = tester.getTopLeft(find.text(ownerStory.story.title));
      final coOwnerTop = tester.getTopLeft(find.text(coOwnerStory.story.title));
      final editorTop = tester.getTopLeft(find.text(editorStory.story.title));

      expect(ownerTop.dy, lessThan(coOwnerTop.dy));
      expect(coOwnerTop.dy, lessThan(editorTop.dy));
    });

    testWidgets('shouldRenderTitleDescriptionAndAllRoles', (
      WidgetTester tester,
    ) async {
      setSurface(tester, const Size(390, 1200));
      await pumpScreen(
        tester,
        FakeStoryRepository()
          ..storiesResult = <UserStory>[
            ownerStory,
            coOwnerStory,
            editorStory,
            viewerStory,
            storyWithoutDescription,
          ],
      );

      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(find.text(ownerStory.story.description!), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Co-owner'), findsOneWidget);
      expect(find.text('Editor'), findsOneWidget);
      expect(find.text('Viewer'), findsWidgets);
      expect(find.text('CO_OWNER'), findsNothing);
      expect(find.text('coOwner'), findsNothing);
    });

    testWidgets('shouldRenderCountsAndLoadPreviewWithoutRawBackendFields', (
      WidgetTester tester,
    ) async {
      final mediaRepository = media_fixtures.FakeMediaRepository()
        ..thumbnailResult = media_fixtures.validPngBytes;
      await pumpScreen(
        tester,
        FakeStoryRepository()
          ..storiesResult = <UserStory>[
            userStory(
              id: 'private-story-id',
              title: 'Private visible title',
              memoryCount: 24,
              participantCount: 2,
              previewPhoto: storyPreviewPhoto(mediaId: 'private-media-id'),
            ),
          ],
        mediaRepository: mediaRepository,
      );

      expect(find.text('24 memories'), findsOneWidget);
      expect(find.text('2 participants'), findsOneWidget);
      expect(mediaRepository.receivedBinaryPaths, <String>[
        '/api/v1/media/private-media-id/thumbnail',
      ]);
      expect(find.textContaining('owner-id'), findsNothing);
      expect(find.textContaining('user-id'), findsNothing);
      expect(find.textContaining('story-owner'), findsNothing);
      expect(find.textContaining('private-story-id'), findsNothing);
      expect(find.textContaining('/api/v1/media'), findsNothing);
      expect(find.textContaining('private-media-id'), findsNothing);
    });

    testWidgets('shouldCallStorySelectedWithExactStoryId', (
      WidgetTester tester,
    ) async {
      String? selectedStoryId;
      await pumpScreen(
        tester,
        FakeStoryRepository()..storiesResult = <UserStory>[ownerStory],
        onStorySelected: (storyId) {
          selectedStoryId = storyId;
        },
      );

      await tester.tap(find.text(ownerStory.story.title));
      await tester.pump();

      expect(selectedStoryId, ownerStory.story.id);
    });

    testWidgets('shouldCallCreateCallbackFromSectionAction', (
      WidgetTester tester,
    ) async {
      var createCalls = 0;
      await pumpScreen(
        tester,
        FakeStoryRepository(),
        onCreateStory: () {
          createCalls += 1;
        },
      );

      await tester.tap(
        find.byKey(const ValueKey('stories.create.section-action')),
      );
      await tester.pump();

      expect(createCalls, 1);
    });
  });

  group('StoriesScreen empty state', () {
    testWidgets('shouldRenderLocalizedEmptyState', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, FakeStoryRepository());

      expect(find.text('No stories yet'), findsOneWidget);
      expect(
        find.text(
          'Create your first story and save important moments together',
        ),
        findsOneWidget,
      );
      expect(find.text(ownerStory.story.title), findsNothing);
    });

    testWidgets('shouldCallCreateCallbackFromEmptyState', (
      WidgetTester tester,
    ) async {
      var createCalls = 0;
      await pumpScreen(
        tester,
        FakeStoryRepository(),
        onCreateStory: () {
          createCalls += 1;
        },
      );

      await tester.tap(find.byKey(const ValueKey('stories.empty.create-action')));
      await tester.pump();

      expect(createCalls, 1);
    });
  });

  group('StoriesScreen refresh', () {
    testWidgets('shouldDelegatePullToRefreshToNotifier', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory];
      await pumpScreen(tester, repository);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 360));
      await tester.pumpAndSettle();

      expect(repository.getStoriesCalls, 2);
    });

    testWidgets('shouldKeepListAndRenderRefreshFailureBanner', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory];
      await pumpScreen(tester, repository);
      repository.getStoriesFailures.add(
        const StoryApplicationException(StoryRequestTimedOut()),
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 360));
      await tester.pumpAndSettle();

      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(
        find.byKey(const ValueKey('stories.refresh.failure-banner')),
        findsOneWidget,
      );
      expect(find.textContaining('The request timed out'), findsOneWidget);
    });

    testWidgets('shouldRetryRefreshFromFailureBanner', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..storiesResult = <UserStory>[ownerStory];
      await pumpScreen(tester, repository);
      repository.getStoriesFailures.add(
        const StoryApplicationException(StoryRequestTimedOut()),
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 360));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('stories.refresh.retry-action')),
      );
      await tester.pumpAndSettle();

      expect(repository.getStoriesCalls, 3);
    });
  });

  group('StoriesScreen responsiveness and security', () {
    testWidgets('shouldNotOverflowWithLongContentAndLargeTextScale', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpScreen(
        tester,
        FakeStoryRepository()
          ..storiesResult = <UserStory>[
            userStory(
              id: 'private-story-id',
              title:
                  'A very long story title that should wrap without breaking',
              description:
                  'A long description for a narrow phone and larger text scale.',
            ),
          ],
        displayName: 'A very very long display name for accessibility',
        textScaler: const TextScaler.linear(1.35),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('shouldNotExposeTokensInfrastructureOrStoryIdsAsText', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()
          ..storiesResult = <UserStory>[
            userStory(
              id: 'private-story-id',
              title: 'Private visible title',
            ),
          ],
      );

      expect(find.textContaining('private-story-id'), findsNothing);
      expect(find.textContaining('accessToken'), findsNothing);
      expect(find.textContaining('refreshToken'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
      expect(find.textContaining('raw response'), findsNothing);
    });
  });
}

Future<void> pumpScreen(
  WidgetTester tester,
  FakeStoryRepository repository, {
  Locale locale = const Locale('en'),
  String displayName = 'Anna',
  String? avatarUrl,
  VoidCallback? onCreateStory,
  VoidCallback? onNotificationsSelected,
  VoidCallback? onProfileSelected,
  ValueChanged<String>? onStorySelected,
  media_fixtures.FakeMediaRepository? mediaRepository,
  FakeNotificationRepository? notificationRepository,
  TextScaler textScaler = TextScaler.noScaling,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storyRepositoryProvider.overrideWithValue(repository),
        notificationRepositoryProvider.overrideWithValue(
          notificationRepository ?? FakeNotificationRepository(),
        ),
        mediaRepositoryProvider.overrideWithValue(
          mediaRepository ?? media_fixtures.FakeMediaRepository(),
        ),
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
        home: StoriesScreen(
          displayName: displayName,
          avatarUrl: avatarUrl,
          onCreateStory: onCreateStory,
          onNotificationsSelected: onNotificationsSelected,
          onProfileSelected: onProfileSelected,
          onStorySelected: onStorySelected,
        ),
      ),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
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

UserStory userStory({
  String id = 'story-1',
  String title = 'First story',
  String? description = 'First description',
  StoryRole role = StoryRole.owner,
  int memoryCount = 0,
  int participantCount = 1,
  StoryPhotoPreview? previewPhoto,
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
    memoryCount: memoryCount,
    participantCount: participantCount,
    previewPhoto: previewPhoto,
  );
}

StoryPhotoPreview storyPreviewPhoto({
  String mediaId = 'media-id',
}) {
  return StoryPhotoPreview(
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
    displayPath: '/api/v1/media/$mediaId/display',
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
final UserStory editorStory = userStory(
  id: 'story-editor',
  title: 'Mountain weekends',
  description: 'Best short trips',
  role: StoryRole.editor,
);
final UserStory viewerStory = userStory(
  id: 'story-viewer',
  title: 'Summer 2024',
  description: 'Sea, sun, and us',
  role: StoryRole.viewer,
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

  List<UserStory> storiesResult = <UserStory>[];
  final List<Object> getStoriesFailures = <Object>[];
  Completer<List<UserStory>>? getStoriesCompleter;

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
    throw UnimplementedError();
  }

  @override
  Future<List<UserStory>> getStories() async {
    getStoriesCalls += 1;

    final completer = getStoriesCompleter;
    if (completer != null) {
      getStoriesCompleter = null;
      return completer.future;
    }

    if (getStoriesFailures.isNotEmpty) {
      throw getStoriesFailures.removeAt(0);
    }

    return storiesResult;
  }

  @override
  Future<UserStory> updateStory(UpdateStoryInput input) async {
    updateStoryCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<UserStory> uploadStoryCover({
    required String storyId,
    required PreparedPhotoUpload photo,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<UserStory> removeStoryCover({
    required String storyId,
  }) async {
    throw UnimplementedError();
  }
}

final class FakeNotificationRepository implements NotificationRepository {
  int unreadCount = 0;

  @override
  Future<List<NotificationItem>> getNotifications({int limit = 50}) async {
    return <NotificationItem>[];
  }

  @override
  Future<int> getUnreadCount() async {
    return unreadCount;
  }

  @override
  Future<void> markAllRead() async {}

  @override
  Future<void> markRead(String notificationId) async {}
}

final class UnexpectedStoryException implements Exception {
  const UnexpectedStoryException();
}
