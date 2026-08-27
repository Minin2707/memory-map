import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/playback/domain/playback_camera_command.dart';
import 'package:memory_map/features/playback/presentation/map/playback_map_view.dart';
import 'package:memory_map/features/playback/presentation/map/playback_marker_visual.dart';
import 'package:memory_map/features/playback/presentation/map/playback_route_projection.dart';

void main() {
  group('PlaybackMapView interaction policy', () {
    test('shouldDisableManualMapGesturesForCameraControlledPlayback', () {
      expect(playbackMapInteractionPolicy.scrollGesturesEnabled, isFalse);
      expect(playbackMapInteractionPolicy.zoomGesturesEnabled, isFalse);
      expect(playbackMapInteractionPolicy.rotateGesturesEnabled, isFalse);
      expect(playbackMapInteractionPolicy.tiltGesturesEnabled, isFalse);
    });
  });

  group('PlaybackMapView callback contract', () {
    test('shouldRequireCameraArrivalAndFailureCallbacks', () {
      final view = PlaybackMapView(
        markers: const [],
        route: PlaybackRouteProjection(),
        currentIndex: null,
        cameraCommand: PlaybackCameraCommand(
          revision: 1,
          memoryIndex: 0,
          target: MapCoordinate(latitude: 41.7151, longitude: 44.8271),
          duration: const Duration(seconds: 2),
        ),
        onCameraArrived: (_) {},
        onCameraFailed: (_) {},
      );

      expect(view.onCameraArrived, isA<ValueChanged<int>>());
      expect(view.onCameraFailed, isA<ValueChanged<int>>());
      expect(view.route.hasRoute, isFalse);
    });
  });

  group('PlaybackMapView route GeoJSON boundary', () {
    test('shouldUseLongitudeLatitudeCoordinateOrderForRouteLineString', () {
      final geoJson = playbackRouteGeoJsonForTesting(<MapCoordinate>[
        MapCoordinate(latitude: 41.7151, longitude: 44.8271),
        MapCoordinate(latitude: -12.0464, longitude: -77.0428),
      ]);
      final features = geoJson['features']! as List<Object>;
      final feature = features.single as Map<String, Object>;
      final geometry = feature['geometry']! as Map<String, Object>;

      expect(
        geometry['coordinates'],
        <List<double>>[
          <double>[44.8271, 41.7151],
          <double>[-77.0428, -12.0464],
        ],
      );
    });
  });

  group('PlaybackMapView marker icon composition policy', () {
    test('shouldPrioritizeCurrentMarkerIconBeforeQueuedNormalIcons', () {
      final ordered = playbackMarkerIconCompositionOrderForTesting(
        <PlaybackMarkerIconRequest>[
          markerIconRequest(1),
          markerIconRequest(2),
          markerIconRequest(3, current: true),
        ],
      );

      expect(ordered.map((request) => request.sequenceNumber), <int>[3, 1, 2]);
    });

    test('shouldLimitConcurrentMarkerIconComposition', () async {
      final limiter = PlaybackMarkerIconCompositionLimiter(maxConcurrent: 3);
      final running = <Completer<void>>[];
      var active = 0;
      var maxActive = 0;

      Future<void> runner(PlaybackMarkerIconRequest _) {
        active += 1;
        maxActive = math.max(maxActive, active);
        final completer = Completer<void>();
        running.add(completer);
        return completer.future.whenComplete(() {
          active -= 1;
        });
      }

      for (var index = 1; index <= 8; index += 1) {
        limiter.enqueue(markerIconRequest(index), runner, priority: false);
      }

      expect(maxActive, 3);
      expect(limiter.activeCount, 3);
      expect(limiter.queuedCount, 5);

      while (!limiter.isIdle) {
        for (final completer in running.where((completer) {
          return !completer.isCompleted;
        }).toList(growable: false)) {
          completer.complete();
        }
        await Future<void>.delayed(Duration.zero);
      }

      expect(maxActive, 3);
    });

    test('shouldRunQueuedCurrentMarkerBeforeNormalMarkerWhenSlotFrees', () async {
      final limiter = PlaybackMarkerIconCompositionLimiter(maxConcurrent: 1);
      final first = Completer<void>();
      final second = Completer<void>();
      final third = Completer<void>();
      final started = <int>[];

      Future<void> runner(PlaybackMarkerIconRequest request) {
        started.add(request.sequenceNumber);
        return switch (request.sequenceNumber) {
          1 => first.future,
          3 => second.future,
          _ => third.future,
        };
      }

      limiter.enqueue(markerIconRequest(1), runner, priority: false);
      limiter.enqueue(markerIconRequest(2), runner, priority: false);
      limiter.enqueue(
        markerIconRequest(3, current: true),
        runner,
        priority: true,
      );

      expect(started, <int>[1]);
      first.complete();
      await Future<void>.delayed(Duration.zero);

      expect(started, <int>[1, 3]);
      second.complete();
      await Future<void>.delayed(Duration.zero);
      third.complete();
      await Future<void>.delayed(Duration.zero);
    });

    test('shouldDropObsoleteQueuedIconWork', () async {
      final limiter = PlaybackMarkerIconCompositionLimiter(maxConcurrent: 1);
      final activeCompleter = Completer<void>();

      Future<void> runner(PlaybackMarkerIconRequest _) {
        return activeCompleter.future;
      }

      final active = markerIconRequest(1);
      final obsolete = markerIconRequest(2);
      limiter.enqueue(active, runner, priority: false);
      limiter.enqueue(obsolete, runner, priority: false);

      expect(limiter.activeCount, 1);
      expect(limiter.queuedCount, 1);

      limiter.retainQueuedKeys(<String>{active.imageKey});

      expect(limiter.queuedCount, 0);
      expect(limiter.hasQueued(obsolete.imageKey), isFalse);
      activeCompleter.complete();
      await Future<void>.delayed(Duration.zero);
    });

    test('shouldRetainOnlyCurrentAndCompatibleMarkerIconKeys', () {
      final request = markerIconRequest(
        2,
        current: true,
        thumbnailPath: '/api/v1/media/media-a/thumbnail',
        thumbnailBytes: Uint8List.fromList(<int>[1, 2, 3]),
      );
      final relevantKeys = playbackRelevantMarkerIconKeysForTesting(
        <String, PlaybackMarkerIconRequest>{
          'playback-marker-1': request,
        },
      );

      expect(relevantKeys, contains(request.imageKey));
      expect(
        relevantKeys,
        contains(
          playbackMarkerIconRequest(
            sequenceNumber: 2,
            current: false,
            thumbnailPath: '/api/v1/media/media-a/thumbnail',
            thumbnailBytes: Uint8List.fromList(<int>[1, 2, 3]),
          ).imageKey,
        ),
      );
      expect(relevantKeys, contains('playback-marker.fallback.2.current'));
      expect(relevantKeys, contains('playback-marker.fallback.2.normal'));
      expect(relevantKeys, isNot(contains('playback-marker.fallback.9.normal')));
    });
  });
}

PlaybackMarkerIconRequest markerIconRequest(
  int sequenceNumber, {
  bool current = false,
  String? thumbnailPath,
  Uint8List? thumbnailBytes,
}) {
  return playbackMarkerIconRequest(
    sequenceNumber: sequenceNumber,
    current: current,
    thumbnailPath: thumbnailPath,
    thumbnailBytes: thumbnailBytes,
  );
}
