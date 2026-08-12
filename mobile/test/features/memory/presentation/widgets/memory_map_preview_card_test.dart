import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/presentation/memory_date_format.dart';
import 'package:memory_map/features/memory/presentation/widgets/memory_map_preview_card.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('MemoryMapPreviewCard', () {
    testWidgets('shouldRenderVisiblePreviewFields', (tester) async {
      await pumpPreview(tester, memoryA);

      expect(find.text('First picnic'), findsOneWidget);
      expect(find.text('Riverside Park'), findsOneWidget);
      expect(find.text('Aug 9, 2026'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('08'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('shouldRenderLocalizedDateWithoutTimezoneConversion', (
      tester,
    ) async {
      await pumpPreview(tester, memoryA, locale: const Locale('ru'));
      final context = tester.element(find.byType(MemoryMapPreviewCard));
      final expected = formatMemoryDate(
        AppLocalizations.of(context),
        memoryA.eventDate,
      );

      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('shouldHideDescriptionAndBlankPlaceName', (tester) async {
      await pumpPreview(
        tester,
        memory(
          description: 'Private preview description',
          placeName: '   ',
        ),
      );

      expect(find.text('Private preview description'), findsNothing);
      expect(find.byIcon(Icons.place_rounded), findsNothing);
    });

    testWidgets('shouldCallTapWithExactMemory', (tester) async {
      Memory? selectedMemory;
      await pumpPreview(
        tester,
        memoryA,
        onTap: (memory) {
          selectedMemory = memory;
        },
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(selectedMemory, same(memoryA));
    });

    testWidgets('shouldStillRenderWithoutOpenCallback', (tester) async {
      await pumpPreview(tester, memoryA, enableTap: false);

      expect(find.text('First picnic'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('shouldCloseWithoutTriggeringOpen', (tester) async {
      var closeCalls = 0;
      var openCalls = 0;
      await pumpPreview(
        tester,
        memoryA,
        onTap: (_) {
          openCalls += 1;
        },
        onClose: () {
          closeCalls += 1;
        },
      );

      await tester.tap(
        find.byKey(const ValueKey('story-map.memory-preview.close')),
      );
      await tester.pump();

      expect(closeCalls, 1);
      expect(openCalls, 0);
    });

    testWidgets('shouldNotRenderIdsCoordinatesOrInfrastructureDetails', (
      tester,
    ) async {
      await pumpPreview(
        tester,
        memory(
          id: 'private-memory-id',
          storyId: 'private-story-id',
          createdBy: 'private-user-id',
          title: 'Visible memory',
          description: 'Private description',
          placeName: 'Visible place',
          latitude: 41.715123,
          longitude: 44.827456,
        ),
      );

      expect(find.text('Visible memory'), findsOneWidget);
      expect(find.text('Visible place'), findsOneWidget);
      expect(find.textContaining('private-memory-id'), findsNothing);
      expect(find.textContaining('private-story-id'), findsNothing);
      expect(find.textContaining('private-user-id'), findsNothing);
      expect(find.textContaining('Private description'), findsNothing);
      expect(find.textContaining('41.715123'), findsNothing);
      expect(find.textContaining('44.827456'), findsNothing);
      expect(find.textContaining('createdAt'), findsNothing);
      expect(find.textContaining('updatedAt'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
      expect(find.textContaining('ProblemDetail'), findsNothing);
    });

    testWidgets('shouldNotOverflowOnSmallPhoneWithLargeText', (tester) async {
      setSurface(tester, const Size(360, 640));

      await pumpPreview(
        tester,
        memory(
          title: 'A very long title that should stay inside the preview card',
          placeName:
              'A very long place name that should use wrapping and ellipsis',
        ),
        textScaler: const TextScaler.linear(1.25),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> pumpPreview(
  WidgetTester tester,
  Memory memory, {
  Locale locale = const Locale('en'),
  ValueChanged<Memory>? onTap,
  bool enableTap = true,
  VoidCallback? onClose,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MaterialApp(
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
        body: Center(
          child: MemoryMapPreviewCard(
            memory: memory,
            onTap: enableTap ? onTap ?? (_) {} : null,
            onClose: onClose,
          ),
        ),
      ),
    ),
  );
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
  String id = 'memory-id',
  String storyId = 'story-id',
  String createdBy = 'author-id',
  String title = 'First picnic',
  String? description = 'Near the river',
  String? placeName = 'Riverside Park',
  double latitude = 55.751244,
  double longitude = 37.618423,
}) {
  return Memory(
    id: id,
    storyId: storyId,
    createdBy: createdBy,
    title: title,
    description: description,
    placeName: placeName,
    location: MemoryLocation(latitude: latitude, longitude: longitude),
    eventDate: MemoryDate(year: 2026, month: 8, day: 9),
    createdAt: DateTime.utc(2026, 8, 9, 10),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

final Memory memoryA = memory(id: 'memory-a');
