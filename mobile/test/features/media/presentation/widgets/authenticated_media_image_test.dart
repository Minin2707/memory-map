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

final class UnexpectedImageException implements Exception {
  const UnexpectedImageException();
}
