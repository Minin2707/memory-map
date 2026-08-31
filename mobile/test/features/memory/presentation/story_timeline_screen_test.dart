import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
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
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';
import 'package:memory_map/features/memory/presentation/story_timeline_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

import '../../media/media_test_fixtures.dart' as media_fixtures;

void main() {
  group('StoryTimelineScreen rendering', () {
    testWidgets('shouldRenderTimelineWithNewestYearsFirst', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..readModelsResult = <MemoryReadModel>[
            readModel(memory2023),
            readModel(memory2024B),
            readModel(memory2024A),
          ],
      );

      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Map'), findsNothing);
      expect(find.text('Stats'), findsNothing);
      expect(
        find.byKey(const ValueKey('story-timeline.tabs')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('story-timeline.refresh-action')),
        findsOneWidget,
      );
      expect(find.text('2024'), findsOneWidget);
      expect(find.text('Family picnic'), findsOneWidget);
      expect(find.text('2023'), findsNothing);

      await scrollDownUntilFound(tester, find.text('Birthday walk'));
      expect(find.text('Birthday walk'), findsOneWidget);

      await scrollDownUntilFound(tester, find.text('2023'));
      expect(find.text('2023'), findsOneWidget);

      await scrollDownUntilFound(tester, find.text('Winter lights'));
      expect(find.text('Winter lights'), findsOneWidget);
    });

    testWidgets('shouldRenderStoryTitleWhenProvidedWithoutStoryLookup', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()..readModelsResult = <MemoryReadModel>[],
        storyTitle: 'Our story',
      );

      expect(find.text('Our story'), findsOneWidget);
      expect(find.text('Timeline'), findsNothing);
    });

    testWidgets('shouldRenderRussianTimelineCopy', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()..readModelsResult = <MemoryReadModel>[],
        locale: const Locale('ru'),
      );

      expect(find.text('Хронология'), findsOneWidget);
      expect(find.text('Карта'), findsNothing);
      expect(find.text('Статистика'), findsNothing);
      expect(find.text('Хронология пока пуста'), findsOneWidget);
    });

    testWidgets('shouldRenderOptionalFieldsSafely', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..readModelsResult = <MemoryReadModel>[
            readModel(
              memory(
                id: 'memory-no-optionals',
                title: 'No optional fields',
                description: null,
                placeName: '   ',
              ),
            ),
          ],
      );

      expect(find.text('No optional fields'), findsOneWidget);
      expect(find.text('   '), findsNothing);
      expect(find.text('Visible description'), findsNothing);
      expect(find.byIcon(Icons.place_rounded), findsNothing);
    });
  });

  group('StoryTimelineScreen thumbnails', () {
    testWidgets('shouldLoadRealThumbnailThroughBackendPathOnly', (
      tester,
    ) async {
      final mediaRepository = media_fixtures.FakeMediaRepository()
        ..thumbnailResult = media_fixtures.validPngBytes;

      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..readModelsResult = <MemoryReadModel>[
            readModel(
              memory2024A,
              previewPhoto: previewPhoto(mediaId: 'media-a'),
            ),
          ],
        mediaRepository: mediaRepository,
      );

      expect(mediaRepository.getThumbnailByPathCalls, 1);
      expect(mediaRepository.receivedBinaryPaths, <String>[
        '/api/v1/media/media-a/thumbnail',
      ]);
      expect(mediaRepository.getThumbnailCalls, 0);
      expect(mediaRepository.getDisplayCalls, 0);
      expect(mediaRepository.getMediaCalls, 0);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('shouldUseIntentionalNoPhotoStateWhenPreviewIsAbsent', (
      tester,
    ) async {
      final mediaRepository = media_fixtures.FakeMediaRepository();

      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..readModelsResult = <MemoryReadModel>[readModel(memory2024A)],
        mediaRepository: mediaRepository,
      );

      expect(
        find.byKey(const ValueKey('story-timeline.no-photo-visual')),
        findsOneWidget,
      );
      expect(mediaRepository.getThumbnailByPathCalls, 0);
      expect(mediaRepository.getMediaCalls, 0);
      expect(mediaRepository.getDisplayCalls, 0);
    });

    testWidgets('shouldKeepCardVisibleWhenThumbnailFails', (tester) async {
      final mediaRepository = media_fixtures.FakeMediaRepository()
        ..thumbnailFailure = StateError('binary failed');

      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..readModelsResult = <MemoryReadModel>[
            readModel(
              memory2024A,
              previewPhoto: previewPhoto(mediaId: 'media-a'),
            ),
          ],
        mediaRepository: mediaRepository,
      );

      expect(find.text('Family picnic'), findsOneWidget);
      expect(find.text('Central Park'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-timeline.no-photo-visual')),
        findsOneWidget,
      );
      expect(find.textContaining('binary failed'), findsNothing);
    });
  });

  group('StoryTimelineScreen loading and failures', () {
    testWidgets('shouldRenderInitialLoadingWithoutFakeTimelineItems', (
      tester,
    ) async {
      final completer = Completer<List<MemoryReadModel>>();
      final repository = FakeMemoryRepository()..getCompleter = completer;

      await pumpScreen(tester, repository, settle: false);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('story-timeline.loading-view')),
        findsOneWidget,
      );
      expect(find.text('Family picnic'), findsNothing);

      completer.complete(<MemoryReadModel>[readModel(memory2024A)]);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRenderEmptyStateAndCreateActionWhenCallbackExists', (
      tester,
    ) async {
      var createCalls = 0;

      await pumpScreen(
        tester,
        FakeMemoryRepository()..readModelsResult = <MemoryReadModel>[],
        onCreateMemory: () {
          createCalls += 1;
        },
      );

      expect(find.text('No timeline yet'), findsOneWidget);
      expect(find.text('Add memory'), findsNWidgets(2));

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-timeline.empty.create-action')),
      );

      expect(createCalls, 1);
    });

    testWidgets('shouldHideCreateActionsWhenCallbackIsNull', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()..readModelsResult = <MemoryReadModel>[],
      );

      expect(
        find.byKey(const ValueKey('story-timeline.create-action')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('story-timeline.empty.create-action')),
        findsNothing,
      );
    });

    testWidgets('shouldRenderKnownLoadFailureSafelyAndRetry', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..getFailures.add(
          const MemoryApplicationException(MemoryStoryUnavailable()),
        )
        ..readModelsResult = <MemoryReadModel>[readModel(memory2024A)];

      await pumpScreen(tester, repository);

      expect(find.text('Could not load timeline'), findsOneWidget);
      expect(find.text('Story memories are unavailable.'), findsOneWidget);
      expect(find.textContaining('MemoryApplicationException'), findsNothing);

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-timeline.error.retry-action')),
      );

      expect(repository.getMemoriesCalls, 2);
      expect(find.text('Family picnic'), findsOneWidget);
    });

    testWidgets('shouldKeepTimelineVisibleOnRefreshFailureAndRetry', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..readModelsResult = <MemoryReadModel>[readModel(memory2024A)];
      final container = await pumpScreen(tester, repository);
      repository.getFailures.add(
        const MemoryApplicationException(MemoryRequestTimedOut()),
      );

      await container
          .read(storyMemoriesProvider(defaultStoryId).notifier)
          .refreshMemories();
      await tester.pumpAndSettle();

      expect(find.text('Family picnic'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-timeline.refresh.failure-banner')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Could not refresh timeline. The request timed out. Please try again.',
        ),
        findsOneWidget,
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-timeline.refresh.retry-action')),
      );

      expect(repository.getMemoriesCalls, 3);
    });
  });

  group('StoryTimelineScreen callbacks and privacy', () {
    testWidgets('shouldCallBackCreateAndMemorySelectionCallbacks', (
      tester,
    ) async {
      var backCalls = 0;
      var createCalls = 0;
      var playbackCalls = 0;
      Memory? selectedMemory;

      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..readModelsResult = <MemoryReadModel>[readModel(memory2024A)],
        onBack: () {
          backCalls += 1;
        },
        onCreateMemory: () {
          createCalls += 1;
        },
        onPlaybackSelected: () {
          playbackCalls += 1;
        },
        onMemorySelected: (memory) {
          selectedMemory = memory;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-timeline.back-action')),
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      await pressButton(
        tester,
        find.byKey(const ValueKey('story-timeline.playback-action')),
      );
      await tester.ensureVisible(find.text('Family picnic'));
      await tester.tap(find.text('Family picnic'));
      await tester.pump();
      await pressButton(
        tester,
        find.byKey(const ValueKey('story-timeline.create-action')),
      );

      expect(backCalls, 2);
      expect(createCalls, 1);
      expect(playbackCalls, 1);
      expect(selectedMemory, same(memory2024A));
    });

    testWidgets('shouldHidePlaybackActionWhenCallbackIsNull', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..readModelsResult = <MemoryReadModel>[readModel(memory2024A)],
      );

      expect(
        find.byKey(const ValueKey('story-timeline.playback-action')),
        findsNothing,
      );
    });

    testWidgets('shouldNotOverflowOnSmallPhoneWithLargeText', (tester) async {
      setSurface(tester, const Size(360, 640));

      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..readModelsResult = <MemoryReadModel>[
            readModel(
              memory(
                id: 'long-memory-id',
                title:
                    'A very long timeline memory title that should wrap well',
                description:
                    'A long visible description that should stay clamped and '
                    'not overflow the timeline card on a small phone.',
                placeName: 'A very long place name that should fit gracefully',
              ),
            ),
          ],
        textScaler: const TextScaler.linear(1.25),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('shouldNotRenderIdsCoordinatesTimestampsOrMediaPaths', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..readModelsResult = <MemoryReadModel>[
            readModel(
              memory(
                id: 'private-memory-id',
                storyId: 'private-story-id',
                createdBy: 'private-user-id',
                title: 'Visible private memory',
                description: 'Visible private description',
                placeName: 'Visible private place',
              ),
              previewPhoto: previewPhoto(mediaId: 'private-media-id'),
            ),
          ],
        storyId: 'private-story-id',
      );

      expect(find.text('Visible private memory'), findsOneWidget);
      expect(find.text('Visible private description'), findsOneWidget);
      expect(find.text('Visible private place'), findsOneWidget);
      expect(find.textContaining('private-memory-id'), findsNothing);
      expect(find.textContaining('private-story-id'), findsNothing);
      expect(find.textContaining('private-user-id'), findsNothing);
      expect(find.textContaining('private-media-id'), findsNothing);
      expect(find.textContaining('/api/v1/media'), findsNothing);
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

  group('StoryTimelineScreen shared resource reconciliation', () {
    testWidgets('shouldReflectSharedMemoryEditsAndDeletesWithoutExtraLookups', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..readModelsResult = <MemoryReadModel>[
          readModel(memory2024A, previewPhoto: previewPhoto(mediaId: 'media-a')),
        ];
      final container = await pumpScreen(tester, repository);

      final updatedMemory = memory(
        id: memory2024A.id,
        title: 'Edited title',
        day: 20,
      );
      container
          .read(storyMemoriesProvider(defaultStoryId).notifier)
          .upsertMemory(updatedMemory);
      await tester.pumpAndSettle();

      expect(find.text('Family picnic'), findsNothing);
      expect(find.text('Edited title'), findsOneWidget);
      expect(repository.getMemoryCalls, 0);

      container
          .read(storyMemoriesProvider(defaultStoryId).notifier)
          .removeMemoryById(updatedMemory.id);
      await tester.pumpAndSettle();

      expect(find.text('Edited title'), findsNothing);
      expect(find.text('No timeline yet'), findsOneWidget);
      expect(repository.getMemoryCalls, 0);
    });

    testWidgets('shouldReflectSharedPreviewUploadAndDeleteUpdates', (
      tester,
    ) async {
      final mediaRepository = media_fixtures.FakeMediaRepository()
        ..thumbnailResult = media_fixtures.validPngBytes;
      final repository = FakeMemoryRepository()
        ..readModelsResult = <MemoryReadModel>[readModel(memory2024A)];
      final container = await pumpScreen(
        tester,
        repository,
        mediaRepository: mediaRepository,
      );

      expect(mediaRepository.getThumbnailByPathCalls, 0);

      container
          .read(storyMemoriesProvider(defaultStoryId).notifier)
          .upsertAuthoritativeRead(
            readModel(
              memory2024A,
              previewPhoto: previewPhoto(mediaId: 'uploaded-media-id'),
            ),
          );
      await tester.pumpAndSettle();

      expect(mediaRepository.getThumbnailByPathCalls, 1);
      expect(mediaRepository.receivedBinaryPaths, <String>[
        '/api/v1/media/uploaded-media-id/thumbnail',
      ]);

      container
          .read(storyMemoriesProvider(defaultStoryId).notifier)
          .upsertAuthoritativeRead(readModel(memory2024A));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('story-timeline.no-photo-visual')),
        findsOneWidget,
      );
      expect(mediaRepository.getMediaCalls, 0);
    });
  });
}

Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  FakeMemoryRepository repository, {
  String storyId = defaultStoryId,
  String? storyTitle,
  Locale locale = const Locale('en'),
  VoidCallback? onBack,
  VoidCallback? onCreateMemory,
  VoidCallback? onPlaybackSelected,
  ValueChanged<Memory>? onMemorySelected,
  media_fixtures.FakeMediaRepository? mediaRepository,
  TextScaler textScaler = TextScaler.noScaling,
  bool settle = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      memoryRepositoryProvider.overrideWithValue(repository),
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
        home: StoryTimelineScreen(
          storyId: storyId,
          storyTitle: storyTitle,
          onBack: onBack,
          onCreateMemory: onCreateMemory,
          onPlaybackSelected: onPlaybackSelected,
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
    FloatingActionButton(:final onPressed) => onPressed,
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

Future<void> scrollDownUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxScrolls = 8,
}) async {
  for (var index = 0; index < maxScrolls; index += 1) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
    await tester.pumpAndSettle();
  }

  fail('Expected finder to become visible after scrolling: $finder');
}

