import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/memory_details_notifier.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';
import 'package:memory_map/features/memory/presentation/memory_date_format.dart';
import 'package:memory_map/features/memory/presentation/memory_details_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('MemoryDetailsScreen rendering', () {
    testWidgets('shouldRenderEnglishMemoryDetails', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()..memoryResult = memoryA,
      );

      expect(find.text('Memory'), findsOneWidget);
      expect(find.text('First picnic'), findsOneWidget);
      expect(find.text('Memory note'), findsOneWidget);
      expect(find.text('Near the river'), findsOneWidget);
      expect(find.text('Place'), findsOneWidget);
      expect(find.text('Riverside Park'), findsOneWidget);
      expect(find.text('Aug 9, 2026'), findsOneWidget);
    });

    testWidgets('shouldRenderRussianMemoryDetails', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()..memoryResult = memoryA,
        locale: const Locale('ru'),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(MemoryDetailsScreen)),
      );

      expect(find.text(l10n.memoryDetailsPageTitle), findsOneWidget);
      expect(find.text(l10n.memoryDetailsDescriptionTitle), findsOneWidget);
      expect(find.text(l10n.memoryDetailsPlaceTitle), findsOneWidget);
      expect(
        find.text(formatMemoryDate(l10n, memoryA.eventDate)),
        findsOneWidget,
      );
    });

    testWidgets('shouldRenderNullableFieldsWithPlaceholders', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..memoryResult = memory(
            title: 'Memory without optional fields',
            description: null,
            placeName: '   ',
          ),
      );

      expect(find.text('Memory without optional fields'), findsOneWidget);
      expect(find.text('No description yet.'), findsOneWidget);
      expect(find.text('No place name yet.'), findsOneWidget);
      expect(find.text('null'), findsNothing);
      expect(find.text('   '), findsNothing);
    });
  });

  group('MemoryDetailsScreen loading and failures', () {
    testWidgets('shouldRenderInitialLoadingWithoutFakeMemory', (tester) async {
      final completer = Completer<Memory>();
      final repository = FakeMemoryRepository()..getMemoryCompleter = completer;

      await pumpScreen(tester, repository, settle: false);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('memory-details.loading-view')),
        findsOneWidget,
      );
      expect(find.text('First picnic'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);

      completer.complete(memoryA);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRenderKnownLoadFailureSafelyAndRetry', (tester) async {
      final repository = FakeMemoryRepository()
        ..getMemoryFailures.add(
          const MemoryApplicationException(MemoryNotFound()),
        )
        ..memoryResult = memoryA;
      await pumpScreen(tester, repository);

      expect(find.text('Could not load memory'), findsOneWidget);
      expect(find.text('Memory is unavailable.'), findsOneWidget);
      expect(find.textContaining('MemoryApplicationException'), findsNothing);
      expect(find.textContaining('private-memory-id'), findsNothing);

      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.error.retry-action')),
      );

      expect(repository.getMemoryCalls, 2);
      expect(find.text('First picnic'), findsOneWidget);
    });

    testWidgets('shouldRenderUnauthorizedKnownFailureSafely', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..getMemoryFailures.add(
            const MemoryApplicationException(MemoryUnauthorized()),
          ),
      );

      expect(find.text('Could not load memory'), findsOneWidget);
      expect(
        find.text('Your session needs attention. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('401'), findsNothing);
      expect(find.textContaining('Forbidden'), findsNothing);
    });

    testWidgets('shouldRenderUnexpectedAsyncErrorSafely', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..getMemoryFailures.add(const UnexpectedMemoryException()),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('UnexpectedMemoryException'), findsNothing);
      expect(find.textContaining('StackTrace'), findsNothing);
      expect(find.textContaining('SECRET'), findsNothing);
    });
  });

  group('MemoryDetailsScreen refresh', () {
    testWidgets('shouldKeepContentVisibleWhileRefreshing', (tester) async {
      final refreshCompleter = Completer<Memory>();
      final repository = FakeMemoryRepository()..memoryResult = memoryA;
      final container = await pumpScreen(tester, repository);
      repository.getMemoryCompleter = refreshCompleter;

      final refresh = container
          .read(memoryDetailsProvider(defaultMemoryId).notifier)
          .refreshMemory();
      await tester.pump();

      expect(find.text('First picnic'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      refreshCompleter.complete(memoryB);
      await refresh;
      await tester.pumpAndSettle();

      expect(find.text('Beach morning'), findsOneWidget);
      expect(find.text('First picnic'), findsNothing);
    });

    testWidgets('shouldRefreshFromExplicitRefreshAction', (tester) async {
      final repository = FakeMemoryRepository()..memoryResult = memoryA;
      await pumpScreen(tester, repository);
      repository.memoryResult = memoryB;

      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.refresh-action')),
      );

      expect(repository.getMemoryCalls, 2);
      expect(find.text('Beach morning'), findsOneWidget);
    });

    testWidgets('shouldRenderRefreshFailureBannerAndRetry', (tester) async {
      final repository = FakeMemoryRepository()..memoryResult = memoryA;
      await pumpScreen(tester, repository);
      repository.getMemoryFailures.add(
        const MemoryApplicationException(MemoryRequestTimedOut()),
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.refresh-action')),
      );

      expect(find.text('First picnic'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('memory-details.refresh.failure-banner')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Could not refresh memory. The request timed out. Please try again.',
        ),
        findsOneWidget,
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.refresh.retry-action')),
      );

      expect(repository.getMemoryCalls, 3);
    });
  });

  group('MemoryDetailsScreen callbacks and security', () {
    testWidgets('shouldCallBackAndEditWithoutRepositoryWrites', (
      tester,
    ) async {
      var backCalls = 0;
      Memory? editedMemory;
      final repository = FakeMemoryRepository()..memoryResult = memoryA;
      await pumpScreen(
        tester,
        repository,
        onBack: () {
          backCalls += 1;
        },
        onEdit: (memory) {
          editedMemory = memory;
        },
        onDelete: (_) {},
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.back-action')),
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.edit-action')),
      );

      expect(backCalls, 2);
      expect(editedMemory, same(memoryA));
      expect(repository.createMemoryCalls, 0);
      expect(repository.updateMemoryCalls, 0);
      expect(repository.deleteMemoryCalls, 0);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('shouldHideEditAndDeleteActionsWhenCallbacksAreNull', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()..memoryResult = memoryA,
      );

      expect(
        find.byKey(const ValueKey('memory-details.edit-action')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('memory-details.delete-card')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('memory-details.delete-action')),
        findsNothing,
      );
    });

    testWidgets('shouldNotOverflowOnSmallPhoneWithLargeText', (tester) async {
      setSurface(tester, const Size(360, 640));

      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..memoryResult = memory(
            title: 'A very long memory title that should wrap without overflow',
            description:
                'A longer visible description that should stay readable on a '
                'small phone with larger text settings.',
            placeName: 'A very long place name that should fit gracefully',
          ),
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
          ..memoryResult = memory(
            id: 'private-memory-id',
            storyId: 'private-story-id',
            createdBy: 'private-user-id',
            title: 'Visible private memory',
            description: 'Visible private description',
            placeName: 'Visible private place',
          ),
        memoryId: 'private-memory-id',
      );

      expect(find.text('Visible private memory'), findsOneWidget);
      expect(find.text('Visible private description'), findsOneWidget);
      expect(find.text('Visible private place'), findsOneWidget);
      expect(find.textContaining('private-memory-id'), findsNothing);
      expect(find.textContaining('private-story-id'), findsNothing);
      expect(find.textContaining('private-user-id'), findsNothing);
      expect(find.textContaining('41.715123'), findsNothing);
      expect(find.textContaining('44.827456'), findsNothing);
      expect(find.textContaining('2026-08-09'), findsNothing);
      expect(find.textContaining('createdBy'), findsNothing);
      expect(find.textContaining('createdAt'), findsNothing);
      expect(find.textContaining('updatedAt'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
      expect(find.textContaining('HTTP'), findsNothing);
      expect(find.textContaining('ProblemDetail'), findsNothing);
      expect(find.textContaining('accessToken'), findsNothing);
    });
  });

  group('MemoryDetailsScreen delete flow', () {
    testWidgets('shouldOpenDeleteConfirmationAndCancelWithoutBackendCall', (
      tester,
    ) async {
      Memory? deletedMemory;
      final repository = FakeMemoryRepository()..memoryResult = memoryA;
      await pumpScreen(
        tester,
        repository,
        onDelete: (memory) {
          deletedMemory = memory;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete-action')),
      );

      expect(find.text('Delete memory?'), findsOneWidget);
      expect(
        find.text(
          'This memory will be permanently deleted. This action cannot be undone.',
        ),
        findsOneWidget,
      );
      expect(repository.deleteMemoryCalls, 0);

      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete.cancel-action')),
      );

      expect(find.byType(AlertDialog), findsNothing);
      expect(repository.deleteMemoryCalls, 0);
      expect(deletedMemory, isNull);
    });

    testWidgets('shouldConfirmDeleteAfterBackendSuccessAndCallCallbackOnce', (
      tester,
    ) async {
      var callbackCalls = 0;
      Memory? deletedMemory;
      final repository = FakeMemoryRepository()..memoryResult = memoryA;
      await pumpScreen(
        tester,
        repository,
        onDelete: (memory) {
          callbackCalls += 1;
          deletedMemory = memory;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete.confirm-action')),
      );

      expect(repository.deleteMemoryCalls, 1);
      expect(
        repository.receivedDeleteInput,
        DeleteMemoryInput(memoryId: memoryA.id),
      );
      expect(callbackCalls, 1);
      expect(deletedMemory, same(memoryA));
      expect(
        tester.widget<OutlinedButton>(
          find.byKey(const ValueKey('memory-details.delete-action')),
        ).onPressed,
        isNull,
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete-action')),
      );

      expect(repository.deleteMemoryCalls, 1);
      expect(callbackCalls, 1);
    });

    testWidgets('shouldNotCallSuccessCallbackBeforeBackendCompletion', (
      tester,
    ) async {
      final completer = Completer<void>();
      Memory? deletedMemory;
      final repository = FakeMemoryRepository()
        ..memoryResult = memoryA
        ..deleteCompleter = completer;
      await pumpScreen(
        tester,
        repository,
        onBack: () {},
        onEdit: (_) {},
        onDelete: (memory) {
          deletedMemory = memory;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete.confirm-action')),
        settle: false,
      );
      await tester.pump();

      expect(find.text('Deleting memory...'), findsOneWidget);
      expect(deletedMemory, isNull);
      expect(repository.deleteMemoryCalls, 1);
      expect(
        tester.widget<IconButton>(
          find.byKey(const ValueKey('memory-details.back-action')),
        ).onPressed,
        isNull,
      );
      expect(
        tester.widget<IconButton>(
          find.byKey(const ValueKey('memory-details.refresh-action')),
        ).onPressed,
        isNull,
      );
      expect(
        tester.widget<IconButton>(
          find.byKey(const ValueKey('memory-details.edit-action')),
        ).onPressed,
        isNull,
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete-action')),
        settle: false,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(repository.deleteMemoryCalls, 1);
      expect(deletedMemory, isNull);

      completer.complete();
      await tester.pumpAndSettle();

      expect(deletedMemory, same(memoryA));
    });

    testWidgets('shouldRenderKnownDeleteFailureSafelyAndPreserveDetails', (
      tester,
    ) async {
      Memory? deletedMemory;
      final repository = FakeMemoryRepository()
        ..memoryResult = memoryA
        ..deleteFailure = const MemoryApplicationException(
          MemoryDeletionUnavailable(),
        );
      await pumpScreen(
        tester,
        repository,
        onDelete: (memory) {
          deletedMemory = memory;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete.confirm-action')),
      );

      expect(
        find.byKey(const ValueKey('memory-details.delete.failure-banner')),
        findsOneWidget,
      );
      expect(find.text('Memory cannot be deleted from here.'), findsOneWidget);
      expect(find.text('First picnic'), findsOneWidget);
      expect(deletedMemory, isNull);
      expect(find.textContaining('MemoryApplicationException'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
      expect(find.textContaining('HTTP'), findsNothing);
    });

    testWidgets('shouldRenderUnexpectedDeleteFailureSafelyAndAllowRetry', (
      tester,
    ) async {
      Memory? deletedMemory;
      final repository = FakeMemoryRepository()
        ..memoryResult = memoryA
        ..deleteFailure = const UnexpectedMemoryException();
      await pumpScreen(
        tester,
        repository,
        onDelete: (memory) {
          deletedMemory = memory;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete.confirm-action')),
      );

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('UnexpectedMemoryException'), findsNothing);
      expect(deletedMemory, isNull);

      repository.deleteFailure = null;
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete.confirm-action')),
      );

      expect(repository.deleteMemoryCalls, 2);
      expect(deletedMemory, same(memoryA));
    });

    testWidgets('shouldKeepDeleteDialogFreeOfIdsCoordinatesAndRawDetails', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository()
          ..memoryResult = memory(
            id: 'private-memory-id',
            storyId: 'private-story-id',
            createdBy: 'private-user-id',
            title: 'Visible private memory',
            description: 'Visible private description',
            placeName: 'Visible private place',
          ),
        memoryId: 'private-memory-id',
        onDelete: (_) {},
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-details.delete-action')),
      );

      expect(find.text('Delete memory?'), findsOneWidget);
      expect(find.textContaining('private-memory-id'), findsNothing);
      expect(find.textContaining('private-story-id'), findsNothing);
      expect(find.textContaining('private-user-id'), findsNothing);
      expect(find.textContaining('41.715123'), findsNothing);
      expect(find.textContaining('44.827456'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
      expect(find.textContaining('HTTP'), findsNothing);
      expect(find.textContaining('accessToken'), findsNothing);
    });
  });
}

Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  FakeMemoryRepository repository, {
  String memoryId = defaultMemoryId,
  Locale locale = const Locale('en'),
  VoidCallback? onBack,
  ValueChanged<Memory>? onEdit,
  ValueChanged<Memory>? onDelete,
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
        home: MemoryDetailsScreen(
          memoryId: memoryId,
          onBack: onBack,
          onEdit: onEdit,
          onDelete: onDelete,
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
  await tester.pump();
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
  String id = defaultMemoryId,
  String storyId = 'story-id',
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
    location: MemoryLocation(latitude: 41.715123, longitude: 44.827456),
    eventDate: MemoryDate(year: 2026, month: 8, day: day),
    createdAt: DateTime.utc(2026, 8, 9, createdHour),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

const String defaultMemoryId = '00000000-0000-0000-0000-000000000001';

final Memory memoryA = memory(
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

final class FakeMemoryRepository implements MemoryRepository {
  int getMemoriesCalls = 0;
  int getMemoryCalls = 0;
  int createMemoryCalls = 0;
  int updateMemoryCalls = 0;
  int deleteMemoryCalls = 0;
  Completer<Memory>? getMemoryCompleter;
  Completer<void>? deleteCompleter;
  DeleteMemoryInput? receivedDeleteInput;
  Memory memoryResult = memoryA;
  final List<Object> getMemoryFailures = <Object>[];
  final List<String> receivedMemoryIds = <String>[];
  Object? deleteFailure;

  @override
  Future<List<Memory>> getMemories(String storyId) async {
    getMemoriesCalls += 1;

    return <Memory>[];
  }

  @override
  Future<Memory> getMemory(String memoryId) async {
    getMemoryCalls += 1;
    receivedMemoryIds.add(memoryId);

    final configuredCompleter = getMemoryCompleter;
    if (configuredCompleter != null) {
      getMemoryCompleter = null;
      return configuredCompleter.future;
    }

    if (getMemoryFailures.isNotEmpty) {
      throw getMemoryFailures.removeAt(0);
    }

    return memoryResult;
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    createMemoryCalls += 1;

    return memoryResult;
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    updateMemoryCalls += 1;

    return memoryResult;
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) async {
    deleteMemoryCalls += 1;
    receivedDeleteInput = input;

    final completer = deleteCompleter;
    if (completer != null) {
      deleteCompleter = null;
      return completer.future;
    }

    final failure = deleteFailure;
    if (failure != null) {
      throw failure;
    }
  }
}

final class UnexpectedMemoryException implements Exception {
  const UnexpectedMemoryException();
}
