import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';
import 'package:memory_map/features/memory/presentation/story_memories_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('StoryMemoriesScreen rendering', () {
    testWidgets('shouldRenderEnglishMemoryListInBackendOrder', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryB, memoryA, memoryC];
      await pumpScreen(
        tester,
        repository,
      );

      expect(find.text('Memories'), findsOneWidget);
      expect(find.text('Story memories'), findsOneWidget);
      expect(find.text('3 memories'), findsOneWidget);
      expect(find.text('Beach morning'), findsOneWidget);
      expect(find.text('First picnic'), findsOneWidget);
      expect(find.text('Quiet evening'), findsOneWidget);
      expect(find.text('Aug 15, 2026'), findsOneWidget);

      expect(
        tester.getTopLeft(find.text('Beach morning')).dy,
        lessThan(tester.getTopLeft(find.text('First picnic')).dy),
      );
      expect(
        tester.getTopLeft(find.text('First picnic')).dy,
        lessThan(tester.getTopLeft(find.text('Quiet evening')).dy),
      );
      expect(repository.receivedStoryIds, <String>[defaultStoryId]);
    });

    testWidgets('shouldRenderRussianMemoryScreen', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()..memoriesResult = <Memory>[memoryA],
        locale: const Locale('ru'),
      );

      expect(find.text('Воспоминания'), findsOneWidget);
      expect(find.text('Воспоминания истории'), findsOneWidget);
      expect(find.text('1 воспоминание'), findsOneWidget);
      expect(find.text('9 авг. 2026 г.'), findsOneWidget);
    });

    testWidgets('shouldRenderNullableFieldsSafely', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..memoriesResult = <Memory>[
            memory(
              title: 'Memory without optional fields',
              description: null,
              placeName: '   ',
            ),
          ],
      );

      expect(find.text('Memory without optional fields'), findsOneWidget);
      expect(find.text('   '), findsNothing);
      expect(find.text('Near the river'), findsNothing);
      expect(find.byIcon(Icons.place_rounded), findsNothing);
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
      expect(find.text('No memories'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('story-memories.empty.create-action')),
      );
      await tester.pump();

      expect(createCalls, 1);
    });

    testWidgets('shouldHideCreateActionsWhenCallbackIsNull', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()..memoriesResult = <Memory>[],
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

    testWidgets('shouldRefreshFromExplicitRefreshAction', (tester) async {
      final repository = FakeMemoryRepository()
        ..memoriesResult = <Memory>[memoryA];
      await pumpScreen(tester, repository);
      repository.memoriesResult = <Memory>[memoryC];

      await pressButton(
        tester,
        find.byKey(const ValueKey('story-memories.refresh-action')),
      );

      expect(repository.getMemoriesCalls, 2);
      expect(find.text('Quiet evening'), findsOneWidget);
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

  group('StoryMemoriesScreen callbacks and security', () {
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
                  'A longer visible description that should stay readable on a '
                  'small phone with larger text settings.',
              placeName: 'A very long place name that should fit gracefully',
            ),
          ],
        textScaler: const TextScaler.linear(1.25),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('shouldNotRenderIdsCoordinatesOrRawBackendDetails', (
      tester,
    ) async {
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
              placeName: 'Visible private place',
            ),
          ],
        storyId: 'private-story-id',
      );

      expect(find.textContaining('private-memory-id'), findsNothing);
      expect(find.textContaining('private-story-id'), findsNothing);
      expect(find.textContaining('private-user-id'), findsNothing);
      expect(find.textContaining('Visible private description'), findsNothing);
      expect(find.textContaining('55.751244'), findsNothing);
      expect(find.textContaining('37.618423'), findsNothing);
      expect(find.textContaining('createdBy'), findsNothing);
      expect(find.textContaining('createdAt'), findsNothing);
      expect(find.textContaining('updatedAt'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
      expect(find.textContaining('HTTP'), findsNothing);
      expect(find.textContaining('ProblemDetail'), findsNothing);
      expect(find.textContaining('accessToken'), findsNothing);
    });
  });
}

Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  FakeMemoryRepository repository, {
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
      memoryRepositoryProvider.overrideWithValue(repository),
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

Memory memory({
  String id = '00000000-0000-0000-0000-000000000001',
  String storyId = defaultStoryId,
  String createdBy = 'author-id',
  String title = 'First picnic',
  String? description = 'Near the river',
  String? placeName = 'Riverside Park',
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
    eventDate: MemoryDate(year: 2026, month: 8, day: day),
    createdAt: DateTime.utc(2026, 8, 9, createdHour),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

const String defaultStoryId = 'story-id';

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
  List<Memory> memoriesResult = <Memory>[];
  final List<Object> getFailures = <Object>[];
  final List<String> receivedStoryIds = <String>[];

  @override
  Future<List<Memory>> getMemories(String storyId) async {
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

    return memoriesResult;
  }

  @override
  Future<Memory> getMemory(String memoryId) async {
    getMemoryCalls += 1;
    return memoryA;
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

final class UnexpectedMemoryException implements Exception {
  const UnexpectedMemoryException();
}
