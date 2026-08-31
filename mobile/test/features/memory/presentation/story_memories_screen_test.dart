import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';
import 'package:memory_map/features/memory/presentation/story_memories_route.dart';
import 'package:memory_map/features/memory/presentation/story_memories_screen.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_photo_preview.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/l10n/app_localizations.dart';

import '../../media/media_test_fixtures.dart' as media_fixtures;

void main() {
  group('StoryMemoriesScreen header', () {
    testWidgets('shouldRenderStoryTitleAuthoritativeCountAndPreview', (
      tester,
    ) async {
      final storyRepository = FakeStoryRepository()
        ..storyResult = userStory(
          title: 'Our story',
          memoryCount: 24,
          previewPhoto: storyPreviewPhoto(mediaId: 'story-media'),
        );
      final memoryRepository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA];
      final mediaRepository = media_fixtures.FakeMediaRepository();

      await pumpScreen(
        tester,
        memoryRepository,
        storyRepository: storyRepository,
        mediaRepository: mediaRepository,
      );

      expect(find.text('Our story'), findsOneWidget);
      expect(find.text('24 memories'), findsOneWidget);
      expect(find.text('Story memories'), findsNothing);
      expect(
        find.byKey(const ValueKey('story-memories.refresh-action')),
        findsNothing,
      );
      expect(mediaRepository.receivedBinaryPaths, contains(
        '/api/v1/media/story-media/thumbnail',
      ));
      expect(memoryRepository.receivedStoryIds, <String>[defaultStoryId]);
      expect(storyRepository.receivedGetStoryIds, <String>[defaultStoryId]);
    });

    testWidgets('shouldRenderNoStoryPreviewFallback', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()..memoriesResult = <Memory>[memoryA],
        storyRepository: FakeStoryRepository()
          ..storyResult = userStory(title: 'Quiet archive', memoryCount: 1),
      );

      expect(find.text('Quiet archive'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-memories.header.no-photo')),
        findsOneWidget,
      );
    });

    testWidgets('shouldKeepMemoriesVisibleWhileStoryHeaderIsLoading', (
      tester,
    ) async {
      final storyCompleter = Completer<UserStory>();
      final storyRepository = FakeStoryRepository()
        ..getStoryCompleter = storyCompleter;

      await pumpScreen(
        tester,
        FakeMemoryRepository()..memoriesResult = <Memory>[memoryA],
        storyRepository: storyRepository,
        settle: false,
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('story-memories.header.thumbnail-loading')),
        findsOneWidget,
      );
      expect(find.text('First picnic'), findsOneWidget);

      storyCompleter.complete(ownerStory);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldTreatStoryThumbnailFailureAsSafeFallback', (
      tester,
    ) async {
      final mediaRepository = media_fixtures.FakeMediaRepository()
        ..thumbnailFailure = Object();

      await pumpScreen(
        tester,
        FakeMemoryRepository()..memoriesResult = <Memory>[memoryA],
        storyRepository: FakeStoryRepository()
          ..storyResult = userStory(
            previewPhoto: storyPreviewPhoto(mediaId: 'broken-story-media'),
          ),
        mediaRepository: mediaRepository,
      );

      expect(find.text('First picnic'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-memories.header.no-photo')),
        findsOneWidget,
      );
    });
  });

  group('StoryMemoriesScreen grouped list', () {
    testWidgets('shouldRenderYearsNewestFirstWithCanonicalOrderInsideYear', (
      tester,
    ) async {
      final older = memory(
        id: 'memory-2026-older',
        title: 'August picnic',
        year: 2026,
        month: 8,
        day: 3,
      );
      final newer = memory(
        id: 'memory-2026-newer',
        title: 'August beach',
        year: 2026,
        month: 8,
        day: 11,
      );
      final previousYear = memory(
        id: 'memory-2025',
        title: 'Winter lights',
        year: 2025,
        month: 12,
        day: 1,
      );

      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..memoriesResult = <Memory>[newer, previousYear, older],
      );

      expect(find.text('2026'), findsOneWidget);
      expect(find.text('2025'), findsOneWidget);
      expect(find.text('2 memories'), findsOneWidget);
      expect(find.text('1 memory'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('2026')).dy,
        lessThan(tester.getTopLeft(find.text('2025')).dy),
      );
      expect(
        tester.getTopLeft(find.text('August picnic')).dy,
        lessThan(tester.getTopLeft(find.text('August beach')).dy),
      );
    });

    testWidgets('shouldRenderRussianYearCountsAndDates', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..memoriesResult = <Memory>[
            memoryA,
            memory(id: 'memory-b', title: 'Вечер', day: 10),
          ],
        locale: const Locale('ru'),
      );

      expect(find.text('2 воспоминания'), findsOneWidget);
      expect(find.text('9 авг. 2026 г.'), findsOneWidget);
    });

    testWidgets('shouldRenderCardsWithPreviewNoPhotoTitleDateAndPlace', (
      tester,
    ) async {
      final mediaRepository = media_fixtures.FakeMediaRepository();
      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..readModelsResult = <MemoryReadModel>[
            readModel(
              memoryA,
              previewPhoto: memoryPreviewPhoto(mediaId: 'memory-media'),
            ),
            readModel(memoryC),
          ],
        mediaRepository: mediaRepository,
      );

      expect(find.text('First picnic'), findsOneWidget);
      expect(find.text('Riverside Park'), findsOneWidget);
      expect(find.text('Aug 9, 2026'), findsOneWidget);
      expect(find.text('Quiet evening'), findsOneWidget);
      expect(find.text('Near the river'), findsNothing);
      expect(find.textContaining('/api/v1/media'), findsNothing);
      expect(find.text('Travel'), findsNothing);
      expect(find.text('Nature'), findsNothing);
      expect(
        find.byKey(const ValueKey('story-memories.no-photo-preview')),
        findsOneWidget,
      );
      expect(mediaRepository.receivedBinaryPaths, contains(
        '/api/v1/media/memory-media/thumbnail',
      ));
      expect(mediaRepository.getMediaCalls, 0);
    });

    testWidgets('shouldRenderThumbnailFailureWithNoPhotoGeometry', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..readModelsResult = <MemoryReadModel>[
            readModel(
              memoryA,
              previewPhoto: memoryPreviewPhoto(mediaId: 'broken-memory-media'),
            ),
          ],
        mediaRepository: media_fixtures.FakeMediaRepository()
          ..thumbnailFailure = Object(),
      );

      expect(find.text('First picnic'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-memories.no-photo-preview')),
        findsOneWidget,
      );
    });

    testWidgets('shouldHideBlankPlaceAndRawPrivateDetails', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..memoriesResult = <Memory>[
            memory(
              id: 'private-memory-id',
              storyId: 'private-story-id',
              createdBy: 'private-user-id',
              title: 'Visible private memory',
              description: 'Visible private description',
              placeName: '   ',
            ),
          ],
        storyId: 'private-story-id',
        storyRepository: FakeStoryRepository()
          ..storyResult = userStory(id: 'private-story-id'),
      );

      expect(find.text('Visible private memory'), findsOneWidget);
      expect(find.text('   '), findsNothing);
      expect(find.textContaining('private-memory-id'), findsNothing);
      expect(find.textContaining('private-story-id'), findsNothing);
      expect(find.textContaining('private-user-id'), findsNothing);
      expect(find.textContaining('Visible private description'), findsNothing);
      expect(find.textContaining('55.751244'), findsNothing);
      expect(find.textContaining('37.618423'), findsNothing);
      expect(find.textContaining('createdAt'), findsNothing);
      expect(find.textContaining('updatedAt'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
      expect(find.textContaining('HTTP'), findsNothing);
      expect(find.textContaining('ProblemDetail'), findsNothing);
      expect(find.textContaining('accessToken'), findsNothing);
    });
  });

  group('StoryMemoriesScreen loading and failures', () {
    testWidgets('shouldRenderInitialLoadingWithoutFakeMemories', (
      tester,
    ) async {
      final completer = Completer<List<Memory>>();
      final repository = FakeMemoryRepository()..getCompleter = completer;

      await pumpScreen(tester, repository, settle: false);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('story-memories.loading-view')),
        findsOneWidget,
      );
      expect(find.text('First picnic'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);

      completer.complete(<Memory>[memoryA]);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRenderEmptyStateAndCreateActionWhenCallbackExists', (
      tester,
    ) async {
      var createCalls = 0;
      await pumpScreen(
        tester,
        FakeMemoryRepository()..memoriesResult = <Memory>[],
        onCreateMemory: () {
          createCalls += 1;
        },
      );

      expect(find.text('No memories yet'), findsOneWidget);
      expect(find.text('2026'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('story-memories.empty.create-action')),
      );
      await tester.pump();

      expect(createCalls, 1);
    });

    testWidgets('shouldRenderKnownLoadFailureSafelyAndRetry', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..getFailures.add(
          const MemoryApplicationException(MemoryStoryUnavailable()),
        )
        ..memoriesResult = <Memory>[memoryA];
      await pumpScreen(tester, repository);

      expect(find.text('Could not load memories'), findsOneWidget);
      expect(find.text('Story memories are unavailable.'), findsOneWidget);
      expect(find.textContaining('MemoryApplicationException'), findsNothing);

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-memories.error.retry-action')),
      );

      expect(repository.getMemoriesCalls, 2);
      expect(find.text('First picnic'), findsOneWidget);
    });

    testWidgets('shouldRenderUnexpectedAsyncErrorSafely', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..getFailures.add(const UnexpectedMemoryException()),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('UnexpectedMemoryException'), findsNothing);
      expect(find.textContaining('StackTrace'), findsNothing);
    });
  });

  group('StoryMemoriesScreen refresh', () {
    testWidgets('shouldKeepContentVisibleWhileRefreshing', (tester) async {
      final refreshCompleter = Completer<List<Memory>>();
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA];
      final container = await pumpScreen(tester, repository);
      repository.getCompleter = refreshCompleter;

      final refresh = container
          .read(storyMemoriesProvider(defaultStoryId).notifier)
          .refreshMemories();
      await tester.pump();

      expect(find.text('First picnic'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      refreshCompleter.complete(<Memory>[memoryB]);
      await refresh;
      await tester.pumpAndSettle();

      expect(find.text('Beach morning'), findsOneWidget);
      expect(find.text('First picnic'), findsNothing);
    });

    testWidgets('shouldRefreshThroughPullToRefreshWithoutHeaderAction', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA];
      await pumpScreen(tester, repository);
      repository.memoriesResult = <Memory>[memoryC];

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 360));
      await tester.pumpAndSettle();

      expect(repository.getMemoriesCalls, 2);
      expect(find.text('Quiet evening'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-memories.refresh-action')),
        findsNothing,
      );
    });

    testWidgets('shouldRenderRefreshFailureBannerAndRetry', (tester) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA];
      await pumpScreen(tester, repository);
      repository.getFailures.add(
        const MemoryApplicationException(MemoryRequestTimedOut()),
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 360));
      await tester.pumpAndSettle();

      expect(find.text('First picnic'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-memories.refresh.failure-banner')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Could not refresh memories. The request timed out. Please try again.',
        ),
        findsOneWidget,
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-memories.refresh.retry-action')),
      );

      expect(repository.getMemoriesCalls, 3);
    });
  });

  group('StoryMemoriesScreen callbacks and capability', () {
    testWidgets('shouldCallBackCreateAndMemorySelectedCallbacks', (
      tester,
    ) async {
      var backCalls = 0;
      var createCalls = 0;
      Memory? selectedMemory;
      await pumpScreen(
        tester,
        FakeMemoryRepository()..memoriesResult = <Memory>[memoryA],
        onBack: () {
          backCalls += 1;
        },
        onCreateMemory: () {
          createCalls += 1;
        },
        onMemorySelected: (memory) {
          selectedMemory = memory;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-memories.back-action')),
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.tap(find.text('First picnic'));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('story-memories.create-action')),
      );
      await tester.pump();

      expect(backCalls, 2);
      expect(createCalls, 1);
      expect(selectedMemory, same(memoryA));
    });

    testWidgets('shouldShowCreateActionForOwnerCoOwnerAndEditorOnly', (
      tester,
    ) async {
      for (final role in <StoryRole>[
        StoryRole.owner,
        StoryRole.coOwner,
        StoryRole.editor,
      ]) {
        await pumpRoute(
          tester,
          role: role,
          memoryRepository: FakeMemoryRepository()
            ..memoriesResult = <Memory>[],
        );

        expect(
          find.byKey(const ValueKey('story-memories.create-action')),
          findsOneWidget,
        );
      }

      await pumpRoute(
        tester,
        role: StoryRole.viewer,
        memoryRepository: FakeMemoryRepository()..memoriesResult = <Memory>[],
      );

      expect(
        find.byKey(const ValueKey('story-memories.create-action')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('story-memories.empty.create-action')),
        findsNothing,
      );
    });

    testWidgets('shouldNotOverflowOnSmallPhoneWithLargeText', (tester) async {
      setSurface(tester, const Size(360, 640));

      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..memoriesResult = <Memory>[
            memory(
              title:
                  'A very long memory title that should wrap without overflow',
              description:
                  'A longer visible description that should stay hidden on a '
                  'small phone with larger text settings.',
              placeName: 'A very long place name that should fit gracefully',
            ),
          ],
        storyRepository: FakeStoryRepository()
          ..storyResult = userStory(
            title: 'A long story title that should not overflow',
            memoryCount: 1,
          ),
        textScaler: const TextScaler.linear(1.25),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  FakeMemoryRepository memoryRepository, {
  FakeStoryRepository? storyRepository,
  media_fixtures.FakeMediaRepository? mediaRepository,
  String storyId = defaultStoryId,
  Locale locale = const Locale('en'),
  VoidCallback? onBack,
  VoidCallback? onCreateMemory,
  ValueChanged<Memory>? onMemorySelected,
  TextScaler textScaler = TextScaler.noScaling,
  bool settle = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      memoryRepositoryProvider.overrideWithValue(memoryRepository),
      storyRepositoryProvider.overrideWithValue(
        storyRepository ?? FakeStoryRepository(),
      ),
      mediaRepositoryProvider.overrideWithValue(
        mediaRepository ?? media_fixtures.FakeMediaRepository(),
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
        home: StoryMemoriesScreen(
          storyId: storyId,
          onBack: onBack,
          onCreateMemory: onCreateMemory,
          onMemorySelected: onMemorySelected,
        ),
      ),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  }

  return container;
}

Future<ProviderContainer> pumpRoute(
  WidgetTester tester, {
  required StoryRole role,
  required FakeMemoryRepository memoryRepository,
}) async {
  final container = ProviderContainer(
    overrides: [
      memoryRepositoryProvider.overrideWithValue(memoryRepository),
      storyRepositoryProvider.overrideWithValue(
        FakeStoryRepository()
          ..storyResult = userStory(
            role: role,
            memoryCount: memoryRepository.memoriesResult?.length ?? 0,
          ),
      ),
      mediaRepositoryProvider.overrideWithValue(
        media_fixtures.FakeMediaRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StoryMemoriesRoute(
          storyId: defaultStoryId,
          onCreateMemory: () {},
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

void setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

UserStory userStory({
  String id = defaultStoryId,
  String title = 'Our story',
  StoryRole role = StoryRole.owner,
  int memoryCount = 3,
  StoryPhotoPreview? previewPhoto,
}) {
  return UserStory(
    story: Story(
      id: id,
      title: title,
      description: 'Together',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    ),
    role: role,
    memoryCount: memoryCount,
    participantCount: 2,
    previewPhoto: previewPhoto,
  );
}

Memory memory({
  String id = '00000000-0000-0000-0000-000000000001',
  String storyId = defaultStoryId,
  String createdBy = 'author-id',
  String title = 'First picnic',
  String? description = 'Near the river',
  String? placeName = 'Riverside Park',
  int year = 2026,
  int month = 8,
  int day = 9,
  int createdHour = 10,
}) {
  return Memory(
    id: id,
    storyId: storyId,
    createdBy: createdBy,
    title: title,
    description: description,
    placeName: placeName,
    location: MemoryLocation(latitude: 55.751244, longitude: 37.618423),
    eventDate: MemoryDate(year: year, month: month, day: day),
    createdAt: DateTime.utc(2026, 8, 9, createdHour),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

MemoryReadModel readModel(
  Memory memory, {
  MemoryPhotoPreview? previewPhoto,
}) {
  return MemoryReadModel(memory: memory, previewPhoto: previewPhoto);
}

StoryPhotoPreview storyPreviewPhoto({
  required String mediaId,
}) {
  return StoryPhotoPreview(
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
    displayPath: '/api/v1/media/$mediaId/display',
  );
}

MemoryPhotoPreview memoryPreviewPhoto({
  required String mediaId,
}) {
  return MemoryPhotoPreview(
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}

const String defaultStoryId = 'story-id';

final UserStory ownerStory = userStory();

final Memory memoryA = memory(
  id: '00000000-0000-0000-0000-000000000001',
  title: 'First picnic',
  day: 9,
);

final Memory memoryB = memory(
  id: '00000000-0000-0000-0000-000000000002',
  title: 'Beach morning',
  description: 'Shells and sunlight',
  placeName: 'Black Sea',
  day: 15,
);

final Memory memoryC = memory(
  id: '00000000-0000-0000-0000-000000000003',
  title: 'Quiet evening',
  description: null,
  placeName: null,
  day: 20,
);

final class FakeMemoryRepository implements MemoryRepository {
  int getMemoriesCalls = 0;
  int getMemoryCalls = 0;
  int createMemoryCalls = 0;
  int updateMemoryCalls = 0;
  int deleteMemoryCalls = 0;
  Completer<List<Memory>>? getCompleter;
  List<Memory>? memoriesResult = <Memory>[];
  List<MemoryReadModel>? readModelsResult;
  final List<Object> getFailures = <Object>[];
  final List<String> receivedStoryIds = <String>[];

  @override
  Future<List<MemoryReadModel>> getMemories(String storyId) async {
    getMemoriesCalls += 1;
    receivedStoryIds.add(storyId);

    final configuredCompleter = getCompleter;
    if (configuredCompleter != null) {
      getCompleter = null;
      return configuredCompleter.future.then(_readModelsFromMemories);
    }

    if (getFailures.isNotEmpty) {
      throw getFailures.removeAt(0);
    }

    final configuredReadModels = readModelsResult;
    if (configuredReadModels != null) {
      return List<MemoryReadModel>.of(configuredReadModels);
    }

    return _readModelsFromMemories(memoriesResult ?? const <Memory>[]);
  }

  @override
  Future<MemoryReadModel> getMemory(String memoryId) async {
    getMemoryCalls += 1;
    return MemoryReadModel.fromMemory(memoryA);
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    createMemoryCalls += 1;
    return memoryA;
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    updateMemoryCalls += 1;
    return memoryA;
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) async {
    deleteMemoryCalls += 1;
  }
}

final class FakeStoryRepository implements StoryRepository {
  int createCalls = 0;
  int getStoriesCalls = 0;
  int getStoryCalls = 0;
  int updateStoryCalls = 0;

  UserStory storyResult = ownerStory;
  Completer<UserStory>? getStoryCompleter;
  final List<String> receivedGetStoryIds = <String>[];

  @override
  Future<Story> createStory({
    required String title,
    String? description,
  }) async {
    createCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<List<UserStory>> getStories() async {
    getStoriesCalls += 1;
    return <UserStory>[storyResult];
  }

  @override
  Future<UserStory> getStory(String storyId) async {
    getStoryCalls += 1;
    receivedGetStoryIds.add(storyId);

    final completer = getStoryCompleter;
    if (completer != null) {
      getStoryCompleter = null;
      return completer.future;
    }

    return storyResult;
  }

  @override
  Future<UserStory> updateStory(UpdateStoryInput input) async {
    updateStoryCalls += 1;
    return storyResult;
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

List<MemoryReadModel> _readModelsFromMemories(List<Memory> memories) {
  return memories.map(MemoryReadModel.fromMemory).toList();
}

final class UnexpectedMemoryException implements Exception {
  const UnexpectedMemoryException();
}
