import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';
import 'package:memory_map/features/memory/presentation/create_memory_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('CreateMemoryScreen rendering', () {
    testWidgets('shouldRenderInitialEnglishFormWithoutRepositoryCall', (
      tester,
    ) async {
      final repository = FakeMemoryRepository();
      await pumpScreen(tester, repository);

      expect(find.text('Add memory'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Place name'), findsOneWidget);
      expect(find.text('Event date'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('No date selected'), findsOneWidget);
      expect(find.text('No location selected'), findsOneWidget);
      expect(find.text('Create memory'), findsOneWidget);
      expect(repository.createMemoryCalls, 0);
      expect(repository.getMemoriesCalls, 0);
    });

    testWidgets('shouldRenderRussianFormFromLocalizations', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository(),
        locale: const Locale('ru'),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CreateMemoryScreen)),
      );

      expect(find.text(l10n.createMemoryPageTitle), findsOneWidget);
      expect(find.text(l10n.createMemoryTitleLabel), findsOneWidget);
      expect(find.text(l10n.createMemorySubmitButton), findsOneWidget);
    });

    testWidgets('shouldNotOverflowOnSmallPhoneWithLargeText', (tester) async {
      setSurface(tester, const Size(360, 640));

      await pumpScreen(
        tester,
        FakeMemoryRepository(),
        textScaler: const TextScaler.linear(1.25),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('CreateMemoryScreen validation', () {
    testWidgets('shouldRequireTitleDateAndLocationBeforeRepositoryCall', (
      tester,
    ) async {
      final repository = FakeMemoryRepository();
      await pumpScreen(tester, repository);

      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.submit-action')),
      );

      expect(find.text('Enter a memory title.'), findsOneWidget);
      expect(find.text('Choose an event date.'), findsOneWidget);
      expect(find.text('Choose a location.'), findsOneWidget);
      expect(repository.createMemoryCalls, 0);
    });

    testWidgets('shouldRejectBlankTitleAndTooLongPlaceName', (tester) async {
      final repository = FakeMemoryRepository();
      await pumpScreen(
        tester,
        repository,
        datePicker: (_, __) async => futureDate,
        onPickLocation: (_) async => tbilisiLocation,
      );

      await tester.enterText(
        find.byKey(const ValueKey('create-memory.title-field')),
        '   ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('create-memory.place-name-field')),
        ''.padRight(256, 'a'),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.date-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.location-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.submit-action')),
      );

      expect(find.text('Memory title cannot be blank.'), findsOneWidget);
      expect(
        find.text('Place name must be 255 characters or fewer.'),
        findsOneWidget,
      );
      expect(repository.createMemoryCalls, 0);
    });
  });

  group('CreateMemoryScreen pickers and submit', () {
    testWidgets('shouldPickDateLocationAndSubmitExactInput', (tester) async {
      final repository = FakeMemoryRepository()
        ..createResult = authoritativeMemory;
      Memory? createdCallbackMemory;
      MemoryLocation? pickerInitialLocation;
      await pumpScreen(
        tester,
        repository,
        datePicker: (_, initialDate) async {
          expect(initialDate, isNull);
          return futureDate;
        },
        onPickLocation: (initialLocation) async {
          pickerInitialLocation = initialLocation;
          return tbilisiLocation;
        },
        onMemoryCreated: (memory) {
          createdCallbackMemory = memory;
        },
      );

      await tester.enterText(
        find.byKey(const ValueKey('create-memory.title-field')),
        '  Exact title  ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('create-memory.description-field')),
        ' Exact description ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('create-memory.place-name-field')),
        ' Exact place ',
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.date-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.location-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.submit-action')),
      );

      expect(pickerInitialLocation, isNull);
      expect(repository.createMemoryCalls, 1);
      expect(repository.receivedCreateInput?.storyId, defaultStoryId);
      expect(repository.receivedCreateInput?.title, '  Exact title  ');
      expect(
        repository.receivedCreateInput?.description,
        ' Exact description ',
      );
      expect(repository.receivedCreateInput?.placeName, ' Exact place ');
      expect(repository.receivedCreateInput?.eventDate, futureDate);
      expect(repository.receivedCreateInput?.location, tbilisiLocation);
      expect(createdCallbackMemory, same(authoritativeMemory));
      expect(find.text('Dec 17, 2030'), findsOneWidget);
      expect(find.text('Location selected'), findsOneWidget);
      expect(find.textContaining('41.7151'), findsNothing);
      expect(find.textContaining('44.8271'), findsNothing);
    });

    testWidgets('shouldMapEmptyOptionalFieldsToNull', (tester) async {
      final repository = FakeMemoryRepository();
      await pumpScreen(
        tester,
        repository,
        datePicker: (_, __) async => futureDate,
        onPickLocation: (_) async => tbilisiLocation,
      );

      await tester.enterText(
        find.byKey(const ValueKey('create-memory.title-field')),
        'Memory title',
      );
      await tester.enterText(
        find.byKey(const ValueKey('create-memory.description-field')),
        '   ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('create-memory.place-name-field')),
        '',
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.date-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.location-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.submit-action')),
      );

      expect(repository.receivedCreateInput?.description, isNull);
      expect(repository.receivedCreateInput?.placeName, isNull);
    });

    testWidgets('shouldKeepPreviousLocationWhenPickerCancels', (tester) async {
      final repository = FakeMemoryRepository();
      var pickCount = 0;
      await pumpScreen(
        tester,
        repository,
        datePicker: (_, __) async => futureDate,
        onPickLocation: (initialLocation) async {
          pickCount += 1;
          return pickCount == 1 ? tbilisiLocation : null;
        },
      );

      await tester.enterText(
        find.byKey(const ValueKey('create-memory.title-field')),
        'Memory title',
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.date-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.location-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.location-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.submit-action')),
      );

      expect(pickCount, 2);
      expect(repository.receivedCreateInput?.location, tbilisiLocation);
      expect(find.textContaining('41.7151'), findsNothing);
      expect(find.textContaining('44.8271'), findsNothing);
    });

    testWidgets('shouldSubmitChangedLocation', (tester) async {
      final repository = FakeMemoryRepository();
      var pickCount = 0;
      await pumpScreen(
        tester,
        repository,
        datePicker: (_, __) async => futureDate,
        onPickLocation: (_) async {
          pickCount += 1;
          return pickCount == 1 ? tbilisiLocation : batumiLocation;
        },
      );

      await tester.enterText(
        find.byKey(const ValueKey('create-memory.title-field')),
        'Memory title',
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.date-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.location-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.location-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.submit-action')),
      );

      expect(repository.receivedCreateInput?.location, batumiLocation);
    });
  });

  group('CreateMemoryScreen operation state', () {
    testWidgets('shouldShowPendingAndPreventDuplicateSubmitAndBack', (
      tester,
    ) async {
      final completer = Completer<Memory>();
      final repository = FakeMemoryRepository()..createCompleter = completer;
      var backCalls = 0;
      await pumpScreen(
        tester,
        repository,
        datePicker: (_, __) async => futureDate,
        onPickLocation: (_) async => tbilisiLocation,
        onBack: () {
          backCalls += 1;
        },
      );
      await fillRequiredFields(tester);

      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.submit-action')),
        settle: false,
      );
      await tester.pump();
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.submit-action')),
        settle: false,
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.back-action')),
        settle: false,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.text('Creating memory...'), findsOneWidget);
      expect(repository.createMemoryCalls, 1);
      expect(backCalls, 0);

      completer.complete(authoritativeMemory);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRenderKnownFailureAndPreserveFields', (tester) async {
      final repository = FakeMemoryRepository()
        ..createFailure = const MemoryApplicationException(
          MemoryCreationUnavailable(),
        );
      Memory? createdCallbackMemory;
      await pumpScreen(
        tester,
        repository,
        datePicker: (_, __) async => futureDate,
        onPickLocation: (_) async => tbilisiLocation,
        onMemoryCreated: (memory) {
          createdCallbackMemory = memory;
        },
      );

      await fillRequiredFields(tester, title: 'Preserved title');
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.submit-action')),
      );

      expect(
        find.text('Memory cannot be created from here.'),
        findsOneWidget,
      );
      expect(find.text('Preserved title'), findsOneWidget);
      expect(createdCallbackMemory, isNull);
      expect(find.textContaining('MemoryApplicationException'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
      expect(find.textContaining('HTTP'), findsNothing);
    });

    testWidgets('shouldRenderUnexpectedFailureSafelyAndAllowRetry', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..createFailure = const UnexpectedMemoryException();
      await pumpScreen(
        tester,
        repository,
        datePicker: (_, __) async => futureDate,
        onPickLocation: (_) async => tbilisiLocation,
      );

      await fillRequiredFields(tester);
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.submit-action')),
      );

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('UnexpectedMemoryException'), findsNothing);

      repository.createFailure = null;
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-memory.submit-action')),
      );

      expect(repository.createMemoryCalls, 2);
    });
  });
}

Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  FakeMemoryRepository repository, {
  String storyId = defaultStoryId,
  Locale locale = const Locale('en'),
  VoidCallback? onBack,
  CreateMemoryLocationPicker? onPickLocation,
  ValueChanged<Memory>? onMemoryCreated,
  CreateMemoryDatePicker? datePicker,
  TextScaler textScaler = TextScaler.noScaling,
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
        home: CreateMemoryScreen(
          storyId: storyId,
          onBack: onBack,
          onPickLocation: onPickLocation,
          onMemoryCreated: onMemoryCreated,
          datePicker: datePicker ?? ((_, __) async => futureDate),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return container;
}

Future<void> fillRequiredFields(
  WidgetTester tester, {
  String title = 'Memory title',
}) async {
  await tester.enterText(
    find.byKey(const ValueKey('create-memory.title-field')),
    title,
  );
  await pressButton(
    tester,
    find.byKey(const ValueKey('create-memory.date-action')),
  );
  await pressButton(
    tester,
    find.byKey(const ValueKey('create-memory.location-action')),
  );
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
  String title = 'Server memory',
  String? description = 'Server description',
  String? placeName = 'Server place',
  MemoryLocation? location,
  MemoryDate? eventDate,
}) {
  return Memory(
    id: id,
    storyId: storyId,
    createdBy: createdBy,
    title: title,
    description: description,
    placeName: placeName,
    location: location ?? tbilisiLocation,
    eventDate: eventDate ?? futureDate,
    createdAt: DateTime.utc(2026, 8, 9, 10),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

const String defaultStoryId = 'story-id';
final MemoryDate futureDate = MemoryDate(year: 2030, month: 12, day: 17);
final MemoryLocation tbilisiLocation = MemoryLocation(
  latitude: 41.7151,
  longitude: 44.8271,
);
final MemoryLocation batumiLocation = MemoryLocation(
  latitude: 41.6168,
  longitude: 41.6367,
);
final Memory authoritativeMemory = memory(
  id: '00000000-0000-0000-0000-000000000099',
  title: 'Authoritative server title',
);

final class FakeMemoryRepository implements MemoryRepository {
  int getMemoriesCalls = 0;
  int getMemoryCalls = 0;
  int createMemoryCalls = 0;
  int updateMemoryCalls = 0;
  int deleteMemoryCalls = 0;
  Completer<Memory>? createCompleter;
  CreateMemoryInput? receivedCreateInput;
  Memory createResult = authoritativeMemory;
  Object? createFailure;

  @override
  Future<List<MemoryReadModel>> getMemories(String storyId) async {
    getMemoriesCalls += 1;

    return <MemoryReadModel>[];
  }

  @override
  Future<MemoryReadModel> getMemory(String memoryId) async {
    getMemoryCalls += 1;

    return MemoryReadModel.fromMemory(authoritativeMemory);
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    createMemoryCalls += 1;
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
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    updateMemoryCalls += 1;

    return authoritativeMemory;
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) async {
    deleteMemoryCalls += 1;
  }
}

final class UnexpectedMemoryException implements Exception {
  const UnexpectedMemoryException();
}


