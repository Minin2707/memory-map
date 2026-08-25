import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';
import 'package:memory_map/features/map/presentation/widgets/maplibre_marker_synchronizer.dart';

void main() {
  group('MapLibreMarkerSynchronizer readiness', () {
    test('shouldStartLoadingUntilStyleLoads', () {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      );

      expect(synchronizer.styleLoaded, isFalse);
      expect(synchronizer.isLoading, isTrue);
      expect(controller.listenerCount, 1);
    });

    test('shouldIgnoreDuplicateStyleLoadedCallbacks', () {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      );

      expect(synchronizer.markStyleLoaded(), isTrue);
      expect(synchronizer.markStyleLoaded(), isFalse);
      expect(synchronizer.isLoading, isFalse);
      expect(controller.styleLoadedCalls, 2);
    });

    test('shouldResyncCurrentMarkersOnRepeatedStyleLoadedCallback', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      );

      synchronizer
        ..updateMarkers(<MapMarker>[markerA])
        ..markStyleLoaded();
      await flushMicrotasks();
      synchronizer.markStyleLoaded();
      await flushMicrotasks();

      expect(controller.annotations.length, 1);
      expect(controller.addedBatches.last, <MapMarkerRenderOptions>[
        MapMarkerRenderOptions(
          coordinate: markerA.coordinate,
          selected: false,
        ),
      ]);
    });

    test('shouldWaitForStyleSetupBeforeMarkerSync', () async {
      final controller = FakeAnnotationController()..pauseNextStyleLoad();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      );

      synchronizer
        ..updateMarkers(<MapMarker>[markerA])
        ..markStyleLoaded();
      await flushMicrotasks();

      expect(controller.styleLoadedCalls, 1);
      expect(controller.clearCalls, 0);
      expect(controller.addCalls, 0);

      controller.resumePausedStyleLoad();
      await flushMicrotasks();

      expect(controller.operations, <String>[
        'styleLoaded',
        'clearMarkers',
        'addMarkers',
      ]);
    });

    test('shouldCoalesceRepeatedStyleCallbacksWhileSetupIsPending', () async {
      final controller = FakeAnnotationController()..pauseNextStyleLoad();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      );

      synchronizer
        ..updateMarkers(<MapMarker>[markerA])
        ..markStyleLoaded();
      await flushMicrotasks();
      synchronizer.markStyleLoaded();
      await flushMicrotasks();

      expect(controller.styleLoadedCalls, 2);
      expect(controller.clearCalls, 0);
      expect(controller.addCalls, 0);

      controller.resumePausedStyleLoad();
      await flushMicrotasks();

      expect(controller.addCalls, 1);
      expect(controller.annotations.length, 1);
    });

    test('shouldNotCreateAnnotationsBeforeStyleLoaded', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      );

      synchronizer.updateMarkers(<MapMarker>[markerA]);
      await flushMicrotasks();

      expect(controller.clearCalls, 0);
      expect(controller.addCalls, 0);
    });

    test('shouldSyncLatestMarkersWhenStyleBecomesReady', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      );

      synchronizer
        ..updateMarkers(<MapMarker>[markerA])
        ..updateMarkers(<MapMarker>[markerB], selectedMarkerId: markerB.id)
        ..markStyleLoaded();
      await flushMicrotasks();

      expect(controller.clearCalls, 1);
      expect(controller.addCalls, 1);
      expect(controller.addedBatches.single, <MapMarkerRenderOptions>[
        MapMarkerRenderOptions(
          coordinate: markerB.coordinate,
          selected: true,
        ),
      ]);
    });
  });

  group('MapLibreMarkerSynchronizer reconciliation', () {
    test('shouldClearAndAddAllMarkersOnFirstSync', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      )..markStyleLoaded();
      await flushMicrotasks();

      synchronizer.updateMarkers(<MapMarker>[markerA, markerB]);
      await flushMicrotasks();

      expect(controller.clearCalls, 2);
      expect(controller.addedBatches.last, <MapMarkerRenderOptions>[
        MapMarkerRenderOptions(
          coordinate: markerA.coordinate,
          selected: false,
        ),
        MapMarkerRenderOptions(
          coordinate: markerB.coordinate,
          selected: false,
        ),
      ]);
    });

    test('shouldReconcileMarkerListChanges', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      )..markStyleLoaded();
      await flushMicrotasks();

      synchronizer.updateMarkers(<MapMarker>[markerA, markerB]);
      await flushMicrotasks();
      synchronizer.updateMarkers(<MapMarker>[movedMarkerA, markerC]);
      await flushMicrotasks();

      expect(controller.clearCalls, 3);
      expect(controller.addCalls, 2);
      expect(controller.addedBatches.last, <MapMarkerRenderOptions>[
        MapMarkerRenderOptions(
          coordinate: movedMarkerA.coordinate,
          selected: false,
        ),
        MapMarkerRenderOptions(
          coordinate: markerC.coordinate,
          selected: false,
        ),
      ]);
    });

    test('shouldApplySelectedMarkerRenderState', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      )..markStyleLoaded();
      await flushMicrotasks();

      synchronizer.updateMarkers(
        <MapMarker>[markerA, markerB],
        selectedMarkerId: markerB.id,
      );
      await flushMicrotasks();

      expect(controller.addedBatches.last, <MapMarkerRenderOptions>[
        MapMarkerRenderOptions(
          coordinate: markerA.coordinate,
          selected: false,
        ),
        MapMarkerRenderOptions(
          coordinate: markerB.coordinate,
          selected: true,
        ),
      ]);
    });

    test('shouldPassMarkerIconsThroughRenderOptions', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      )..markStyleLoaded();
      await flushMicrotasks();
      final icon = MapMarkerIcon(
        imageKey: 'marker-photo-safe-key',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      );

      synchronizer.updateMarkers(
        <MapMarker>[markerA],
        markerIcons: <String, MapMarkerIcon>{markerA.id: icon},
      );
      await flushMicrotasks();

      expect(controller.addedBatches.last, <MapMarkerRenderOptions>[
        MapMarkerRenderOptions(
          coordinate: markerA.coordinate,
          selected: false,
          icon: icon,
        ),
      ]);
    });

    test('shouldReconcileWhenMarkerIconChanges', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      )..markStyleLoaded();
      await flushMicrotasks();
      final firstIcon = MapMarkerIcon(
        imageKey: 'marker-photo-a',
        bytes: Uint8List.fromList(<int>[1]),
      );
      final secondIcon = MapMarkerIcon(
        imageKey: 'marker-photo-b',
        bytes: Uint8List.fromList(<int>[2]),
      );

      synchronizer.updateMarkers(
        <MapMarker>[markerA],
        markerIcons: <String, MapMarkerIcon>{markerA.id: firstIcon},
      );
      await flushMicrotasks();
      synchronizer.updateMarkers(
        <MapMarker>[markerA],
        markerIcons: <String, MapMarkerIcon>{markerA.id: secondIcon},
      );
      await flushMicrotasks();

      expect(controller.addCalls, 2);
      expect(controller.addedBatches.last.single.icon, secondIcon);
    });

    test('shouldReconcileWhenMarkerPhotoBecomesFallback', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      )..markStyleLoaded();
      await flushMicrotasks();
      final icon = MapMarkerIcon(
        imageKey: 'marker-photo-a',
        bytes: Uint8List.fromList(<int>[1]),
      );

      synchronizer.updateMarkers(
        <MapMarker>[markerA],
        markerIcons: <String, MapMarkerIcon>{markerA.id: icon},
      );
      await flushMicrotasks();
      synchronizer.updateMarkers(<MapMarker>[markerA]);
      await flushMicrotasks();

      expect(controller.addCalls, 2);
      expect(controller.addedBatches.last.single.icon, isNull);
    });

    test('shouldSkipRedundantSyncWhenRenderInputIsUnchanged', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      )..markStyleLoaded();
      await flushMicrotasks();

      synchronizer.updateMarkers(
        <MapMarker>[markerA, markerB],
        selectedMarkerId: markerB.id,
      );
      await flushMicrotasks();
      final clearCalls = controller.clearCalls;
      final addCalls = controller.addCalls;

      synchronizer.updateMarkers(
        <MapMarker>[
          MapMarker(id: markerA.id, coordinate: markerA.coordinate),
          MapMarker(id: markerB.id, coordinate: markerB.coordinate),
        ],
        selectedMarkerId: markerB.id,
      );
      await flushMicrotasks();

      expect(controller.clearCalls, clearCalls);
      expect(controller.addCalls, addCalls);
    });

    test('shouldReconcileWhenOnlySelectionChanges', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      )..markStyleLoaded();
      await flushMicrotasks();

      synchronizer.updateMarkers(<MapMarker>[markerA, markerB]);
      await flushMicrotasks();
      synchronizer.updateMarkers(
        <MapMarker>[markerA, markerB],
        selectedMarkerId: markerA.id,
      );
      await flushMicrotasks();

      expect(controller.addedBatches.last, <MapMarkerRenderOptions>[
        MapMarkerRenderOptions(
          coordinate: markerA.coordinate,
          selected: true,
        ),
        MapMarkerRenderOptions(
          coordinate: markerB.coordinate,
          selected: false,
        ),
      ]);
    });

    test('shouldPreserveAllMarkersWhenSelectingFirstMarker', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      )..markStyleLoaded();
      await flushMicrotasks();

      synchronizer.updateMarkers(fourMarkers);
      await flushMicrotasks();
      synchronizer.updateMarkers(fourMarkers, selectedMarkerId: markerA.id);
      await flushMicrotasks();

      expect(controller.annotations.length, 4);
      expect(
        controller.addedBatches.last.map((options) => options.selected),
        <bool>[true, false, false, false],
      );
    });

    test('shouldPreserveAllMarkersWhenMovingSelection', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      )..markStyleLoaded();
      await flushMicrotasks();

      synchronizer.updateMarkers(fourMarkers, selectedMarkerId: markerA.id);
      await flushMicrotasks();
      synchronizer.updateMarkers(fourMarkers, selectedMarkerId: markerB.id);
      await flushMicrotasks();

      expect(controller.annotations.length, 4);
      expect(
        controller.addedBatches.last.map((options) => options.selected),
        <bool>[false, true, false, false],
      );
    });

    test('shouldPreserveAllMarkersWhenClearingSelection', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      )..markStyleLoaded();
      await flushMicrotasks();

      synchronizer.updateMarkers(fourMarkers, selectedMarkerId: markerB.id);
      await flushMicrotasks();
      synchronizer.updateMarkers(fourMarkers);
      await flushMicrotasks();

      expect(controller.annotations.length, 4);
      expect(
        controller.addedBatches.last.map((options) => options.selected),
        <bool>[false, false, false, false],
      );
    });

    test('shouldPreserveMixedPhotoAndFallbackMarkersDuringSelection', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      )..markStyleLoaded();
      await flushMicrotasks();
      final photoIcon = MapMarkerIcon(
        imageKey: 'marker-photo-a',
        bytes: Uint8List.fromList(<int>[1]),
      );
      final fallbackIcon = MapMarkerIcon(
        imageKey: 'marker-fallback',
        bytes: Uint8List.fromList(<int>[2]),
      );

      synchronizer.updateMarkers(
        fourMarkers,
        markerIcons: <String, MapMarkerIcon>{
          markerA.id: photoIcon,
          markerB.id: fallbackIcon,
          markerC.id: photoIcon,
          markerD.id: fallbackIcon,
        },
        selectedMarkerId: markerB.id,
      );
      await flushMicrotasks();

      expect(controller.annotations.length, 4);
      expect(controller.addedBatches.last.map((options) => options.icon), [
        photoIcon,
        fallbackIcon,
        photoIcon,
        fallbackIcon,
      ]);
      expect(
        controller.addedBatches.last.map((options) => options.selected),
        <bool>[false, true, false, false],
      );
    });

    test('shouldClearAnnotationsWhenMarkerListBecomesEmpty', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      )..markStyleLoaded();
      await flushMicrotasks();

      synchronizer.updateMarkers(<MapMarker>[markerA]);
      await flushMicrotasks();
      synchronizer.updateMarkers(const <MapMarker>[]);
      await flushMicrotasks();

      expect(controller.clearCalls, 3);
      expect(controller.addCalls, 1);
      expect(controller.addedBatches.single.length, 1);
    });

    test('shouldKeepDuplicateCoordinatesAsSeparateAnnotations', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      )..markStyleLoaded();
      await flushMicrotasks();

      synchronizer.updateMarkers(<MapMarker>[markerA, markerD]);
      await flushMicrotasks();

      expect(controller.annotations.length, 2);
      expect(controller.addedBatches.last, <MapMarkerRenderOptions>[
        MapMarkerRenderOptions(
          coordinate: markerA.coordinate,
          selected: false,
        ),
        MapMarkerRenderOptions(
          coordinate: markerD.coordinate,
          selected: false,
        ),
      ]);
    });

    test('shouldUseLatestRequestedMarkersAfterConcurrentSync', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      )..markStyleLoaded();
      await flushMicrotasks();

      controller.pauseNextAdd();
      synchronizer.updateMarkers(<MapMarker>[markerA]);
      await flushMicrotasks();
      synchronizer.updateMarkers(<MapMarker>[markerB, markerC]);
      controller.resumePausedAdd();
      await flushMicrotasks();

      expect(controller.addedBatches.last, <MapMarkerRenderOptions>[
        MapMarkerRenderOptions(
          coordinate: markerB.coordinate,
          selected: false,
        ),
        MapMarkerRenderOptions(
          coordinate: markerC.coordinate,
          selected: false,
        ),
      ]);
    });

    test('shouldKeepLatestMovedSelectedMarkerAfterConcurrentSync', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      )..markStyleLoaded();
      await flushMicrotasks();

      controller.pauseNextAdd();
      synchronizer.updateMarkers(
        <MapMarker>[movedMarkerB],
        selectedMarkerId: movedMarkerB.id,
      );
      await flushMicrotasks();
      synchronizer.updateMarkers(
        <MapMarker>[latestMovedMarkerB],
        selectedMarkerId: latestMovedMarkerB.id,
      );
      controller.resumePausedAdd();
      await flushMicrotasks();

      expect(controller.addedBatches.last, <MapMarkerRenderOptions>[
        MapMarkerRenderOptions(
          coordinate: latestMovedMarkerB.coordinate,
          selected: true,
        ),
      ]);
    });
  });

  group('MapLibreMarkerSynchronizer marker selection', () {
    test('shouldReportOpaqueMarkerIdWhenAnnotationIsTapped', () async {
      final selectedIds = <String>[];
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
        onMarkerSelected: selectedIds.add,
      )..markStyleLoaded();
      await flushMicrotasks();

      synchronizer.updateMarkers(<MapMarker>[markerA, markerB]);
      await flushMicrotasks();

      controller.tap(controller.annotations[1]);

      expect(selectedIds, <String>[markerB.id]);
    });

    test('shouldIgnoreStaleAnnotationTapsAfterReconciliation', () async {
      final selectedIds = <String>[];
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
        onMarkerSelected: selectedIds.add,
      )..markStyleLoaded();
      await flushMicrotasks();

      synchronizer.updateMarkers(<MapMarker>[markerA]);
      await flushMicrotasks();
      final staleAnnotation = controller.annotations.single;
      synchronizer.updateMarkers(<MapMarker>[markerB]);
      await flushMicrotasks();

      controller.tap(staleAnnotation);

      expect(selectedIds, isEmpty);
    });

    test('shouldUseUpdatedSelectionHandler', () async {
      final firstSelectedIds = <String>[];
      final secondSelectedIds = <String>[];
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
        onMarkerSelected: firstSelectedIds.add,
      )..markStyleLoaded();
      await flushMicrotasks();

      synchronizer
        ..updateMarkers(<MapMarker>[markerA])
        ..updateSelectionHandler(secondSelectedIds.add);
      await flushMicrotasks();

      controller.tap(controller.annotations.single);

      expect(firstSelectedIds, isEmpty);
      expect(secondSelectedIds, <String>[markerA.id]);
    });

    test('shouldRemoveTapListenerAndClearMarkersOnDispose', () async {
      final selectedIds = <String>[];
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
        onMarkerSelected: selectedIds.add,
      )..markStyleLoaded();
      await flushMicrotasks();

      synchronizer.updateMarkers(<MapMarker>[markerA]);
      await flushMicrotasks();
      final annotation = controller.annotations.single;

      await synchronizer.dispose();
      controller.tap(annotation);

      expect(controller.listenerCount, 0);
      expect(controller.clearCalls, 3);
      expect(selectedIds, isEmpty);
    });

    test('shouldClearAfterInFlightMarkerRenderDuringDispose', () async {
      final controller = FakeAnnotationController();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      )..markStyleLoaded();
      await flushMicrotasks();

      controller.pauseNextAdd();
      synchronizer.updateMarkers(<MapMarker>[markerA]);
      await flushMicrotasks();

      final disposeFuture = synchronizer.dispose();
      await flushMicrotasks();

      expect(controller.operations, <String>[
        'styleLoaded',
        'clearMarkers',
        'clearMarkers',
        'addMarkers',
      ]);

      controller.resumePausedAdd();
      await disposeFuture;

      expect(controller.operations, <String>[
        'styleLoaded',
        'clearMarkers',
        'clearMarkers',
        'addMarkers',
        'clearMarkers',
      ]);
      expect(controller.annotations, isEmpty);
    });

    test('shouldIgnoreStaleSyncWhenDisposedDuringStyleSetup', () async {
      final controller = FakeAnnotationController()..pauseNextStyleLoad();
      final synchronizer = MapLibreMarkerSynchronizer<FakeAnnotation>(
        controller: controller,
      );

      synchronizer
        ..updateMarkers(<MapMarker>[markerA])
        ..markStyleLoaded();
      await flushMicrotasks();

      final disposeFuture = synchronizer.dispose();
      await flushMicrotasks();

      controller.resumePausedStyleLoad();
      await disposeFuture;

      expect(controller.operations, <String>[
        'styleLoaded',
        'clearMarkers',
      ]);
      expect(controller.addCalls, 0);
    });
  });

  group('MapMarkerRenderOptions', () {
    test('shouldUseValueEqualityAndHashCode', () {
      final first = MapMarkerRenderOptions(
        coordinate: coordinateA,
        selected: true,
      );
      final second = MapMarkerRenderOptions(
        coordinate: coordinateA,
        selected: true,
      );
      final different = MapMarkerRenderOptions(
        coordinate: coordinateA,
        selected: false,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
    });

    test('shouldIncludeIconIdentityInEquality', () {
      final icon = MapMarkerIcon(
        imageKey: 'safe-key',
        bytes: Uint8List.fromList(<int>[1]),
      );
      final first = MapMarkerRenderOptions(
        coordinate: coordinateA,
        selected: false,
        icon: icon,
      );
      final second = MapMarkerRenderOptions(
        coordinate: coordinateA,
        selected: false,
        icon: MapMarkerIcon(
          imageKey: 'safe-key',
          bytes: Uint8List.fromList(<int>[9]),
        ),
      );
      final different = MapMarkerRenderOptions(
        coordinate: coordinateA,
        selected: false,
        icon: MapMarkerIcon(
          imageKey: 'other-safe-key',
          bytes: Uint8List.fromList(<int>[1]),
        ),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
    });

    test('shouldRejectBlankMarkerIconKey', () {
      expect(
        () => MapMarkerIcon(
          imageKey: ' ',
          bytes: Uint8List.fromList(<int>[1]),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('shouldHaveSafeToString', () {
      final options = MapMarkerRenderOptions(
        coordinate: coordinateA,
        selected: true,
      );

      final text = options.toString();

      expect(text, contains('selected: true'));
      expect(text, contains('hasIcon: false'));
      expect(text, isNot(contains('41.7151')));
      expect(text, isNot(contains('44.8271')));
      expect(text, isNot(contains('memory')));
    });

    test('shouldHaveSafeMarkerIconToString', () {
      final icon = MapMarkerIcon(
        imageKey: 'private-memory-private-media-path',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      );

      final text = icon.toString();

      expect(text, 'MapMarkerIcon(hasBytes: true)');
      expect(text, isNot(contains('private-memory')));
      expect(text, isNot(contains('private-media')));
      expect(text, isNot(contains('path')));
      expect(text, isNot(contains('1, 2, 3')));
    });
  });
}

Future<void> flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final MapCoordinate coordinateA = MapCoordinate(
  latitude: 41.7151,
  longitude: 44.8271,
);

final MapCoordinate coordinateB = MapCoordinate(
  latitude: -12.0464,
  longitude: -77.0428,
);

final MapCoordinate coordinateC = MapCoordinate(
  latitude: 55.751244,
  longitude: 37.618423,
);

final MapMarker markerA = MapMarker(id: 'memory-a', coordinate: coordinateA);
final MapMarker movedMarkerA = MapMarker(id: 'memory-a', coordinate: coordinateC);
final MapMarker markerB = MapMarker(id: 'memory-b', coordinate: coordinateB);
final MapMarker movedMarkerB = MapMarker(id: 'memory-b', coordinate: coordinateA);
final MapMarker latestMovedMarkerB =
    MapMarker(id: 'memory-b', coordinate: coordinateC);
final MapMarker markerC = MapMarker(id: 'memory-c', coordinate: coordinateC);
final MapMarker markerD = MapMarker(id: 'memory-d', coordinate: coordinateA);
final List<MapMarker> fourMarkers = <MapMarker>[
  markerA,
  markerB,
  markerC,
  markerD,
];

final class FakeAnnotation {
  const FakeAnnotation(this.id);

  final int id;
}

final class FakeAnnotationController
    implements MapMarkerAnnotationController<FakeAnnotation> {
  final List<MapMarkerTapHandler<FakeAnnotation>> _listeners =
      <MapMarkerTapHandler<FakeAnnotation>>[];
  final List<FakeAnnotation> annotations = <FakeAnnotation>[];
  final List<List<MapMarkerRenderOptions>> addedBatches =
      <List<MapMarkerRenderOptions>>[];
  int clearCalls = 0;
  int addCalls = 0;
  int styleLoadedCalls = 0;
  final List<String> operations = <String>[];
  Completer<void>? _pausedStyleLoad;
  Completer<List<FakeAnnotation>>? _pausedAdd;

  int get listenerCount => _listeners.length;

  @override
  void addMarkerTapListener(MapMarkerTapHandler<FakeAnnotation> listener) {
    _listeners.add(listener);
  }

  @override
  void removeMarkerTapListener(MapMarkerTapHandler<FakeAnnotation> listener) {
    _listeners.remove(listener);
  }

  @override
  Future<void> handleStyleLoaded() async {
    styleLoadedCalls += 1;
    operations.add('styleLoaded');

    final pausedStyleLoad = _pausedStyleLoad;
    if (pausedStyleLoad != null) {
      await pausedStyleLoad.future;
      if (identical(_pausedStyleLoad, pausedStyleLoad)) {
        _pausedStyleLoad = null;
      }
    }
  }

  @override
  Future<void> clearMarkers() async {
    clearCalls += 1;
    operations.add('clearMarkers');
    annotations.clear();
  }

  @override
  Future<List<FakeAnnotation>> addMarkers(
    List<MapMarkerRenderOptions> options,
  ) async {
    addCalls += 1;
    operations.add('addMarkers');
    addedBatches.add(List<MapMarkerRenderOptions>.unmodifiable(options));

    final created = List<FakeAnnotation>.generate(
      options.length,
      (index) => FakeAnnotation(addCalls * 100 + index),
      growable: false,
    );

    final pausedAdd = _pausedAdd;
    if (pausedAdd != null) {
      await pausedAdd.future;
      if (identical(_pausedAdd, pausedAdd)) {
        _pausedAdd = null;
      }
    }

    annotations
      ..clear()
      ..addAll(created);
    return created;
  }

  void pauseNextAdd() {
    _pausedAdd = Completer<List<FakeAnnotation>>();
  }

  void resumePausedAdd() {
    _pausedAdd?.complete(const <FakeAnnotation>[]);
  }

  void pauseNextStyleLoad() {
    _pausedStyleLoad = Completer<void>();
  }

  void resumePausedStyleLoad() {
    _pausedStyleLoad?.complete();
  }

  void tap(FakeAnnotation annotation) {
    for (final listener in List<MapMarkerTapHandler<FakeAnnotation>>.of(
      _listeners,
    )) {
      listener(annotation);
    }
  }
}
