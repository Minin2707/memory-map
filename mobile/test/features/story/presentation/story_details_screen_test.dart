import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/media/presentation/widgets/authenticated_media_image.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';
import 'package:memory_map/features/participant/application/participant_application_exception.dart';
import 'package:memory_map/features/music/application/music_application_exception.dart';
import 'package:memory_map/features/music/application/music_application_providers.dart';
import 'package:memory_map/features/music/domain/music_failure.dart';
import 'package:memory_map/features/music/domain/music_track.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';
import 'package:memory_map/features/music/domain/story_soundtrack_repository.dart';
import 'package:memory_map/features/participant/application/participant_application_providers.dart';
import 'package:memory_map/features/participant/domain/leave_story_input.dart';
import 'package:memory_map/features/participant/domain/participant_failure.dart';
import 'package:memory_map/features/participant/domain/remove_story_participant_input.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/participant/domain/story_participant_repository.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/story_photo_preview.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/features/story/presentation/story_details_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

import '../../media/media_test_fixtures.dart' as media_fixtures;

void main() {
  group('StoryDetailsScreen rendering', () {
    testWidgets('shouldRenderEnglishStoryDetails', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, FakeStoryRepository()..storyResult = ownerStory);

      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(find.text(ownerStory.story.description!), findsWidgets);
      expect(find.text('No memories'), findsOneWidget);
      expect(find.text('1 participant'), findsOneWidget);
      expect(find.text('Owner'), findsNothing);
      await scrollDownUntilFound(
        tester,
        find.byKey(const ValueKey('story-details.lower-content')),
      );
      expect(
        find.byKey(const ValueKey('story-details.lower-content')),
        findsOneWidget,
      );
      expect(find.text('Recent memories'), findsOneWidget);
      expect(find.text('No memories yet'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-details.description-card')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('story-details.info-card')),
        findsNothing,
      );
    });

    testWidgets('shouldRenderRussianStoryDetails', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        locale: const Locale('ru'),
      );

      expect(find.text('Нет воспоминаний'), findsOneWidget);
      await scrollDownUntilFound(
        tester,
        find.byKey(const ValueKey('story-details.lower-content')),
      );
      expect(
        find.byKey(const ValueKey('story-details.lower-content')),
        findsOneWidget,
      );
      expect(find.text('Последние воспоминания'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-details.info-card')),
        findsNothing,
      );
    });

    testWidgets('shouldNotRenderLegacyNoDescriptionPlaceholder', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = storyWithoutDescription,
      );

      await scrollDownUntilFound(
        tester,
        find.byKey(const ValueKey('story-details.lower-content')),
      );

      expect(find.text('No description yet.'), findsNothing);
    });

    testWidgets('shouldHideBlankHeroDescription', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()
          ..storyResult = userStory(description: '   '),
      );

      await scrollDownUntilFound(
        tester,
        find.byKey(const ValueKey('story-details.lower-content')),
      );

      expect(find.text('No description yet.'), findsNothing);
      expect(find.text('   '), findsNothing);
    });

    testWidgets('shouldNotRenderRoleBadgesInStoryDetailsHero', (
      WidgetTester tester,
    ) async {
      for (final role in StoryRole.values) {
        await pumpScreen(
          tester,
          FakeStoryRepository()..storyResult = userStory(role: role),
        );

        expect(find.text(roleLabel(role)), findsNothing);
      }
    });

    testWidgets('shouldRenderParticipantsSummaryFromProvider', (
      WidgetTester tester,
    ) async {
      final participantRepository = FakeStoryParticipantRepository()
        ..participantsResult = <StoryParticipant>[
          participant(
            userId: 'anna-user-id',
            displayName: 'Anna',
            avatarUrl: 'https://example.test/anna.png',
            role: StoryRole.owner,
          ),
          participant(
            userId: 'alex-user-id',
            displayName: 'Alex Lane',
            avatarUrl: null,
            role: StoryRole.coOwner,
          ),
        ];

      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        participantRepository: participantRepository,
      );

      await scrollDownUntilFound(
        tester,
        find.byKey(const ValueKey('story-details.participants-summary')),
      );

      expect(
        participantRepository.receivedStoryIds,
        <String>['story-1'],
      );
      expect(
        find.byKey(const ValueKey('story-details.participants-summary')),
        findsOneWidget,
      );
      expect(find.text('Participants'), findsOneWidget);
      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Alex Lane'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Co-owner'), findsOneWidget);

      final avatars = tester
          .widgetList<CircleAvatar>(
            find.byKey(const ValueKey('story-details.participants.avatar')),
          )
          .toList();
      expect(avatars, hasLength(2));
      expect(avatars.first.foregroundImage, isA<NetworkImage>());
      expect(avatars.last.foregroundImage, isNull);
      expect(
        find.descendant(
          of: find
              .byKey(const ValueKey('story-details.participants.avatar'))
              .last,
          matching: find.text('AL'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'shouldRenderParticipantsSummaryCustomAvatarThroughAuthenticatedPath',
      (WidgetTester tester) async {
        const avatarPath =
            '/api/v1/stories/story-owner/participants/anna-user-id/avatar/1';
        final participantRepository = FakeStoryParticipantRepository()
          ..participantsResult = <StoryParticipant>[
            participant(
              userId: 'anna-user-id',
              displayName: 'Anna',
              avatarUrl: avatarPath,
              role: StoryRole.owner,
            ),
          ];
        final mediaRepository = media_fixtures.FakeMediaRepository();

        await pumpScreen(
          tester,
          FakeStoryRepository()..storyResult = ownerStory,
          participantRepository: participantRepository,
          mediaRepository: mediaRepository,
        );

        await scrollDownUntilFound(
          tester,
          find.byKey(const ValueKey('story-details.participants-summary')),
        );

        expect(find.byType(AuthenticatedMediaPathImage), findsWidgets);
        expect(mediaRepository.getDisplayByPathCalls, 1);
        expect(mediaRepository.receivedBinaryPaths, contains(avatarPath));
      },
    );

    testWidgets('shouldRenderNoMusicSoundtrackSummaryForOwner', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        soundtrackRepository: FakeStorySoundtrackRepository()
          ..getResult = StorySoundtrack.noMusic(),
      );

      await scrollDownUntilFound(
        tester,
        find.byKey(const ValueKey('story-details.soundtrack-summary')),
      );

      expect(find.text('Soundtrack'), findsOneWidget);
      expect(find.text('No music'), findsOneWidget);
    });

    testWidgets('shouldRenderSelectedSoundtrackSummary', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        soundtrackRepository: FakeStorySoundtrackRepository()
          ..getResult = StorySoundtrack(
            selectedSoundtrack: soundtrackTrack,
            effectiveSoundtrack: soundtrackTrack,
          ),
      );

      await scrollDownUntilFound(
        tester,
        find.byKey(const ValueKey('story-details.soundtrack-summary')),
      );

      expect(find.text('Autumn Leaves'), findsOneWidget);
      expect(find.text('LofCosmos'), findsOneWidget);
      expect(find.textContaining('Currently unavailable'), findsNothing);
    });

    testWidgets('shouldRenderSelectedUnavailableSoundtrackSummary', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        soundtrackRepository: FakeStorySoundtrackRepository()
          ..getResult = StorySoundtrack(selectedSoundtrack: soundtrackTrack),
      );

      await scrollDownUntilFound(
        tester,
        find.byKey(const ValueKey('story-details.soundtrack-summary')),
      );

      expect(find.text('Autumn Leaves'), findsOneWidget);
      expect(find.textContaining('Currently unavailable'), findsOneWidget);
      expect(find.textContaining('DISABLED'), findsNothing);
    });

    testWidgets('shouldExposeSoundtrackNavigationOnlyForOwnerAndCoOwner', (
      WidgetTester tester,
    ) async {
      var navigationCount = 0;

      for (final role in StoryRole.values) {
        await pumpScreen(
          tester,
          FakeStoryRepository()..storyResult = userStory(role: role),
          onSoundtrackSelected: (_) {
            navigationCount += 1;
          },
        );

        await scrollDownUntilFound(
          tester,
          find.byKey(const ValueKey('story-details.soundtrack-summary')),
        );
        await pressButton(
          tester,
          find.byKey(const ValueKey('story-details.soundtrack-summary')),
        );
      }

      expect(navigationCount, 2);
    });

    testWidgets('shouldRenderSoundtrackFailureRetryWithoutBlockingDetails', (
      WidgetTester tester,
    ) async {
      final repository = FakeStorySoundtrackRepository()
        ..getFailures.add(
          const MusicApplicationException(MusicNetworkUnavailable()),
        )
        ..getResult = StorySoundtrack.noMusic();

      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        soundtrackRepository: repository,
      );

      await scrollDownUntilFound(
        tester,
        find.byKey(const ValueKey('story-details.soundtrack-summary')),
      );

      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(find.textContaining('Could not load soundtrack'), findsOneWidget);

      await pressButton(
        tester,
        find.byKey(
          const ValueKey('story-details.soundtrack-summary.retry-action'),
        ),
      );

      expect(repository.getCalls, 2);
      expect(find.text('No music'), findsOneWidget);
    });

    testWidgets('shouldRenderParticipantPreviewLimitAndRemainingCount', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        participantRepository: FakeStoryParticipantRepository()
          ..participantsResult = <StoryParticipant>[
            participant(displayName: 'Anna', role: StoryRole.owner),
            participant(displayName: 'Alex', role: StoryRole.coOwner),
            participant(displayName: 'Mira', role: StoryRole.editor),
            participant(displayName: 'Oleg', role: StoryRole.viewer),
            participant(displayName: 'Nina', role: StoryRole.viewer),
          ],
      );

      await scrollDownUntilFound(
        tester,
        find.byKey(const ValueKey('story-details.participants-summary')),
      );

      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Mira'), findsOneWidget);
      expect(find.text('Oleg'), findsNothing);
      expect(find.text('Nina'), findsNothing);
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('shouldRenderParticipantsLoadingWithoutBlockingHero', (
      WidgetTester tester,
    ) async {
      final completer = Completer<List<StoryParticipant>>();
      final participantRepository = FakeStoryParticipantRepository()
        ..getParticipantsCompleter = completer;

      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        participantRepository: participantRepository,
        settle: false,
      );
      await tester.pump();

      expect(find.text(ownerStory.story.title), findsOneWidget);
      await scrollDownUntilFound(
        tester,
        find.byKey(const ValueKey('story-details.participants.loading')),
      );
      expect(
        find.byKey(const ValueKey('story-details.participants.loading')),
        findsOneWidget,
      );
      expect(find.text('Anna'), findsNothing);

      completer.complete(<StoryParticipant>[ownerParticipant]);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRenderParticipantsEmptyStateDefensively', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        participantRepository: FakeStoryParticipantRepository()
          ..participantsResult = <StoryParticipant>[],
      );

      await scrollDownUntilFound(
        tester,
        find.byKey(const ValueKey('story-details.participants.empty')),
      );

      expect(
        find.byKey(const ValueKey('story-details.participants.empty')),
        findsOneWidget,
      );
      expect(find.text('No participants to show'), findsOneWidget);
      expect(find.text(ownerStory.story.title), findsOneWidget);
    });

    testWidgets('shouldRenderParticipantsFailureSafelyAndRetry', (
      WidgetTester tester,
    ) async {
      final participantRepository = FakeStoryParticipantRepository()
        ..getParticipantsFailures.add(
          const ParticipantApplicationException(
            ParticipantNetworkUnavailable(),
          ),
        )
        ..participantsResult = <StoryParticipant>[ownerParticipant];

      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        participantRepository: participantRepository,
      );

      await scrollDownUntilFound(
        tester,
        find.byKey(const ValueKey('story-details.participants.failure')),
      );

      expect(
        find.byKey(const ValueKey('story-details.participants.failure')),
        findsOneWidget,
      );
      expect(find.textContaining('Could not load participants'), findsOneWidget);
      expect(
        find.textContaining('No network connection'),
        findsOneWidget,
      );
      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(find.textContaining('ParticipantApplicationException'),
          findsNothing);
      expect(find.textContaining('private-user-id'), findsNothing);

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-details.participants.retry-action')),
      );

      expect(participantRepository.getParticipantsCalls, 2);
      expect(find.text('Anna'), findsOneWidget);
    });

    testWidgets('shouldHandleLongParticipantsOnSmallViewport', (
      WidgetTester tester,
    ) async {
      setSurface(tester, const Size(320, 640));

      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        textScaler: const TextScaler.linear(1.45),
        participantRepository: FakeStoryParticipantRepository()
          ..participantsResult = <StoryParticipant>[
            participant(
              displayName: 'Alexandria Very Long Family Name',
              role: StoryRole.coOwner,
            ),
            participant(displayName: 'Mira', role: StoryRole.editor),
            participant(displayName: 'Nina', role: StoryRole.viewer),
          ],
      );

      expect(find.text('Alexandria Very Long Family Name'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shouldLoadRealHeroDisplayWhenPreviewExists', (
      WidgetTester tester,
    ) async {
      final mediaRepository = media_fixtures.FakeMediaRepository();
      final story = userStory(
        memoryCount: 24,
        participantCount: 2,
        previewPhoto: previewPhoto('media-a'),
      );

      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = story,
        mediaRepository: mediaRepository,
      );

      expect(find.text(story.story.title), findsOneWidget);
      expect(find.text(story.story.description!), findsWidgets);
      expect(find.text('24 memories'), findsOneWidget);
      expect(find.text('2 participants'), findsOneWidget);
      expect(mediaRepository.getDisplayByPathCalls, 1);
      expect(mediaRepository.getThumbnailByPathCalls, 0);
      expect(mediaRepository.receivedBinaryPaths, <String>[
        '/api/v1/media/media-a/display',
      ]);
      final resizeImage = resizeImageFor(
        tester,
        find.descendant(
          of: find.byKey(
            const ValueKey(
              'story-details.hero-display./api/v1/media/media-a/display',
            ),
          ),
          matching: find.byType(Image),
        ),
      );
      expect(resizeImage.width, isNotNull);
      expect(resizeImage.height, isNull);
      expect(resizeImage.width, lessThanOrEqualTo(2048));
    });

    testWidgets('shouldRenderIntentionalNoPhotoHero', (
      WidgetTester tester,
    ) async {
      final mediaRepository = media_fixtures.FakeMediaRepository();

      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        mediaRepository: mediaRepository,
      );

      expect(
        find.byKey(const ValueKey('story-details.hero.no-photo')),
        findsOneWidget,
      );
      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(mediaRepository.getDisplayByPathCalls, 0);
      expect(mediaRepository.getThumbnailByPathCalls, 0);
    });

    testWidgets('shouldKeepStoryVisibleWhenHeroDisplayFails', (
      WidgetTester tester,
    ) async {
      final mediaRepository = media_fixtures.FakeMediaRepository()
        ..displayFailure = const StoryApplicationException(StoryNotFound());

      final story = userStory(previewPhoto: previewPhoto('media-a'));
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = story,
        mediaRepository: mediaRepository,
      );

      expect(
        find.byKey(const ValueKey('story-details.hero.display-failure')),
        findsOneWidget,
      );
      expect(find.text(story.story.title), findsOneWidget);
      expect(find.textContaining('/api/v1/media'), findsNothing);
      expect(find.textContaining('media-a'), findsNothing);
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

    testWidgets('shouldRenderLowerCompositionActionsAndRecentMemories', (
      WidgetTester tester,
    ) async {
      setSurface(tester, const Size(390, 1200));
      UserStory? memoriesStory;
      UserStory? mapStory;
      UserStory? timelineStory;
      Memory? selectedMemory;
      UserStory? playbackStory;
      var createCalls = 0;
      var inviteCalls = 0;
      final latestMemory = memory(
        id: 'latest-memory',
        title: 'Latest memory',
        eventDate: MemoryDate(year: 2026, month: 8, day: 9),
      );
      final middleMemory = memory(
        id: 'middle-memory',
        title: 'Middle memory',
        eventDate: MemoryDate(year: 2025, month: 5, day: 4),
      );
      final olderMemory = memory(
        id: 'older-memory',
        title: 'Older memory',
        eventDate: MemoryDate(year: 2024, month: 2, day: 3),
      );
      final oldestMemory = memory(
        id: 'oldest-memory',
        title: 'Oldest memory',
        eventDate: MemoryDate(year: 2023, month: 1, day: 2),
      );
      final mediaRepository = media_fixtures.FakeMediaRepository();
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        mediaRepository: mediaRepository,
        memoryRepository: FakeMemoryRepository()
          ..memoriesResult = <MemoryReadModel>[
            MemoryReadModel.fromMemory(oldestMemory),
            MemoryReadModel.fromMemory(olderMemory),
            MemoryReadModel.fromMemory(middleMemory),
            MemoryReadModel(
              memory: latestMemory,
              previewPhoto: memoryPreviewPhoto('media-latest'),
            ),
          ],
        onInvite: () {
          inviteCalls += 1;
        },
        onMemoriesSelected: (userStory) {
          memoriesStory = userStory;
        },
        onMapSelected: (userStory) {
          mapStory = userStory;
        },
        onTimelineSelected: (userStory) {
          timelineStory = userStory;
        },
        onCreateMemory: () {
          createCalls += 1;
        },
        onMemorySelected: (memory) {
          selectedMemory = memory;
        },
        onPlaybackSelected: (userStory) {
          playbackStory = userStory;
        },
      );

      await scrollDownUntilFound(
        tester,
        find.byKey(const ValueKey('story-details.lower-content')),
      );

      expect(find.text('Explore'), findsNothing);
      expect(find.text('Recent memories'), findsOneWidget);
      expect(find.text('Latest memory'), findsOneWidget);
      expect(find.text('Middle memory'), findsOneWidget);
      expect(find.text('Older memory'), findsOneWidget);
      expect(find.text('Oldest memory'), findsNothing);
      expect(
        mediaRepository.receivedBinaryPaths,
        contains('/api/v1/media/media-latest/thumbnail'),
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-details.memories-action')),
      );
      await pressButton(
        tester,
        find.byKey(
          const ValueKey('story-details.recent-memories.see-all-action'),
        ),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('story-details.invite-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('story-details.map-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('story-details.timeline-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('story-details.add-memory-action')),
      );
      await pressButton(tester, find.text('Latest memory'));
      await pressButton(
        tester,
        find.byKey(const ValueKey('story-details.playback-action')),
      );

      expect(memoriesStory, ownerStory);
      expect(mapStory, ownerStory);
      expect(timelineStory, ownerStory);
      expect(createCalls, 1);
      expect(selectedMemory, latestMemory);
      expect(playbackStory, ownerStory);
      expect(inviteCalls, 1);
    });

    testWidgets('shouldShowPlaybackForEveryRoleWhenCallbackExists', (
      WidgetTester tester,
    ) async {
      setSurface(tester, const Size(390, 1200));

      for (final role in StoryRole.values) {
        UserStory? selectedStory;
        final story = userStory(role: role);
        await pumpScreen(
          tester,
          FakeStoryRepository()..storyResult = story,
          onPlaybackSelected: (userStory) {
            selectedStory = userStory;
          },
        );

        final action =
            find.byKey(const ValueKey('story-details.playback-action'));
        expect(action, findsOneWidget);
        expect(find.text('Playback Story'), findsOneWidget);

        await pressButton(tester, action);

        expect(selectedStory, story);
        expect(find.textContaining(story.story.id), findsNothing);
      }
    });

    testWidgets('shouldHidePlaybackWhenCallbackIsAbsent', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
      );

      expect(
        find.byKey(const ValueKey('story-details.playback-action')),
        findsNothing,
      );
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
      }
    });

    testWidgets('shouldShowParticipantsSummaryManageAndInviteForOwnerAndCoOwner', (
      WidgetTester tester,
    ) async {
      for (final role in <StoryRole>[StoryRole.owner, StoryRole.coOwner]) {
        UserStory? managedStory;
        var inviteCalls = 0;
        final story = userStory(role: role);
        await pumpScreen(
          tester,
          FakeStoryRepository()..storyResult = story,
          participantRepository: FakeStoryParticipantRepository()
            ..participantsResult = <StoryParticipant>[ownerParticipant],
          onParticipantsSelected: (userStory) {
            managedStory = userStory;
          },
          onInvite: () {
            inviteCalls += 1;
          },
        );

        await scrollDownUntilFound(
          tester,
          find.byKey(const ValueKey('story-details.participants-summary')),
        );

        await pressButton(
          tester,
          find.byKey(
            const ValueKey('story-details.participants.manage-action'),
          ),
        );
        await pressButton(
          tester,
          find.byKey(
            const ValueKey('story-details.participants.invite-action'),
          ),
        );

        expect(managedStory, story);
        expect(inviteCalls, 1);
      }
    });

    testWidgets('shouldKeepParticipantsSummaryReadonlyForEditorAndViewer', (
      WidgetTester tester,
    ) async {
      for (final role in <StoryRole>[StoryRole.editor, StoryRole.viewer]) {
        await pumpScreen(
          tester,
          FakeStoryRepository()..storyResult = userStory(role: role),
          participantRepository: FakeStoryParticipantRepository()
            ..participantsResult = <StoryParticipant>[
              participant(displayName: 'Anna', role: role),
            ],
          onParticipantsSelected: (_) {},
          onInvite: () {},
        );

        await scrollDownUntilFound(
          tester,
          find.byKey(const ValueKey('story-details.participants-summary')),
        );

        expect(find.text('Anna'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('story-details.participants.manage-action')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('story-details.participants.invite-action')),
          findsNothing,
        );
      }
    });

    testWidgets('shouldShowNavigationForEveryRoleWhenCallbacksExist', (
      WidgetTester tester,
    ) async {
      setSurface(tester, const Size(390, 1200));

      for (final role in StoryRole.values) {
        UserStory? memoriesStory;
        UserStory? mapStory;
        UserStory? timelineStory;
        final story = userStory(role: role);
        await pumpScreen(
          tester,
          FakeStoryRepository()..storyResult = story,
          onMemoriesSelected: (userStory) {
            memoriesStory = userStory;
          },
          onMapSelected: (userStory) {
            mapStory = userStory;
          },
          onTimelineSelected: (userStory) {
            timelineStory = userStory;
          },
        );

        expect(
          find.byKey(const ValueKey('story-details.section-navigation')),
          findsOneWidget,
        );
        expect(find.text('Memories'), findsOneWidget);
        expect(find.text('Map'), findsOneWidget);
        expect(find.text('Timeline'), findsOneWidget);

        await pressButton(
          tester,
          find.byKey(const ValueKey('story-details.memories-action')),
        );
        await pressButton(
          tester,
          find.byKey(const ValueKey('story-details.map-action')),
        );
        await pressButton(
          tester,
          find.byKey(const ValueKey('story-details.timeline-action')),
        );

        expect(memoriesStory, story);
        expect(mapStory, story);
        expect(timelineStory, story);
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

    testWidgets('shouldShowAddMemoryForWritableRolesOnly', (
      WidgetTester tester,
    ) async {
      setSurface(tester, const Size(390, 1200));

      for (final role in <StoryRole>[
        StoryRole.owner,
        StoryRole.coOwner,
        StoryRole.editor,
      ]) {
        var createCalls = 0;
        await pumpScreen(
          tester,
          FakeStoryRepository()..storyResult = userStory(role: role),
          onCreateMemory: () {
            createCalls += 1;
          },
        );

        await scrollDownUntilFound(
          tester,
          find.byKey(const ValueKey('story-details.lower-content')),
        );

        final action =
            find.byKey(const ValueKey('story-details.add-memory-action'));
        expect(action, findsOneWidget);

        await pressButton(tester, action);

        expect(createCalls, 1);
      }

      await pumpScreen(
        tester,
        FakeStoryRepository()
          ..storyResult = userStory(role: StoryRole.viewer),
        onCreateMemory: () {},
      );

      await scrollDownUntilFound(
        tester,
        find.byKey(const ValueKey('story-details.lower-content')),
      );

      expect(
        find.byKey(const ValueKey('story-details.add-memory-action')),
        findsNothing,
      );
    });

    testWidgets('shouldRenderNavigationButHideUnavailablePrimaryActions', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, FakeStoryRepository()..storyResult = ownerStory);

      await scrollDownUntilFound(
        tester,
        find.byKey(const ValueKey('story-details.lower-content')),
      );

      expect(find.text('Memories'), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Timeline'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-details.participants-action')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('story-details.participants.manage-action')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('story-details.recent-memories.see-all-action'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('story-details.add-memory-action')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('story-details.playback-action')),
        findsNothing,
      );
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

  group('StoryDetailsScreen period', () {
    testWidgets('shouldRenderHistoricalYearRangeFromMemoryEventDates', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        memoryRepository: FakeMemoryRepository()
          ..memoriesResult = <MemoryReadModel>[
            MemoryReadModel.fromMemory(memory(eventDate: memoryDate(2024))),
            MemoryReadModel.fromMemory(memory(eventDate: memoryDate(2021))),
          ],
      );

      expect(find.text('2021 — 2024'), findsOneWidget);
    });

    testWidgets('shouldRenderPresentWhenLatestMemoryYearIsCurrent', (
      WidgetTester tester,
    ) async {
      final currentYear = DateTime.now().year;
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        memoryRepository: FakeMemoryRepository()
          ..memoriesResult = <MemoryReadModel>[
            MemoryReadModel.fromMemory(memory(eventDate: memoryDate(2021))),
            MemoryReadModel.fromMemory(
              memory(eventDate: memoryDate(currentYear)),
            ),
          ],
      );

      expect(find.text('2021 — present'), findsOneWidget);
    });

    testWidgets('shouldRenderSingleYearWithoutPresentSuffix', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        memoryRepository: FakeMemoryRepository()
          ..memoriesResult = <MemoryReadModel>[
            MemoryReadModel.fromMemory(memory(eventDate: memoryDate(2023))),
          ],
      );

      expect(find.text('2023'), findsOneWidget);
      expect(find.textContaining('present'), findsNothing);
    });

    testWidgets('shouldOmitPeriodWhenMemoriesAreEmpty', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        memoryRepository: FakeMemoryRepository()
          ..memoriesResult = const <MemoryReadModel>[],
      );

      expect(find.textContaining(' — '), findsNothing);
    });

    testWidgets('shouldRenderHeroWhileMemoriesAreStillLoading', (
      WidgetTester tester,
    ) async {
      final completer = Completer<List<MemoryReadModel>>();
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        memoryRepository: FakeMemoryRepository()..getMemoriesCompleter = completer,
        settle: false,
      );
      await tester.pump();

      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(find.textContaining(' — '), findsNothing);

      completer.complete(const <MemoryReadModel>[]);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRenderHeroWhenMemoriesFail', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository()..storyResult = ownerStory,
        memoryRepository: FakeMemoryRepository()
          ..failure = const StoryApplicationException(StoryNotFound()),
      );

      expect(find.text(ownerStory.story.title), findsOneWidget);
      expect(find.textContaining('StoryApplicationException'), findsNothing);
      expect(find.textContaining(' — '), findsNothing);
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
  ValueChanged<UserStory>? onTimelineSelected,
  ValueChanged<UserStory>? onSoundtrackSelected,
  VoidCallback? onCreateMemory,
  ValueChanged<Memory>? onMemorySelected,
  ValueChanged<UserStory>? onPlaybackSelected,
  media_fixtures.FakeMediaRepository? mediaRepository,
  FakeMemoryRepository? memoryRepository,
  FakeStoryParticipantRepository? participantRepository,
  FakeStorySoundtrackRepository? soundtrackRepository,
  TextScaler textScaler = TextScaler.noScaling,
  bool settle = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      storyRepositoryProvider.overrideWithValue(repository),
      mediaRepositoryProvider.overrideWithValue(
        mediaRepository ?? media_fixtures.FakeMediaRepository(),
      ),
      memoryRepositoryProvider.overrideWithValue(
        memoryRepository ?? FakeMemoryRepository(),
      ),
      storyParticipantRepositoryProvider.overrideWithValue(
        participantRepository ?? FakeStoryParticipantRepository(),
      ),
      storySoundtrackRepositoryProvider.overrideWithValue(
        soundtrackRepository ?? FakeStorySoundtrackRepository(),
      ),
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
          onTimelineSelected: onTimelineSelected,
          onSoundtrackSelected: onSoundtrackSelected,
          onCreateMemory: onCreateMemory,
          onMemorySelected: onMemorySelected,
          onPlaybackSelected: onPlaybackSelected,
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
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
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

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -280));
    await tester.pumpAndSettle();
  }

  fail('Expected finder to become visible after scrolling: $finder');
}

void setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

ResizeImage resizeImageFor(WidgetTester tester, Finder finder) {
  final image = tester.widget<Image>(finder);
  expect(image.image, isA<ResizeImage>());
  return image.image as ResizeImage;
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

Memory memory({
  String id = 'memory-id',
  String title = 'Memory',
  String? placeName,
  MemoryDate? eventDate,
}) {
  return Memory(
    id: id,
    storyId: ownerStory.story.id,
    createdBy: 'author-id',
    title: title,
    description: null,
    placeName: placeName,
    location: MemoryLocation(latitude: 55.751244, longitude: 37.618423),
    eventDate: eventDate ?? memoryDate(2024),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
  );
}

MemoryDate memoryDate(int year) {
  return MemoryDate(year: year, month: 6, day: 1);
}

StoryPhotoPreview previewPhoto(String mediaId) {
  return StoryPhotoPreview(
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
    displayPath: '/api/v1/media/$mediaId/display',
  );
}

MemoryPhotoPreview memoryPreviewPhoto(String mediaId) {
  return MemoryPhotoPreview(
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}

final MusicTrack soundtrackTrack = MusicTrack(
  id: 'track-a',
  title: 'Autumn Leaves',
  artist: 'LofCosmos',
  durationSeconds: 270,
);

StoryParticipant participant({
  String? userId,
  String displayName = 'Anna',
  String? avatarUrl,
  StoryRole role = StoryRole.owner,
}) {
  return StoryParticipant(
    userId: userId ?? '${displayName.toLowerCase().replaceAll(' ', '-')}-id',
    displayName: displayName,
    avatarUrl: avatarUrl,
    role: role,
    joinedAt: DateTime.utc(2026, 1, 3),
  );
}

final StoryParticipant ownerParticipant = participant(
  userId: 'owner-user-id',
  displayName: 'Anna',
  avatarUrl: 'https://example.test/anna.png',
  role: StoryRole.owner,
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

final class FakeStoryParticipantRepository implements StoryParticipantRepository {
  int getParticipantsCalls = 0;
  final List<String> receivedStoryIds = <String>[];
  List<StoryParticipant> participantsResult = const <StoryParticipant>[];
  final List<Object> getParticipantsFailures = <Object>[];
  Completer<List<StoryParticipant>>? getParticipantsCompleter;

  @override
  Future<List<StoryParticipant>> getParticipants(String storyId) async {
    getParticipantsCalls += 1;
    receivedStoryIds.add(storyId);

    final completer = getParticipantsCompleter;
    if (completer != null) {
      getParticipantsCompleter = null;
      return completer.future;
    }

    if (getParticipantsFailures.isNotEmpty) {
      throw getParticipantsFailures.removeAt(0);
    }

    return participantsResult;
  }

  @override
  Future<void> leaveStory(LeaveStoryInput input) async {
    throw UnimplementedError();
  }

  @override
  Future<void> removeParticipant(RemoveStoryParticipantInput input) async {
    throw UnimplementedError();
  }
}

final class FakeStorySoundtrackRepository
    implements StorySoundtrackRepository {
  int getCalls = 0;
  StorySoundtrack getResult = StorySoundtrack.noMusic();
  final List<Object> getFailures = <Object>[];

  @override
  Future<StorySoundtrack> getStorySoundtrack(String storyId) async {
    getCalls += 1;
    if (getFailures.isNotEmpty) {
      throw getFailures.removeAt(0);
    }

    return getResult;
  }

  @override
  Future<StorySoundtrack> setStorySoundtrack(
    String storyId,
    String musicTrackId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<StorySoundtrack> removeStorySoundtrack(String storyId) async {
    throw UnimplementedError();
  }
}

final class FakeMemoryRepository implements MemoryRepository {
  int getMemoriesCalls = 0;
  List<MemoryReadModel> memoriesResult = const <MemoryReadModel>[];
  Completer<List<MemoryReadModel>>? getMemoriesCompleter;
  Object? failure;

  @override
  Future<List<MemoryReadModel>> getMemories(String storyId) async {
    getMemoriesCalls += 1;

    final completer = getMemoriesCompleter;
    if (completer != null) {
      getMemoriesCompleter = null;
      return completer.future;
    }

    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }

    return memoriesResult;
  }

  @override
  Future<MemoryReadModel> getMemory(String memoryId) async {
    throw UnimplementedError();
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    throw UnimplementedError();
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) async {
    throw UnimplementedError();
  }
}

final class UnexpectedStoryException implements Exception {
  const UnexpectedStoryException();
}
