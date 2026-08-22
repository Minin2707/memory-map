import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/playback/presentation/map/playback_route_projection.dart';
import 'package:memory_map/features/playback/presentation/map/playback_route_synchronizer.dart';

void main() {
  group('PlaybackRouteSynchronizer style readiness', () {
    test('shouldRetainRouteBeforeStyleReadyAndRenderAfterStyleLoaded', () async {
      final controller = FakePlaybackRouteController();
      final synchronizer = PlaybackRouteSynchronizer(controller: controller);

      synchronizer.updateRoute(route(1, 2));
      await pumpQueue();

      expect(controller.operations, isEmpty);

      final changed = synchronizer.markStyleLoaded();
      await pumpQueue();

      expect(changed, isTrue);
      expect(controller.operations, <String>['clearRoute', 'addRoute']);
      expect(controller.routes.single.coordinates, <MapCoordinate>[
        coordinate(41, 44),
        coordinate(42, 45),
      ]);
      expect(controller.routes.single.lineColor, playbackRouteLineColor);
      expect(controller.routes.single.lineOpacity, playbackRouteLineOpacity);
      expect(controller.routes.single.lineWidth, playbackRouteLineWidth);
      expect(
        controller.routes.single.lineDasharray,
        playbackRouteLineDasharray,
      );
    });

    test('shouldNotRenderEmptyOrSinglePointRoutes', () async {
      final controller = FakePlaybackRouteController();
      final synchronizer = PlaybackRouteSynchronizer(controller: controller);

      synchronizer
        ..updateRoute(PlaybackRouteProjection())
        ..markStyleLoaded();
      await pumpQueue();

      expect(controller.operations, <String>['clearRoute']);
      expect(controller.routes, isEmpty);

      synchronizer.updateRoute(PlaybackRouteProjection(
        coordinates: <MapCoordinate>[coordinate(41, 44)],
      ));
      await pumpQueue();

      expect(controller.operations, <String>['clearRoute']);
      expect(controller.routes, isEmpty);
    });
  });

  group('PlaybackRouteSynchronizer reconciliation', () {
    test('shouldNotDuplicateSourceRouteForSameInput', () async {
      final controller = FakePlaybackRouteController();
      final synchronizer = PlaybackRouteSynchronizer(controller: controller);
      final projectedRoute = route(1, 2, 3);

      synchronizer
        ..updateRoute(projectedRoute)
        ..markStyleLoaded();
      await pumpQueue();
      synchronizer.updateRoute(projectedRoute);
      await pumpQueue();

      expect(controller.operations, <String>['clearRoute', 'addRoute']);
      expect(controller.routes.length, 1);
    });

    test('shouldReplaceGeometryWhenRouteChanges', () async {
      final controller = FakePlaybackRouteController();
      final synchronizer = PlaybackRouteSynchronizer(controller: controller);

      synchronizer
        ..updateRoute(route(1, 2))
        ..markStyleLoaded();
      await pumpQueue();
      synchronizer.updateRoute(route(1, 2, 3));
      await pumpQueue();

      expect(controller.operations, <String>[
        'clearRoute',
        'addRoute',
        'clearRoute',
        'addRoute',
      ]);
      expect(controller.routes.last.coordinates, <MapCoordinate>[
        coordinate(41, 44),
        coordinate(42, 45),
        coordinate(43, 46),
      ]);
    });

    test('shouldRestoreDottedRouteWhenStyleReloads', () async {
      final controller = FakePlaybackRouteController();
      final synchronizer = PlaybackRouteSynchronizer(controller: controller);

      synchronizer
        ..updateRoute(route(1, 2))
        ..markStyleLoaded();
      await pumpQueue();

      final changed = synchronizer.markStyleLoaded();
      await pumpQueue();

      expect(changed, isFalse);
      expect(controller.operations, <String>[
        'clearRoute',
        'addRoute',
        'clearRoute',
        'addRoute',
      ]);
      expect(controller.routes.length, 2);
      expect(controller.routes.last.lineDasharray, playbackRouteLineDasharray);
    });

    test('shouldClearOnDisposeAndPreventLateMutation', () async {
      final controller = FakePlaybackRouteController();
      final synchronizer = PlaybackRouteSynchronizer(controller: controller);

      synchronizer
        ..updateRoute(route(1, 2))
        ..markStyleLoaded();
      await pumpQueue();
      await synchronizer.dispose();
      synchronizer.updateRoute(route(1, 2, 3));
      synchronizer.markStyleLoaded();
      await pumpQueue();

      expect(controller.operations, <String>[
        'clearRoute',
        'addRoute',
        'clearRoute',
      ]);
      expect(controller.routes.length, 1);
    });

    test('shouldClearAfterInFlightRenderDuringDispose', () async {
      final addCompleter = Completer<void>();
      final controller = FakePlaybackRouteController()
        ..addCompleter = addCompleter;
      final synchronizer = PlaybackRouteSynchronizer(controller: controller);

      synchronizer
        ..updateRoute(route(1, 2))
        ..markStyleLoaded();
      await pumpQueue();

      final disposeFuture = synchronizer.dispose();
      await pumpQueue();

      expect(controller.operations, <String>['clearRoute', 'addRoute']);
      addCompleter.complete();
      await disposeFuture;

      expect(controller.operations, <String>[
        'clearRoute',
        'addRoute',
        'clearRoute',
      ]);
      synchronizer.updateRoute(route(1, 2, 3));
      await pumpQueue();
      expect(controller.routes.length, 1);
    });

    test('shouldKeepDiagnosticsPrivate', () {
      final options = PlaybackRouteRenderOptions(
        coordinates: <MapCoordinate>[
          coordinate(41.715123, 44.827456),
          coordinate(-12.0464, -77.0428),
        ],
      );

      final text = options.toString();

      expect(text, contains('pointCount: 2'));
      expect(text, isNot(contains('41.715123')));
      expect(text, isNot(contains('44.827456')));
      expect(text, isNot(contains('-77.0428')));
      expect(text, isNot(contains('memory-id')));
    });

    test('shouldUseImmutableDottedRouteStyleValueEquality', () {
      final dasharray = <double>[1.4, 2.2];
      final first = PlaybackRouteRenderOptions(
        coordinates: <MapCoordinate>[coordinate(41, 44), coordinate(42, 45)],
        lineDasharray: dasharray,
      );
      final second = PlaybackRouteRenderOptions(
        coordinates: <MapCoordinate>[coordinate(41, 44), coordinate(42, 45)],
        lineDasharray: <double>[1.4, 2.2],
      );

      dasharray.add(9.9);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.lineDasharray, <double>[1.4, 2.2]);
      expect(
        () => first.lineDasharray.add(3.3),
        throwsUnsupportedError,
      );
    });
  });
}

