import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/application/media_application_exception.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';
import 'package:memory_map/features/media/presentation/widgets/memory_media_gallery.dart';
import 'package:memory_map/l10n/app_localizations.dart';

import '../../media_test_fixtures.dart';

void main() {
  group('MemoryMediaGallery', () {
    testWidgets('shouldRenderEmptyStateAndRefreshAction', (tester) async {
      final repository = FakeMediaRepository()..mediaResult = <Media>[];

      await pumpGallery(tester, repository: repository);

      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('No photos yet.'), findsOneWidget);

      repository.mediaResult = <Media>[media(id: 'media-a')];
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-media.refresh-action')),
      );

      expect(repository.getMediaCalls, 2);
      expect(find.byKey(const ValueKey('memory-media.thumbnail.media-a')),
          findsOneWidget);
    });

    testWidgets('shouldRenderThumbnailsAndFetchDisplayOnlyAfterTap', (
      tester,
    ) async {
      final repository = FakeMediaRepository()
        ..mediaResult = <Media>[media(id: 'media-a')]
        ..thumbnailResult = validPngBytes
        ..displayResult = validPngBytes;

      await pumpGallery(tester, repository: repository);

      expect(repository.getThumbnailCalls, 1);
      expect(repository.getDisplayCalls, 0);

      await tester.tap(
        find.byKey(const ValueKey('memory-media.thumbnail.media-a')),
      );
      await tester.pumpAndSettle();

      expect(repository.getDisplayCalls, 1);
      expect(find.byKey(const ValueKey('memory-media.display-image')),
          findsOneWidget);
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-media.display.close-action')),
      );
      expect(find.byKey(const ValueKey('memory-media.display-image')),
          findsNothing);
    });

    testWidgets('shouldHideDeleteActionWhenCapabilityDoesNotAllowIt', (
      tester,
    ) async {
      final repository = FakeMediaRepository()
        ..mediaResult = <Media>[media(id: 'media-a')]
        ..thumbnailResult = validPngBytes
        ..displayResult = validPngBytes;

      await pumpGallery(
        tester,
        repository: repository,
        canDeletePhoto: false,
      );
      await tester.tap(
        find.byKey(const ValueKey('memory-media.thumbnail.media-a')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('memory-media.display.delete-action')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('memory-media.display-image')),
          findsOneWidget);
    });

    testWidgets('shouldCancelDeleteWithoutNetworkOrStateMutation', (
      tester,
    ) async {
      final repository = FakeMediaRepository()
        ..mediaResult = <Media>[media(id: 'media-a')]
        ..thumbnailResult = validPngBytes
        ..displayResult = validPngBytes;

      await pumpGallery(tester, repository: repository);
      await openPhoto(tester, 'media-a');
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-media.display.delete-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-media.delete.cancel-action')),
      );

      expect(repository.deleteMediaCalls, 0);
      expect(find.byKey(const ValueKey('memory-media.display-image')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('memory-media.thumbnail.media-a')),
          findsOneWidget);
    });

    testWidgets('shouldDeleteAfterConfirmationCloseViewerAndRemoveThumbnail', (
      tester,
    ) async {
      final repository = FakeMediaRepository()
        ..mediaResult = <Media>[media(id: 'media-a'), media(id: 'media-b')]
        ..thumbnailResult = validPngBytes
        ..displayResult = validPngBytes;

      await pumpGallery(tester, repository: repository);
      await openPhoto(tester, 'media-a');
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-media.display.delete-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-media.delete.confirm-action')),
      );

      expect(repository.deleteMediaCalls, 1);
      expect(repository.receivedDeleteMediaIds, <String>['media-a']);
      expect(find.byKey(const ValueKey('memory-media.display-image')),
          findsNothing);
      expect(find.byKey(const ValueKey('memory-media.thumbnail.media-a')),
          findsNothing);
      expect(find.byKey(const ValueKey('memory-media.thumbnail.media-b')),
          findsOneWidget);
    });

    testWidgets('shouldKeepViewerAndGalleryOnDeleteFailure', (tester) async {
      final repository = FakeMediaRepository()
        ..mediaResult = <Media>[media(id: 'media-a')]
        ..thumbnailResult = validPngBytes
        ..displayResult = validPngBytes
        ..deleteMediaFailure =
            const MediaApplicationException(MediaNetworkUnavailable());

      await pumpGallery(tester, repository: repository);
      await openPhoto(tester, 'media-a');
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-media.display.delete-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-media.delete.confirm-action')),
      );

      expect(repository.deleteMediaCalls, 1);
      expect(
        find.text('No network connection. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('memory-media.display-image')),
          findsOneWidget);
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-media.display.close-action')),
      );
      expect(find.byKey(const ValueKey('memory-media.thumbnail.media-a')),
          findsOneWidget);
    });

    testWidgets('shouldShowAddPhotoOnlyWhenCapabilityAllowsItAndUpload', (
      tester,
    ) async {
      final repository = FakeMediaRepository()
        ..mediaResult = <Media>[]
        ..uploadResult = media(id: 'uploaded-media-id')
        ..thumbnailResult = validPngBytes;
      final gateway = FakePhotoSelectionGateway();
      final preprocessor = FakePhotoPreprocessor()
        ..result = preparedPhotoUpload(bytes: <int>[8, 8, 8]);

      await pumpGallery(
        tester,
        repository: repository,
        gateway: gateway,
        preprocessor: preprocessor,
        canUploadPhoto: false,
      );

      expect(
        find.byKey(const ValueKey('memory-media.add-photo-action')),
        findsNothing,
      );

      await pumpGallery(
        tester,
        repository: repository,
        gateway: gateway,
        preprocessor: preprocessor,
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-media.add-photo-action')),
      );

      expect(gateway.selectPhotoCalls, 1);
      expect(preprocessor.processCalls, 1);
      expect(repository.uploadPhotoCalls, 1);
      expect(repository.receivedUploads.single.bytes, <int>[8, 8, 8]);
      expect(
        find.byKey(const ValueKey('memory-media.thumbnail.uploaded-media-id')),
        findsOneWidget,
      );
    });

    testWidgets('shouldRenderLoadAndUploadFailuresSafely', (tester) async {
      final repository = FakeMediaRepository()
        ..getMediaFailure =
            const MediaApplicationException(MediaUnavailable())
        ..uploadPhotoFailure =
            const MediaApplicationException(MediaUploadUnavailable())
        ..thumbnailResult = validPngBytes;
      final gateway = FakePhotoSelectionGateway();
      final preprocessor = FakePhotoPreprocessor();

      await pumpGallery(
        tester,
        repository: repository,
        gateway: gateway,
        preprocessor: preprocessor,
      );

      expect(find.text('Photos are unavailable.'), findsOneWidget);
      expect(find.textContaining('/api/v1/media'), findsNothing);

      repository.getMediaFailure = null;
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-media.retry-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('memory-media.add-photo-action')),
      );

      expect(find.text('Photo cannot be uploaded from here.'), findsOneWidget);
      expect(find.textContaining('MediaApplicationException'), findsNothing);
      expect(find.textContaining('accessToken'), findsNothing);
    });
  });
}

