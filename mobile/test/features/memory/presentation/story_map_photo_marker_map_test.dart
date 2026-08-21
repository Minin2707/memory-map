import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/presentation/story_map_photo_marker_map.dart';

void main() {
  group('StoryMapPhotoMarkerMap icon sizing', () {
    test('shouldKeepUnselectedMarkerBaselineDimensions', () {
      final metrics = storyMapMarkerIconMetricsForTesting(selected: false);

      expect(metrics.width, 60.0);
      expect(metrics.height, 72.0);
      expect(metrics.photoDiameter, 46.0);
      expect(metrics.outerRingRadius, 27.0);
      expect(metrics.fallbackFillRadius, 21.0);
      expect(metrics.bottomDotY, 66.0);
    });

    test('shouldMakeSelectedPhotoMarkerAboutFifteenPercentLarger', () {
      final normal = storyMapMarkerIconMetricsForTesting(selected: false);
      final selected = storyMapMarkerIconMetricsForTesting(selected: true);

      expect(selected.width / normal.width, closeTo(1.15, 0.01));
      expect(selected.height / normal.height, closeTo(1.15, 0.01));
      expect(
        selected.photoDiameter / normal.photoDiameter,
        closeTo(1.15, 0.01),
      );
      expect(selected.outerRingRadius, greaterThan(normal.outerRingRadius));
      expect(selected.stemWidth, greaterThan(normal.stemWidth));
      expect(selected.bottomDotRadius, greaterThan(normal.bottomDotRadius));
    });

    test('shouldMakeSelectedFallbackMarkerProportionallyLarger', () {
      final normal = storyMapMarkerIconMetricsForTesting(selected: false);
      final selected = storyMapMarkerIconMetricsForTesting(selected: true);

      expect(
        selected.fallbackFillRadius / normal.fallbackFillRadius,
        closeTo(1.14, 0.02),
      );
      expect(
        selected.fallbackDotRadius / normal.fallbackDotRadius,
        closeTo(1.14, 0.02),
      );
      expect(selected.gradientRadius, greaterThan(normal.gradientRadius));
    });

    test('shouldKeepGeographicAnchorCenteredAtBitmapBottom', () {
      final normal = storyMapMarkerIconMetricsForTesting(selected: false);
      final selected = storyMapMarkerIconMetricsForTesting(selected: true);

      expect(normal.bottomDotY, lessThan(normal.height));
      expect(selected.bottomDotY, lessThan(selected.height));
      expect(normal.width / 2, 30.0);
      expect(selected.width / 2, 34.5);
      expect(
        selected.bottomDotY / selected.height,
        closeTo(normal.bottomDotY / normal.height, 0.01),
      );
    });
  });

  group('StoryMapPhotoMarkerMap icon resolution', () {
    test('shouldPreferDesiredSelectedIconWhenReady', () {
      final key = resolveStoryMapMarkerIconKey(
        desiredImageKey: 'marker.photo.a.selected',
        compatibleImageKeys: const <String>['marker.photo.a.normal'],
        hasIconBytes: const <String>{
          'marker.photo.a.selected',
          'marker.photo.a.normal',
        }.contains,
      );

      expect(key, 'marker.photo.a.selected');
    });

    test('shouldKeepPhotoMarkerVisibleWhileSelectedIconIsPending', () {
      final key = resolveStoryMapMarkerIconKey(
        desiredImageKey: 'marker.photo.a.selected',
        compatibleImageKeys: const <String>[
          'marker.photo.a.normal',
          'marker.fallback.selected',
          'marker.fallback.normal',
        ],
        hasIconBytes: const <String>{'marker.photo.a.normal'}.contains,
      );

      expect(key, 'marker.photo.a.normal');
    });

    test('shouldKeepNoPhotoMarkerVisibleWhileSelectedFallbackIsPending', () {
      final key = resolveStoryMapMarkerIconKey(
        desiredImageKey: 'marker.fallback.selected',
        compatibleImageKeys: const <String>['marker.fallback.normal'],
        hasIconBytes: const <String>{'marker.fallback.normal'}.contains,
      );

      expect(key, 'marker.fallback.normal');
    });

    test('shouldUseFallbackIconWhenPhotoPreviewIconIsPending', () {
      final key = resolveStoryMapMarkerIconKey(
        desiredImageKey: 'marker.photo.b.selected',
        compatibleImageKeys: const <String>[
          'marker.photo.b.normal',
          'marker.fallback.selected',
          'marker.fallback.normal',
        ],
        hasIconBytes: const <String>{'marker.fallback.normal'}.contains,
      );

      expect(key, 'marker.fallback.normal');
    });

    test('shouldReturnNullOnlyWhenNoCompatibleIconExistsYet', () {
      final key = resolveStoryMapMarkerIconKey(
        desiredImageKey: 'marker.photo.b.selected',
        compatibleImageKeys: const <String>[
          'marker.photo.b.normal',
          'marker.fallback.selected',
          'marker.fallback.normal',
        ],
        hasIconBytes: const <String>{}.contains,
      );

      expect(key, isNull);
    });
  });
}
