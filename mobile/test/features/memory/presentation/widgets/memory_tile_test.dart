import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/presentation/memory_date_format.dart';
import 'package:memory_map/features/memory/presentation/widgets/memory_tile.dart';
import 'package:memory_map/l10n/app_localizations.dart';

import '../../../media/media_test_fixtures.dart' as media_fixtures;

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

    testWidgets('shouldLoadPreviewThumbnailThroughBackendPath', (
      tester,
    ) async {
      final repository = media_fixtures.FakeMediaRepository()
        ..thumbnailResult = media_fixtures.validPngBytes;

      await pumpTile(
        tester,
        memoryA,
        previewPhoto: previewPhoto(mediaId: 'media-a'),
        mediaRepository: repository,
      );

      expect(repository.getThumbnailByPathCalls, 1);
      expect(repository.receivedBinaryPaths, <String>[
        '/api/v1/media/media-a/thumbnail',
      ]);
      expect(repository.getThumbnailCalls, 0);
      expect(find.byType(Image), findsOneWidget);
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
  MemoryPhotoPreview? previewPhoto,
  ValueChanged<Memory>? onSelected,
  media_fixtures.FakeMediaRepository? mediaRepository,
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
        home: Scaffold(
          body: MemoryTile(
            memory: memory,
            previewPhoto: previewPhoto,
            onSelected: onSelected,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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

MemoryPhotoPreview previewPhoto({
  required String mediaId,
}) {
  return MemoryPhotoPreview(
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}
