import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_photo_preview.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/features/story/presentation/widgets/story_card.dart';
import 'package:memory_map/l10n/app_localizations.dart';

import '../../../media/media_test_fixtures.dart' as media_fixtures;

void main() {
  group('StoryCard', () {
    testWidgets('shouldLoadRealThumbnailThroughAuthenticatedBackendPath', (
      tester,
    ) async {
      final repository = media_fixtures.FakeMediaRepository()
        ..thumbnailResult = media_fixtures.validPngBytes;

      await pumpCard(
        tester,
        userStory(
          previewPhoto: storyPreviewPhoto(mediaId: 'media-a'),
        ),
        mediaRepository: repository,
      );

      expect(find.byKey(const ValueKey('story-card.thumbnail')), findsOneWidget);
      expect(repository.getThumbnailByPathCalls, 1);
      expect(repository.receivedBinaryPaths, <String>[
        '/api/v1/media/media-a/thumbnail',
      ]);
      expect(repository.getDisplayByPathCalls, 0);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('shouldRenderIntentionalNoPhotoState', (tester) async {
      await pumpCard(tester, userStory());

      expect(find.byKey(const ValueKey('story-card.no-photo')), findsOneWidget);
      expect(find.byIcon(Icons.photo_outlined), findsWidgets);
      expect(find.byType(Image), findsNothing);

      final noPhotoRect = tester.getRect(
        find.byKey(const ValueKey('story-card.no-photo')),
      );
      expect(noPhotoRect.width, noPhotoRect.height);
    });

    testWidgets('shouldKeepCardContentWhenThumbnailFails', (tester) async {
      final repository = media_fixtures.FakeMediaRepository()
        ..thumbnailFailure = const UnexpectedStoryImageException();

      await pumpCard(
        tester,
        userStory(previewPhoto: storyPreviewPhoto(mediaId: 'media-a')),
        mediaRepository: repository,
      );

      expect(
        find.byKey(const ValueKey('story-card.thumbnail-unavailable')),
        findsOneWidget,
      );
      expect(find.text('Our story'), findsOneWidget);
      expect(find.text('Together since 2021'), findsOneWidget);
      expect(find.text('12 memories'), findsOneWidget);
      expect(find.text('2 participants'), findsOneWidget);
      expect(find.textContaining('UnexpectedStoryImageException'), findsNothing);

      final thumbnailRect = tester.getRect(
        find.byKey(const ValueKey('story-card.thumbnail')),
      );
      final unavailableRect = tester.getRect(
        find.byKey(const ValueKey('story-card.thumbnail-unavailable')),
      );
      expect(unavailableRect.size, thumbnailRect.size);
    });

    testWidgets('shouldRenderTitleDescriptionRolesAndCounts', (tester) async {
      await pumpCard(tester, userStory());

      expect(find.text('Our story'), findsOneWidget);
      expect(find.text('Together since 2021'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('12 memories'), findsOneWidget);
      expect(find.text('2 participants'), findsOneWidget);
    });

    testWidgets('shouldRenderMetadataWithPinAndParticipantIcons', (
      tester,
    ) async {
      await pumpCard(tester, userStory());

      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
      expect(find.byIcon(Icons.group_outlined), findsOneWidget);
    });

    testWidgets('shouldKeepMetadataOnOneRowAtNormalPhoneWidth', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpCard(
        tester,
        userStory(memoryCount: 0, participantCount: 1),
      );

      final memoriesRect = tester.getRect(find.text('No memories'));
      final participantsRect = tester.getRect(find.text('1 participant'));

      expect(
        (memoriesRect.center.dy - participantsRect.center.dy).abs(),
        lessThan(1),
      );
    });

    testWidgets('shouldKeepTextBadgeAndCountsInRightColumn', (tester) async {
      await pumpCard(tester, userStory());

      final thumbnailRect = tester.getRect(
        find.byKey(const ValueKey('story-card.no-photo')),
      );
      final titleRect = tester.getRect(find.text('Our story'));
      final badgeRect = tester.getRect(find.text('Owner'));
      final memoriesRect = tester.getRect(find.text('12 memories'));
      final participantsRect = tester.getRect(find.text('2 participants'));

      expect(titleRect.left, greaterThan(thumbnailRect.right));
      expect(badgeRect.left, greaterThan(titleRect.left));
      expect(memoriesRect.left, greaterThan(thumbnailRect.right));
      expect(participantsRect.left, greaterThan(thumbnailRect.right));
      expect(memoriesRect.top, greaterThan(titleRect.top));
      expect(participantsRect.top, greaterThan(titleRect.top));
    });

    testWidgets('shouldHideAbsentOrBlankDescriptionCleanly', (tester) async {
      await pumpCard(
        tester,
        userStory(description: '   '),
      );

      expect(find.text('Our story'), findsOneWidget);
      expect(find.text('   '), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shouldRenderEveryRoleAsLocalizedLabel', (tester) async {
      await pumpCardList(
        tester,
        <UserStory>[
          userStory(role: StoryRole.owner, title: 'Owner story'),
          userStory(role: StoryRole.coOwner, title: 'Co-owner story'),
          userStory(role: StoryRole.editor, title: 'Editor story'),
          userStory(role: StoryRole.viewer, title: 'Viewer story'),
        ],
      );

      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Co-owner'), findsOneWidget);
      expect(find.text('Editor'), findsOneWidget);
      expect(find.text('Viewer'), findsOneWidget);
      expect(find.text('CO_OWNER'), findsNothing);
      expect(find.text('coOwner'), findsNothing);
    });

    testWidgets('shouldRenderEnglishPluralizedCounts', (tester) async {
      await pumpCardList(
        tester,
        <UserStory>[
          userStory(
            title: 'Zero',
            memoryCount: 0,
            participantCount: 1,
          ),
          userStory(
            title: 'Many',
            memoryCount: 2,
            participantCount: 2,
          ),
        ],
      );

      expect(find.text('No memories'), findsOneWidget);
      expect(find.text('1 participant'), findsWidgets);
      expect(find.text('2 memories'), findsOneWidget);
      expect(find.text('2 participants'), findsOneWidget);
    });

    testWidgets('shouldRenderRussianPluralizedCounts', (tester) async {
      await pumpCardList(
        tester,
        <UserStory>[
          userStory(title: 'One', memoryCount: 1, participantCount: 1),
          userStory(title: 'Few', memoryCount: 2, participantCount: 2),
          userStory(title: 'Many', memoryCount: 5, participantCount: 5),
          userStory(title: 'Twenty one', memoryCount: 21, participantCount: 21),
        ],
        locale: const Locale('ru'),
      );

      expect(find.text('1 воспоминание'), findsOneWidget);
      expect(find.text('2 воспоминания'), findsOneWidget);
      expect(find.text('5 воспоминаний'), findsOneWidget);
      expect(find.text('21 воспоминание'), findsOneWidget);
      expect(find.text('1 участник'), findsOneWidget);
      expect(find.text('2 участника'), findsOneWidget);
      expect(find.text('5 участников'), findsOneWidget);
      expect(find.text('21 участник'), findsOneWidget);
    });

    testWidgets('shouldNotExposeIdsPathsOrStorageDetailsAsText', (
      tester,
    ) async {
      await pumpCard(
        tester,
        userStory(
          id: 'private-story-id',
          previewPhoto: storyPreviewPhoto(mediaId: 'private-media-id'),
        ),
      );

      expect(find.textContaining('private-story-id'), findsNothing);
      expect(find.textContaining('private-media-id'), findsNothing);
      expect(find.textContaining('/api/v1/media'), findsNothing);
      expect(find.textContaining('accessToken'), findsNothing);
      expect(find.textContaining('MinIO'), findsNothing);
    });

    testWidgets('shouldCallSelectionWithExactStoryId', (tester) async {
      String? selectedStoryId;
      await pumpCard(
        tester,
        userStory(id: 'story-selected'),
        onSelected: (storyId) {
          selectedStoryId = storyId;
        },
      );

      await tester.tap(find.text('Our story'));
      await tester.pump();

      expect(selectedStoryId, 'story-selected');
    });

    testWidgets('shouldHandleLongContentAndLargeTextScale', (tester) async {
      tester.view.physicalSize = const Size(330, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpCard(
        tester,
        userStory(
          title: 'A very long story title that wraps without layout overflow',
          description:
              'A longer story description that should be clamped by presentation only.',
        ),
        textScaler: const TextScaler.linear(1.35),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('shouldHandleLongTitleWithCoOwnerBadge', (tester) async {
      tester.view.physicalSize = const Size(330, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpCard(
        tester,
        userStory(
          title:
              'A long co-owned story title that should leave room for badge',
          role: StoryRole.coOwner,
        ),
      );

      expect(find.text('Co-owner'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final thumbnailRect = tester.getRect(
        find.byKey(const ValueKey('story-card.no-photo')),
      );
      final memoriesRect = tester.getRect(find.text('12 memories'));
      expect(memoriesRect.left, greaterThan(thumbnailRect.right));
    });
  });
}

Future<void> pumpCard(
  WidgetTester tester,
  UserStory userStory, {
  Locale locale = const Locale('en'),
  media_fixtures.FakeMediaRepository? mediaRepository,
  ValueChanged<String>? onSelected,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await pumpCardList(
    tester,
    <UserStory>[userStory],
    locale: locale,
    mediaRepository: mediaRepository,
    onSelected: onSelected,
    textScaler: textScaler,
  );
}

Future<void> pumpCardList(
  WidgetTester tester,
  List<UserStory> stories, {
  Locale locale = const Locale('en'),
  media_fixtures.FakeMediaRepository? mediaRepository,
  ValueChanged<String>? onSelected,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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
        home: Scaffold(
          body: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemBuilder: (context, index) {
              return StoryCard(
                userStory: stories[index],
                onSelected: onSelected,
              );
            },
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemCount: stories.length,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

UserStory userStory({
  String id = 'story-id',
  String title = 'Our story',
  String? description = 'Together since 2021',
  StoryRole role = StoryRole.owner,
  int memoryCount = 12,
  int participantCount = 2,
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
  required String mediaId,
}) {
  return StoryPhotoPreview(
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}

final class UnexpectedStoryImageException implements Exception {
  const UnexpectedStoryImageException();
}
