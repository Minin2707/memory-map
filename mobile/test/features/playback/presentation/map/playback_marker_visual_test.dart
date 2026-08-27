import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/presentation/widgets/maplibre_marker_synchronizer.dart';
import 'package:memory_map/features/playback/presentation/map/playback_marker_visual.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Playback marker visual metrics', () {
    test('shouldKeepNormalMarkerCompact', () {
      final metrics = playbackMarkerIconMetricsForTesting(current: false);

      expect(metrics.width, 66.0);
      expect(metrics.height, 66.0);
      expect(metrics.photoDiameter, 48.0);
      expect(metrics.outerRingRadius, 28.0);
      expect(metrics.badgeCenterX, 49.0);
      expect(metrics.badgeCenterY, 47.0);
      expect(metrics.badgeRadius, 13.5);
      expect(metrics.badgeFontSize, 15.0);
      expect(metrics.haloRadius, 0.0);
    });

    test('shouldMakeCurrentMarkerAboutTwentyPercentLarger', () {
      final normal = playbackMarkerIconMetricsForTesting(current: false);
      final current = playbackMarkerIconMetricsForTesting(current: true);

      expect(current.width / normal.width, closeTo(1.21, 0.02));
      expect(current.height / normal.height, closeTo(1.21, 0.02));
      expect(current.photoDiameter / normal.photoDiameter, closeTo(1.21, 0.02));
      expect(current.outerRingRadius, greaterThan(normal.outerRingRadius));
      expect(current.haloRadius, greaterThan(0));
      expect(current.haloRadius, 36.0);
      expect(current.badgeRadius, greaterThan(normal.badgeRadius));
    });

    test('shouldAttachBadgeToLowerRightMarkerEdgeWithoutBottomHanging', () {
      final normal = playbackMarkerIconMetricsForTesting(current: false);
      final current = playbackMarkerIconMetricsForTesting(current: true);

      expect(normal.badgeCenterX, greaterThan(normal.centerX));
      expect(normal.badgeCenterY, greaterThan(normal.centerY));
      expect(
        normal.badgeCenterY + normal.badgeRadius,
        lessThanOrEqualTo(normal.height - 5.0),
      );
      expect(
        _badgeCircleOverlap(normal),
        greaterThan(normal.badgeRadius * 0.75),
      );

      expect(current.badgeCenterX, greaterThan(current.centerX));
      expect(current.badgeCenterY, greaterThan(current.centerY));
      expect(
        current.badgeCenterY + current.badgeRadius,
        lessThanOrEqualTo(current.height - 7.0),
      );
      expect(
        _badgeCircleOverlap(current),
        greaterThan(current.badgeRadius * 0.75),
      );
    });

    test('shouldNormalizeDevicePixelRatioForCrispMapLibreBitmaps', () {
      expect(playbackMarkerPixelRatio(0), 1.0);
      expect(playbackMarkerPixelRatio(double.nan), 1.0);
      expect(playbackMarkerPixelRatio(2.625), 2.63);
      expect(playbackMarkerPixelRatio(4.0), 3.0);
    });

    test('shouldBoundPhotoDecodeTargetToRenderedMarkerBitmapSize', () {
      expect(
        playbackMarkerPhotoDecodeTargetSizeForTesting(
          current: false,
          pixelRatio: 3,
        ),
        198,
      );
      expect(
        playbackMarkerPhotoDecodeTargetSizeForTesting(
          current: true,
          pixelRatio: 3,
        ),
        240,
      );
      expect(
        playbackMarkerPhotoDecodeTargetSizeForTesting(
          current: true,
          pixelRatio: 8,
        ),
        240,
      );
    });
  });

  group('Playback marker visual identity', () {
    test('shouldResolvePhotoVisualWhenThumbnailBytesAreReady', () {
      final request = playbackMarkerIconRequest(
        sequenceNumber: 2,
        current: false,
        thumbnailPath: '/api/v1/media/private-media-id/thumbnail',
        thumbnailBytes: Uint8List.fromList(<int>[1, 2, 3]),
      );

      expect(request.identity.source, PlaybackMarkerVisualSource.photo);
      expect(request.sequenceNumber, 2);
      expect(request.imageKey, contains('.2.normal'));
      expect(request.imageKey, isNot(contains('private-media-id')));
      expect(request.imageKey, isNot(contains('/api/v1/media')));
    });

    test('shouldResolveNoPhotoMarkerToFallbackVisual', () {
      final request = playbackMarkerIconRequest(
        sequenceNumber: 1,
        current: false,
        thumbnailPath: null,
        thumbnailBytes: null,
      );

      expect(request.identity.source, PlaybackMarkerVisualSource.fallback);
      expect(request.imageKey, 'playback-marker.fallback.1.normal');
    });

    test('shouldResolveThumbnailFailureToFallbackVisual', () {
      final request = playbackMarkerIconRequest(
        sequenceNumber: 3,
        current: true,
        thumbnailPath: '/api/v1/media/private-media-id/thumbnail',
        thumbnailBytes: null,
      );

      expect(request.identity.source, PlaybackMarkerVisualSource.fallback);
      expect(request.imageKey, 'playback-marker.fallback.3.current');
    });

    test('shouldUseDifferentNormalAndCurrentPhotoIdentities', () {
      const path = '/api/v1/media/media-a/thumbnail';
      final bytes = Uint8List.fromList(<int>[1]);

      final normal = playbackMarkerIconRequest(
        sequenceNumber: 2,
        current: false,
        thumbnailPath: path,
        thumbnailBytes: bytes,
      );
      final current = playbackMarkerIconRequest(
        sequenceNumber: 2,
        current: true,
        thumbnailPath: path,
        thumbnailBytes: bytes,
      );

      expect(normal.identity.source, PlaybackMarkerVisualSource.photo);
      expect(current.identity.source, PlaybackMarkerVisualSource.photo);
      expect(normal.imageKey, isNot(current.imageKey));
      expect(normal.imageKey, contains('.2.normal'));
      expect(current.imageKey, contains('.2.current'));
    });

    test('shouldIncludePixelRatioWhenBitmapScaleChanges', () {
      final normal = playbackMarkerIconRequest(
        sequenceNumber: 2,
        current: false,
        thumbnailPath: null,
        thumbnailBytes: null,
      );
      final scaled = playbackMarkerIconRequest(
        sequenceNumber: 2,
        current: false,
        thumbnailPath: null,
        thumbnailBytes: null,
        pixelRatio: 2.75,
      );

      expect(normal.imageKey, 'playback-marker.fallback.2.normal');
      expect(scaled.imageKey, 'playback-marker.fallback.2.normal.x2_75');
      expect(normal.imageKey, isNot(scaled.imageKey));
    });

    test('shouldUseDifferentNormalAndCurrentFallbackIdentities', () {
      final normal = playbackMarkerIconRequest(
        sequenceNumber: 4,
        current: false,
        thumbnailPath: null,
        thumbnailBytes: null,
      );
      final current = playbackMarkerIconRequest(
        sequenceNumber: 4,
        current: true,
        thumbnailPath: null,
        thumbnailBytes: null,
      );

      expect(normal.imageKey, 'playback-marker.fallback.4.normal');
      expect(current.imageKey, 'playback-marker.fallback.4.current');
      expect(normal.imageKey, isNot(current.imageKey));
    });

    test('shouldKeepMarkerIconResolvableDuringCurrentTransition', () {
      const readyKeys = <String>{
        'playback-marker.fallback.1.normal',
        'playback-marker.fallback.2.normal',
        'playback-marker.fallback.3.normal',
        'playback-marker.fallback.4.normal',
        'playback-marker.fallback.1.current',
      };

      final firstCurrent = List<PlaybackMarkerIconRequest>.generate(
        4,
        (index) => playbackMarkerIconRequest(
          sequenceNumber: index + 1,
          current: index == 0,
          thumbnailPath: null,
          thumbnailBytes: null,
        ),
      );
      final secondCurrent = List<PlaybackMarkerIconRequest>.generate(
        4,
        (index) => playbackMarkerIconRequest(
          sequenceNumber: index + 1,
          current: index == 1,
          thumbnailPath: null,
          thumbnailBytes: null,
        ),
      );

      expect(_resolvedCount(firstCurrent, readyKeys), 4);
      expect(_resolvedCount(secondCurrent, readyKeys), 4);
    });

    test('shouldRejectInvalidSequenceNumber', () {
      expect(
        () => PlaybackMarkerVisualIdentity(
          sequenceNumber: 0,
          current: false,
          source: PlaybackMarkerVisualSource.fallback,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('shouldComposeScaledBitmapAndKeepTwoDigitBadgeRenderable', () async {
      final bytes = await composePlaybackMarkerIcon(
        photoBytes: null,
        sequenceNumber: 12,
        current: false,
        pixelRatio: 2,
      );
      final codec = await ui.instantiateImageCodec(bytes);
      addTearDown(codec.dispose);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      addTearDown(image.dispose);

      final metrics = playbackMarkerIconMetricsForTesting(current: false);
      expect(image.width, (metrics.width * 2).round());
      expect(image.height, (metrics.height * 2).round());
    });

    test('shouldComposeNeutralFallbackMarkerWithoutChangingGeometry', () async {
      final normal = playbackMarkerIconMetricsForTesting(current: false);
      final current = playbackMarkerIconMetricsForTesting(current: true);

      final normalBytes = await composePlaybackMarkerIcon(
        photoBytes: null,
        sequenceNumber: 3,
        current: false,
      );
      final currentBytes = await composePlaybackMarkerIcon(
        photoBytes: null,
        sequenceNumber: 3,
        current: true,
      );
      final normalImage = await _decodeImage(normalBytes);
      final currentImage = await _decodeImage(currentBytes);
      addTearDown(normalImage.dispose);
      addTearDown(currentImage.dispose);

      expect(normalImage.width, normal.width.toInt());
      expect(normalImage.height, normal.height.toInt());
      expect(currentImage.width, current.width.toInt());
      expect(currentImage.height, current.height.toInt());
    });
  });
}

double _badgeCircleOverlap(PlaybackMarkerIconMetrics metrics) {
  final dx = metrics.badgeCenterX - metrics.centerX;
  final dy = metrics.badgeCenterY - metrics.centerY;
  final distance = math.sqrt(dx * dx + dy * dy);
  return metrics.outerRingRadius + metrics.badgeRadius - distance;
}

Future<ui.Image> _decodeImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}

int _resolvedCount(
  List<PlaybackMarkerIconRequest> requests,
  Set<String> readyKeys,
) {
  return requests
      .map(
        (request) => resolveCompatibleMarkerIconKey(
          desiredImageKey: request.imageKey,
          compatibleImageKeys: request.compatibleImageKeys,
          hasIconBytes: readyKeys.contains,
        ),
      )
      .whereType<String>()
      .length;
}
