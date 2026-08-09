import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/presentation/memory_date_format.dart';
import 'package:memory_map/features/memory/presentation/widgets/memory_tile.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('MemoryTile', () {
    testWidgets('shouldRenderVisibleMemoryFieldsAndEnglishDate', (
      tester,
    ) async {
      await pumpTile(tester, memoryA);

      expect(find.text('First picnic'), findsOneWidget);
      expect(find.text('Riverside Park'), findsOneWidget);
      expect(find.text('Aug 9, 2026'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('08'), findsOneWidget);
    });

    testWidgets('shouldRenderRussianDateWithoutTimezoneConversion', (
      tester,
    ) async {
      await pumpTile(tester, memoryA, locale: const Locale('ru'));

      expect(find.text('9 авг. 2026 г.'), findsOneWidget);
    });

    testWidgets('shouldHideDescriptionAndAbsentPlaceName', (tester) async {
      await pumpTile(
        tester,
        memory(
          description: 'Private list description',
          placeName: null,
        ),
      );

      expect(find.text('Private list description'), findsNothing);
      expect(find.byIcon(Icons.place_rounded), findsNothing);
    });

    testWidgets('shouldCallSelectionWithExactMemory', (tester) async {
      Memory? selectedMemory;
      await pumpTile(
        tester,
        memoryA,
        onSelected: (memory) {
          selectedMemory = memory;
        },
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(selectedMemory, same(memoryA));
    });

    testWidgets('shouldNotRenderIdsCoordinatesOrBackendDetails', (
      tester,
    ) async {
      await pumpTile(
        tester,
        memory(
          id: 'private-memory-id',
          storyId: 'private-story-id',
          createdBy: 'private-user-id',
          title: 'Visible title',
          description: 'Visible description',
          placeName: 'Visible place',
        ),
      );

      expect(find.textContaining('private-memory-id'), findsNothing);
      expect(find.textContaining('private-story-id'), findsNothing);
      expect(find.textContaining('private-user-id'), findsNothing);
      expect(find.textContaining('Visible description'), findsNothing);
      expect(find.textContaining('55.751244'), findsNothing);
      expect(find.textContaining('37.618423'), findsNothing);
      expect(find.textContaining('createdAt'), findsNothing);
      expect(find.textContaining('updatedAt'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
    });
  });

  group('formatMemoryDate', () {
    testWidgets('shouldUseMemoryDateComponentsOnly', (tester) async {
      late String formatted;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              formatted = formatMemoryDate(
                AppLocalizations.of(context),
                MemoryDate(year: 2026, month: 1, day: 1),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(formatted, 'Jan 1, 2026');
    });
  });
}

Future<void> pumpTile(
  WidgetTester tester,
  Memory memory, {
  Locale locale = const Locale('en'),
  ValueChanged<Memory>? onSelected,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MemoryTile(
          memory: memory,
          onSelected: onSelected,
        ),
      ),
    ),
  );
}

Memory memory({
  String id = 'memory-id',
  String storyId = 'story-id',
  String createdBy = 'author-id',
  String title = 'First picnic',
  String? description = 'Near the river',
  String? placeName = 'Riverside Park',
}) {
  return Memory(
    id: id,
    storyId: storyId,
    createdBy: createdBy,
    title: title,
    description: description,
    placeName: placeName,
    location: MemoryLocation(latitude: 55.751244, longitude: 37.618423),
    eventDate: MemoryDate(year: 2026, month: 8, day: 9),
    createdAt: DateTime.utc(2026, 8, 9, 10),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

final Memory memoryA = memory(id: 'memory-a');