MemoryReadModel readModel(
  Memory memory, {
  MemoryPhotoPreview? previewPhoto,
}) {
  return MemoryReadModel(memory: memory, previewPhoto: previewPhoto);
}

MemoryPhotoPreview previewPhoto({
  required String mediaId,
}) {
  return MemoryPhotoPreview(
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}

Memory memory({
  String id = '00000000-0000-0000-0000-000000000001',
  String storyId = defaultStoryId,
  String createdBy = 'author-id',
  String title = 'Family picnic',
  String? description = 'Visible description',
  String? placeName = 'Central Park',
  int year = 2024,
  int month = 5,
  int day = 12,
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
    createdAt: DateTime.utc(2026, 1, 1, createdHour),
    updatedAt: DateTime.utc(2026, 1, 1, 11),
  );
}

const String defaultStoryId = 'story-id';

final Memory memory2024A = memory(
  id: '00000000-0000-0000-0000-000000000001',
  title: 'Family picnic',
  year: 2024,
  month: 5,
  day: 12,
);

final Memory memory2024B = memory(
  id: '00000000-0000-0000-0000-000000000002',
  title: 'Birthday walk',
  description: 'Candles and warm weather',
  placeName: 'Old town',
  year: 2024,
  month: 6,
  day: 25,
);

final Memory memory2023 = memory(
  id: '00000000-0000-0000-0000-000000000003',
  title: 'Winter lights',
  description: null,
  placeName: null,
  year: 2023,
  month: 12,
  day: 31,
);

final class FakeMemoryRepository implements MemoryRepository {
  int getMemoriesCalls = 0;
  int getMemoryCalls = 0;
  int createMemoryCalls = 0;
  int updateMemoryCalls = 0;
  int deleteMemoryCalls = 0;
  Completer<List<MemoryReadModel>>? getCompleter;
  List<MemoryReadModel> readModelsResult = <MemoryReadModel>[];
  final List<Object> getFailures = <Object>[];
  final List<String> receivedStoryIds = <String>[];

  @override
  Future<List<MemoryReadModel>> getMemories(String storyId) async {
    getMemoriesCalls += 1;
    receivedStoryIds.add(storyId);

    final configuredCompleter = getCompleter;
    if (configuredCompleter != null) {
      getCompleter = null;
      return configuredCompleter.future;
    }

    if (getFailures.isNotEmpty) {
      throw getFailures.removeAt(0);
    }

    return readModelsResult;
  }

  @override
  Future<MemoryReadModel> getMemory(String memoryId) async {
    getMemoryCalls += 1;
    return readModel(memory2024A);
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    createMemoryCalls += 1;
    return memory2024A;
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    updateMemoryCalls += 1;
    return memory2024A;
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) async {
    deleteMemoryCalls += 1;
  }
}
