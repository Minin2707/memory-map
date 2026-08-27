import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/presentation/widgets/authenticated_media_image.dart';

import '../../media_test_fixtures.dart';

void main() {
  group('AuthenticatedMediaImage', () {
    testWidgets('shouldLoadThumbnailThroughRepository', (tester) async {
      final repository = FakeMediaRepository()..thumbnailResult = validPngBytes;

      await pumpImage(
        tester,
        repository,
        AuthenticatedMediaRepresentation.thumbnail,
      );

      expect(repository.getThumbnailCalls, 1);
      expect(repository.getDisplayCalls, 0);
      expect(find.byType(Image), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isNot(isA<ResizeImage>()),
      );
    });

    testWidgets('shouldLoadDisplayThroughRepositoryOnlyWhenRequested', (
      tester,
    ) async {
      final repository = FakeMediaRepository()..displayResult = validPngBytes;

      await pumpImage(
        tester,
        repository,
        AuthenticatedMediaRepresentation.display,
      );

      expect(repository.getThumbnailCalls, 0);
      expect(repository.getDisplayCalls, 1);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('shouldRenderSafeErrorBuilderOnFailure', (tester) async {
      final repository = FakeMediaRepository()
        ..thumbnailFailure = const UnexpectedImageException();

      await pumpImage(
        tester,
        repository,
        AuthenticatedMediaRepresentation.thumbnail,
      );

      expect(find.text('Image failed'), findsOneWidget);
      expect(find.textContaining('/api/v1/media'), findsNothing);
      expect(find.textContaining('accessToken'), findsNothing);
    });

    testWidgets('shouldLoadThumbnailByTrustedBackendPath', (tester) async {
      final repository = FakeMediaRepository()..thumbnailResult = validPngBytes;

      await pumpPathImage(
        tester,
        repository,
        '/api/v1/media/media-id/thumbnail',
      );

      expect(repository.getThumbnailByPathCalls, 1);
      expect(repository.receivedBinaryPaths, <String>[
        '/api/v1/media/media-id/thumbnail',
      ]);
      expect(repository.getThumbnailCalls, 0);
      expect(repository.getDisplayCalls, 0);
      expect(repository.getDisplayByPathCalls, 0);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('shouldLoadDisplayByTrustedBackendPathWhenRequested', (
      tester,
    ) async {
      final repository = FakeMediaRepository()..displayResult = validPngBytes;

      await pumpPathImage(
        tester,
        repository,
        '/api/v1/media/media-id/display',
        representation: AuthenticatedMediaRepresentation.display,
      );

      expect(repository.getThumbnailByPathCalls, 0);
      expect(repository.getDisplayByPathCalls, 1);
      expect(repository.receivedBinaryPaths, <String>[
        '/api/v1/media/media-id/display',
      ]);
      expect(repository.getMediaCalls, 0);
      expect(repository.getDisplayCalls, 0);
      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('DISPLAY decode sizing', () {
    test('shouldUseRenderedWidthAndDevicePixelRatioForWideSurfaces', () {
      final size = authenticatedMediaDisplayDecodeSize(
        logicalSize: const Size(320, 180),
        devicePixelRatio: 2.5,
      );

      expect(size.cacheWidth, 800);
      expect(size.cacheHeight, isNull);
    });

    test('shouldUseRenderedHeightForTallFullscreenSurfaces', () {
      final size = authenticatedMediaDisplayDecodeSize(
        logicalSize: const Size(360, 720),
        devicePixelRatio: 2,
      );

      expect(size.cacheWidth, isNull);
      expect(size.cacheHeight, 1440);
    });

    test('shouldCapDisplayDecodeSizeAtBackendDisplayMaximum', () {
      final size = authenticatedMediaDisplayDecodeSize(
        logicalSize: const Size(1200, 800),
        devicePixelRatio: 3,
      );

      expect(size.cacheWidth, 2048);
      expect(size.cacheHeight, isNull);
    });

    test('shouldFallbackToOnePixelRatioForInvalidDevicePixelRatio', () {
      final size = authenticatedMediaDisplayDecodeSize(
        logicalSize: const Size(320, 180),
        devicePixelRatio: double.nan,
      );

      expect(size.cacheWidth, 320);
      expect(size.cacheHeight, isNull);
    });
  });
}

Future<void> pumpImage(
  WidgetTester tester,
  FakeMediaRepository repository,
  AuthenticatedMediaRepresentation representation,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: AuthenticatedMediaImage(
          media: media(),
          representation: representation,
          fit: BoxFit.cover,
          placeholder: const Text('Loading image'),
          errorBuilder: (_) => const Text('Image failed'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpPathImage(
  WidgetTester tester,
  FakeMediaRepository repository,
  String thumbnailPath, {
  AuthenticatedMediaRepresentation representation =
      AuthenticatedMediaRepresentation.thumbnail,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: AuthenticatedMediaPathImage(
          thumbnailPath: thumbnailPath,
          representation: representation,
          fit: BoxFit.cover,
          placeholder: const Text('Loading image'),
          errorBuilder: (_) => const Text('Image failed'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class UnexpectedImageException implements Exception {
  const UnexpectedImageException();
}
