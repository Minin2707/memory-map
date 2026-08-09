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
import 'package:memory_map/features/memory/domain/update_memory_input.dart';
import 'package:memory_map/features/memory/presentation/edit_memory_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('EditMemoryScreen rendering', () {
    testWidgets('shouldRenderInitialEnglishFormWithoutRepositoryCall', (
      tester,
    ) async {
      final repository = FakeMemoryRepository();
      await pumpScreen(tester, repository);

      expect(find.text('Edit memory'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Place name'), findsOneWidget);
      expect(find.text('Event date'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Original title'), findsOneWidget);
      expect(find.text('Original description'), findsOneWidget);
      expect(find.text('Original place'), findsOneWidget);
      expect(find.text('Location selected'), findsOneWidget);
      expect(find.text('Make a change to save.'), findsOneWidget);
      expect(find.textContaining(defaultMemoryId), findsNothing);
      expect(find.textContaining(defaultStoryId), findsNothing);
      expect(find.textContaining('41.715'), findsNothing);
      expect(repository.updateMemoryCalls, 0);
      expect(repository.getMemoryCalls, 0);
      expect(repository.getMemoriesCalls, 0);
    });

    testWidgets('shouldRenderRussianFormFromLocalizations', (tester) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository(),
        locale: const Locale('ru'),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(EditMemoryScreen)),
      );

      expect(find.text(l10n.editMemoryPageTitle), findsOneWidget);
      expect(find.text(l10n.createMemoryTitleLabel), findsOneWidget);
      expect(find.text(l10n.editMemorySaveButton), findsOneWidget);
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

    testWidgets('shouldRenderNullableAndEmptyOptionalFieldsAsEmptyInputs', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        FakeMemoryRepository(),
        memory: originalMemory(description: null, placeName: ''),
      );

      expect(find.text('null'), findsNothing);
      expect(find.text('Make a change to save.'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
    });
  });

  group('EditMemoryScreen patch construction', () {
    testWidgets('shouldSubmitTitleOnlyUpdateWithUntouchedOptionalsOmitted', (
      tester,
    ) async {
      final repository = FakeMemoryRepository();
      Memory? callbackMemory;
      await pumpScreen(
        tester,
        repository,
        onMemoryUpdated: (memory) {
          callbackMemory = memory;
        },
      );

      await tester.enterText(
        find.byKey(const ValueKey('edit-memory.title-field')),
        '  Updated title  ',
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.save-action')),
      );

      final input = repository.receivedUpdateInput!;
      expect(input.memoryId, defaultMemoryId);
      expect(input.title.isProvided, isTrue);
      expect(input.title.value, '  Updated title  ');
      expect(input.description.isProvided, isFalse);
      expect(input.placeName.isProvided, isFalse);
      expect(input.location.isProvided, isFalse);
      expect(input.eventDate.isProvided, isFalse);
      expect(callbackMemory, same(authoritativeMemory));
    });

    testWidgets('shouldOmitUntouchedNullableFieldsWhenRenderedEmpty', (
      tester,
    ) async {
      final repository = FakeMemoryRepository();
      await pumpScreen(
        tester,
        repository,
        memory: originalMemory(description: null, placeName: ''),
      );

      await tester.enterText(
        find.byKey(const ValueKey('edit-memory.title-field')),
        'Title only',
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.save-action')),
      );

      final input = repository.receivedUpdateInput!;
      expect(input.title.isProvided, isTrue);
      expect(input.description.isProvided, isFalse);
      expect(input.placeName.isProvided, isFalse);
    });

    testWidgets('shouldClearDescriptionAndPlaceNameWithExplicitNull', (
      tester,
    ) async {
      final repository = FakeMemoryRepository();
      await pumpScreen(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey('edit-memory.description-field')),
        '',
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit-memory.place-name-field')),
        '   ',
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.save-action')),
      );

      final input = repository.receivedUpdateInput!;
      expect(input.title.isProvided, isFalse);
      expect(input.description.isProvided, isTrue);
      expect(input.description.value, isNull);
      expect(input.placeName.isProvided, isTrue);
      expect(input.placeName.value, isNull);
    });

    testWidgets('shouldSubmitDescriptionAndPlaceNameValuesWithoutNormalization', (
      tester,
    ) async {
      final repository = FakeMemoryRepository();
      await pumpScreen(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey('edit-memory.description-field')),
        '  New description  ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit-memory.place-name-field')),
        '  New place  ',
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.save-action')),
      );

      final input = repository.receivedUpdateInput!;
      expect(input.description.value, '  New description  ');
      expect(input.placeName.value, '  New place  ');
    });

    testWidgets('shouldOmitRevertedTextDateAndLocationChanges', (tester) async {
      final repository = FakeMemoryRepository();
      var pickCount = 0;
      await pumpScreen(
        tester,
        repository,
        datePicker: (_, __) async {
          pickCount += 1;
          return pickCount == 1 ? changedDate : defaultDate;
        },
        onPickLocation: (_) async {
          pickCount += 1;
          return pickCount == 2 ? changedLocation : defaultLocation;
        },
      );

      await tester.enterText(
        find.byKey(const ValueKey('edit-memory.title-field')),
        'Changed title',
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit-memory.title-field')),
        'Original title',
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit-memory.description-field')),
        'Changed description',
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit-memory.description-field')),
        'Original description',
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.date-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.location-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.date-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.location-action')),
      );

      expect(find.text('Make a change to save.'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
      expect(repository.updateMemoryCalls, 0);
    });

    testWidgets('shouldSubmitDateAndLocationAtomically', (tester) async {
      final repository = FakeMemoryRepository();
      MemoryLocation? pickerInitialLocation;
      await pumpScreen(
        tester,
        repository,
        datePicker: (_, initialDate) async {
          expect(initialDate, defaultDate);
          return changedDate;
        },
        onPickLocation: (initialLocation) async {
          pickerInitialLocation = initialLocation;
          return changedLocation;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.date-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.location-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.save-action')),
      );

      final input = repository.receivedUpdateInput!;
      expect(pickerInitialLocation, defaultLocation);
      expect(input.location.isProvided, isTrue);
      expect(input.location.value, changedLocation);
      expect(input.eventDate.isProvided, isTrue);
      expect(input.eventDate.value, changedDate);
      expect(input.title.isProvided, isFalse);
      expect(find.textContaining('42.1'), findsNothing);
      expect(find.textContaining('43.2'), findsNothing);
    });

    testWidgets('shouldKeepExistingLocationWhenPickerCancels', (tester) async {
      final repository = FakeMemoryRepository();
      await pumpScreen(
        tester,
        repository,
        onPickLocation: (_) async => null,
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.location-action')),
      );

      expect(find.text('Make a change to save.'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
      expect(repository.updateMemoryCalls, 0);
    });
  });

  group('EditMemoryScreen validation and operation state', () {
    testWidgets('shouldDisableSaveForNoOpAndAvoidRepositoryCall', (
      tester,
    ) async {
      final repository = FakeMemoryRepository();
      await pumpScreen(tester, repository);

      expect(saveButton(tester).onPressed, isNull);
      expect(repository.updateMemoryCalls, 0);
    });

    testWidgets('shouldRejectBlankTitleAndTooLongPlaceName', (tester) async {
      final repository = FakeMemoryRepository();
      await pumpScreen(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey('edit-memory.title-field')),
        '   ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit-memory.place-name-field')),
        ''.padRight(256, 'a'),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.save-action')),
      );

      expect(find.text('Memory title cannot be blank.'), findsOneWidget);
      expect(
        find.text('Place name must be 255 characters or fewer.'),
        findsOneWidget,
      );
      expect(repository.updateMemoryCalls, 0);
    });

    testWidgets('shouldShowPendingAndPreventDuplicateSaveAndBack', (
      tester,
    ) async {
      final completer = Completer<Memory>();
      final repository = FakeMemoryRepository()..updateCompleter = completer;
      var backCalls = 0;
      await pumpScreen(
        tester,
        repository,
        onBack: () {
          backCalls += 1;
        },
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit-memory.title-field')),
        'Pending title',
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.save-action')),
        settle: false,
      );
      await tester.pump();
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.save-action')),
        settle: false,
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.back-action')),
        settle: false,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.text('Saving changes...'), findsOneWidget);
      expect(repository.updateMemoryCalls, 1);
      expect(backCalls, 0);

      completer.complete(authoritativeMemory);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRenderKnownFailureAndPreserveFields', (tester) async {
      final repository = FakeMemoryRepository()
        ..updateFailure = const MemoryApplicationException(
          MemoryUpdateUnavailable(),
        );
      Memory? callbackMemory;
      await pumpScreen(
        tester,
        repository,
        onMemoryUpdated: (memory) {
          callbackMemory = memory;
        },
      );

      await tester.enterText(
        find.byKey(const ValueKey('edit-memory.title-field')),
        'Preserved title',
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.save-action')),
      );

      expect(
        find.text('Memory cannot be updated from here.'),
        findsOneWidget,
      );
      expect(find.text('Preserved title'), findsOneWidget);
      expect(callbackMemory, isNull);
      expect(find.textContaining('MemoryApplicationException'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
      expect(find.textContaining('HTTP'), findsNothing);
    });

    testWidgets('shouldRenderUnexpectedFailureSafelyAndAllowRetry', (
      tester,
    ) async {
      final repository = FakeMemoryRepository()
        ..updateFailure = const UnexpectedMemoryException();
      await pumpScreen(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey('edit-memory.title-field')),
        'Retry title',
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.save-action')),
      );

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('UnexpectedMemoryException'), findsNothing);

      repository.updateFailure = null;
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.save-action')),
      );

      expect(repository.updateMemoryCalls, 2);
    });

    testWidgets('shouldRefreshBaselineFromAuthoritativeMemoryAfterSuccess', (
      tester,
    ) async {
      final repository = FakeMemoryRepository();
      await pumpScreen(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey('edit-memory.title-field')),
        'Client title',
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-memory.save-action')),
      );

      expect(find.text('Authoritative server title'), findsOneWidget);
      expect(find.text('Make a change to save.'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
    });
  });
}

Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  FakeMemoryRepository repository, {
  Memory? memory,
  Locale locale = const Locale('en'),
  VoidCallback? onBack,
  EditMemoryLocationPicker? onPickLocation,
  ValueChanged<Memory>? onMemoryUpdated,
  EditMemoryDatePicker? datePicker,
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
        home: EditMemoryScreen(
          memory: memory ?? originalMemory(),
          onBack: onBack,
          onPickLocation: onPickLocation ?? ((_) async => changedLocation),
          onMemoryUpdated: onMemoryUpdated,
          datePicker: datePicker ?? ((_, __) async => changedDate),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return container;
}

FilledButton saveButton(WidgetTester tester) {
  return tester.widget<FilledButton>(
    find.byKey(const ValueKey('edit-memory.save-action')),
  );
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

Memory originalMemory({
  String id = defaultMemoryId,
  String storyId = defaultStoryId,
  String createdBy = 'author-id',
  String title = 'Original title',
  String? description = 'Original description',
  String? placeName = 'Original place',
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
    location: location ?? defaultLocation,
    eventDate: eventDate ?? defaultDate,
    createdAt: DateTime.utc(2026, 8, 9, 10),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

const String defaultMemoryId = '00000000-0000-0000-0000-000000000001';
const String defaultStoryId = 'story-id';
final MemoryDate defaultDate = MemoryDate(year: 2026, month: 8, day: 9);
final MemoryDate changedDate = MemoryDate(year: 2030, month: 12, day: 17);
final MemoryLocation defaultLocation = MemoryLocation(
  latitude: 41.7151,
  longitude: 44.8271,
);
final MemoryLocation changedLocation = MemoryLocation(
  latitude: 42.1,
  longitude: 43.2,
);
final Memory authoritativeMemory = originalMemory(
  title: 'Authoritative server title',
  description: 'Authoritative server description',
  placeName: 'Authoritative server place',
  eventDate: changedDate,
  location: changedLocation,
);

final class FakeMemoryRepository implements MemoryRepository {
  int getMemoriesCalls = 0;
  int getMemoryCalls = 0;
  int createMemoryCalls = 0;
  int updateMemoryCalls = 0;
  int deleteMemoryCalls = 0;
  Completer<Memory>? updateCompleter;
  UpdateMemoryInput? receivedUpdateInput;
  Memory updateResult = authoritativeMemory;
  Object? updateFailure;

  @override
  Future<List<Memory>> getMemories(String storyId) async {
    getMemoriesCalls += 1;

    return <Memory>[];
  }

  @override
  Future<Memory> getMemory(String memoryId) async {
    getMemoryCalls += 1;

    return updateResult;
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    createMemoryCalls += 1;

    return updateResult;
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    updateMemoryCalls += 1;
    receivedUpdateInput = input;

    final completer = updateCompleter;
    if (completer != null) {
      updateCompleter = null;
      return completer.future;
    }

    final failure = updateFailure;
    if (failure != null) {
      throw failure;
    }

    return updateResult;
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) async {
    deleteMemoryCalls += 1;
  }
}

final class UnexpectedMemoryException implements Exception {
  const UnexpectedMemoryException();
}