Future<void> pumpQueue() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

PlaybackRouteProjection route(int first, int second, [int? third]) {
  return PlaybackRouteProjection(
    coordinates: <MapCoordinate>[
      coordinate(40.0 + first, 43.0 + first),
      coordinate(40.0 + second, 43.0 + second),
      if (third != null) coordinate(40.0 + third, 43.0 + third),
    ],
  );
}

MapCoordinate coordinate(double latitude, double longitude) {
  return MapCoordinate(latitude: latitude, longitude: longitude);
}

final class FakePlaybackRouteController
    implements PlaybackRouteAnnotationController {
  final List<String> operations = <String>[];
  final List<PlaybackRouteRenderOptions> routes =
      <PlaybackRouteRenderOptions>[];
  Completer<void>? clearCompleter;
  Completer<void>? addCompleter;

  @override
  Future<void> clearRoute() async {
    operations.add('clearRoute');

    final completer = clearCompleter;
    if (completer != null) {
      clearCompleter = null;
      await completer.future;
    }
  }

  @override
  Future<void> addRoute(PlaybackRouteRenderOptions options) async {
    operations.add('addRoute');
    routes.add(options);

    final completer = addCompleter;
    if (completer != null) {
      addCompleter = null;
      await completer.future;
    }
  }
}