Future<void> pumpGallery(
  WidgetTester tester, {
  required FakeMediaRepository repository,
  FakePhotoSelectionGateway? gateway,
  FakePhotoPreprocessor? preprocessor,
  bool canUploadPhoto = true,
  bool canDeletePhoto = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaRepositoryProvider.overrideWithValue(repository),
        photoSelectionGatewayProvider.overrideWithValue(
          gateway ?? FakePhotoSelectionGateway(),
        ),
        photoPreprocessorProvider.overrideWithValue(
          preprocessor ?? FakePhotoPreprocessor(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MemoryMediaGallery(
              memoryId: defaultMemoryId,
              canUploadPhoto: canUploadPhoto,
              canDeletePhoto: canDeletePhoto,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openPhoto(WidgetTester tester, String mediaId) async {
  await tester.tap(find.byKey(ValueKey('memory-media.thumbnail.$mediaId')));
  await tester.pumpAndSettle();
}

Future<void> pressButton(WidgetTester tester, Finder finder) async {
  final widget = tester.widget<Widget>(finder);
  final onPressed = switch (widget) {
    IconButton(:final onPressed) => onPressed,
    TextButton(:final onPressed) => onPressed,
    FilledButton(:final onPressed) => onPressed,
    _ => throw StateError('Unsupported button widget: $widget'),
  };

  onPressed?.call();
  await tester.pumpAndSettle();
}
