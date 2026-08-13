import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/playback/domain/playback_camera_command.dart';
import 'package:memory_map/features/playback/presentation/map/playback_map_camera_adapter.dart';
import 'package:memory_map/features/playback/presentation/map/playback_map_camera_port.dart';

void main() {
  group('PlaybackMapCameraAdapter command execution', () {
    test('shouldExecuteNewRevisionsOnceWithCommandDurationAndCoordinates', () async {
      final arrivals = <int>[];
      final camera = FakePlaybackMapCameraPort();
      final adapter = readyAdapter(camera, onCameraArrived: arrivals.add);

      adapter.updateCommand(command(1, target: coordinateA));
      await flushMicrotasks();
      adapter.updateCommand(command(1, target: coordinateA));
      await flushMicrotasks();
      adapter.updateCommand(command(2, target: coordinateB));
      await flushMicrotasks();

      expect(camera.moves.length, 2);
      expect(camera.moves[0].target, coordinateA);
      expect(camera.moves[0].zoom, playbackMapCameraZoom);
      expect(camera.moves[0].duration, const Duration(seconds: 2));
      expect(camera.moves[1].target, coordinateB);
      expect(arrivals, <int>[1, 2]);
    });

    test('shouldKeepCommandUntilMapAndStyleAreReady', () async {
      final arrivals = <int>[];
      final camera = FakePlaybackMapCameraPort();
      final adapter = PlaybackMapCameraAdapter(
        onCameraArrived: arrivals.add,
        onCameraFailed: (_) {},
      );

      adapter.updateCommand(command(1));
      await flushMicrotasks();
      adapter.attachCamera(camera);
      await flushMicrotasks();

      expect(camera.moves, isEmpty);

      adapter.markStyleReady();
      await flushMicrotasks();

      expect(camera.moves.single.target, coordinateA);
      expect(arrivals, <int>[1]);
    });

    test('shouldExecuteOnlyLatestPendingCommandWhenReady', () async {
      final arrivals = <int>[];
      final camera = FakePlaybackMapCameraPort();
      final adapter = PlaybackMapCameraAdapter(
        onCameraArrived: arrivals.add,
        onCameraFailed: (_) {},
      );

      adapter
        ..updateCommand(command(1, target: coordinateA))
        ..updateCommand(command(2, target: coordinateB))
        ..updateCommand(command(3, target: coordinateC))
        ..attachCamera(camera)
        ..markStyleReady();
      await flushMicrotasks();

      expect(camera.moves.length, 1);
      expect(camera.moves.single.target, coordinateC);
      expect(arrivals, <int>[3]);
    });
  });

  group('PlaybackMapCameraAdapter latest wins', () {
    test('shouldSuppressStaleCompletionAfterNewCommandStarts', () async {
      final arrivals = <int>[];
      final camera = FakePlaybackMapCameraPort(autoComplete: false);
      final adapter = readyAdapter(camera, onCameraArrived: arrivals.add);

      adapter.updateCommand(command(1, target: coordinateA));
      await flushMicrotasks();
      adapter.updateCommand(command(2, target: coordinateB));
      await flushMicrotasks();

      camera.moves[0].complete();
      await flushMicrotasks();

      expect(arrivals, isEmpty);

      camera.moves[1].complete();
      await flushMicrotasks();

      expect(arrivals, <int>[2]);
    });

    test('shouldReplayCurrentRevisionForNewControllerGeneration', () async {
      final arrivals = <int>[];
      final firstCamera = FakePlaybackMapCameraPort(autoComplete: false);
      final secondCamera = FakePlaybackMapCameraPort();
      final adapter = PlaybackMapCameraAdapter(
        onCameraArrived: arrivals.add,
        onCameraFailed: (_) {},
      );

      adapter
        ..updateCommand(command(3, target: coordinateC))
        ..attachCamera(firstCamera)
        ..markStyleReady();
      await flushMicrotasks();

      expect(firstCamera.moves.length, 1);

      adapter.attachCamera(secondCamera);
      await flushMicrotasks();

      expect(secondCamera.moves, isEmpty);

      adapter.markStyleReady();
      await flushMicrotasks();

      expect(secondCamera.moves.length, 1);
      expect(secondCamera.moves.single.target, coordinateC);
      expect(arrivals, <int>[3]);
    });

    test('shouldNotEmitArrivalAfterDispose', () async {
      final arrivals = <int>[];
      final camera = FakePlaybackMapCameraPort(autoComplete: false);
      final adapter = readyAdapter(camera, onCameraArrived: arrivals.add);

      adapter.updateCommand(command(1));
      await flushMicrotasks();
      adapter.dispose();
      camera.moves.single.complete();
      await flushMicrotasks();

      expect(arrivals, isEmpty);
    });

    test('shouldSuppressCompletionAfterCameraDetach', () async {
      final arrivals = <int>[];
      final failures = <int>[];
      final camera = FakePlaybackMapCameraPort(autoComplete: false);
      final adapter = readyAdapter(
        camera,
        onCameraArrived: arrivals.add,
        onCameraFailed: failures.add,
      );

      adapter.updateCommand(command(1));
      await flushMicrotasks();
      adapter.detachCamera();
      camera.moves.single.complete();
      await flushMicrotasks();

      expect(arrivals, isEmpty);
      expect(failures, isEmpty);
    });
  });

  group('PlaybackMapCameraAdapter failure and privacy', () {
    test('shouldReportCurrentTechnicalCameraFailureWithoutArrival', () async {
      final arrivals = <int>[];
      final failures = <int>[];
      final camera = FakePlaybackMapCameraPort(autoComplete: false);
      final adapter = readyAdapter(
        camera,
        onCameraArrived: arrivals.add,
        onCameraFailed: failures.add,
      );

      adapter.updateCommand(command(1));
      await flushMicrotasks();
      camera.moves.single.completeError(StateError('map failed'));
      await flushMicrotasks();

      expect(arrivals, isEmpty);
      expect(failures, <int>[1]);
    });

    test('shouldSuppressStaleTechnicalCameraFailure', () async {
      final arrivals = <int>[];
      final failures = <int>[];
      final camera = FakePlaybackMapCameraPort(autoComplete: false);
      final adapter = readyAdapter(
        camera,
        onCameraArrived: arrivals.add,
        onCameraFailed: failures.add,
      );

      adapter.updateCommand(command(1));
      await flushMicrotasks();
      adapter.updateCommand(command(2));
      await flushMicrotasks();
      camera.moves[0].completeError(StateError('old map failed'));
      await flushMicrotasks();
      camera.moves[1].completeError(StateError('current map failed'));
      await flushMicrotasks();

      expect(arrivals, isEmpty);
      expect(failures, <int>[2]);
    });

    test('shouldSuppressFailureAfterControllerGenerationChanges', () async {
      final failures = <int>[];
      final firstCamera = FakePlaybackMapCameraPort(autoComplete: false);
      final secondCamera = FakePlaybackMapCameraPort(autoComplete: false);
      final adapter = readyAdapter(
        firstCamera,
        onCameraArrived: (_) {},
        onCameraFailed: failures.add,
      );

      adapter.updateCommand(command(1));
      await flushMicrotasks();
      adapter.attachCamera(secondCamera);
      adapter.markStyleReady();
      await flushMicrotasks();

      firstCamera.moves.single.completeError(StateError('old map failed'));
      await flushMicrotasks();
      secondCamera.moves.single.completeError(StateError('new map failed'));
      await flushMicrotasks();

      expect(failures, <int>[1]);
    });

    test('shouldSuppressFailureAfterDispose', () async {
      final failures = <int>[];
      final camera = FakePlaybackMapCameraPort(autoComplete: false);
      final adapter = readyAdapter(
        camera,
        onCameraArrived: (_) {},
        onCameraFailed: failures.add,
      );

      adapter.updateCommand(command(1));
      await flushMicrotasks();
      adapter.dispose();
      camera.moves.single.completeError(StateError('map failed'));
      await flushMicrotasks();

      expect(failures, isEmpty);
    });

    test('shouldHaveSafeToString', () {
      final adapter = PlaybackMapCameraAdapter(
        onCameraArrived: (_) {},
        onCameraFailed: (_) {},
      );

      adapter.updateCommand(command(7, target: coordinateC));

      final text = adapter.toString();
      expect(text, contains('hasCommand: true'));
      expect(text, isNot(contains('55.751244')));
      expect(text, isNot(contains('37.618423')));
      expect(text, isNot(contains('memory')));
    });
  });
}

PlaybackMapCameraAdapter readyAdapter(
  PlaybackMapCameraPort camera,
  {
  required PlaybackCameraArrived onCameraArrived,
  PlaybackCameraFailed? onCameraFailed,
}) {
  return PlaybackMapCameraAdapter(
    onCameraArrived: onCameraArrived,
    onCameraFailed: onCameraFailed ?? (_) {},
  )
    ..attachCamera(camera)
    ..markStyleReady();
}

PlaybackCameraCommand command(
  int revision, {
  MapCoordinate? target,
}) {
  return PlaybackCameraCommand(
    revision: revision,
    memoryIndex: revision - 1,
    target: target ?? coordinateA,
    duration: const Duration(seconds: 2),
  );
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

final class FakePlaybackMapCameraPort implements PlaybackMapCameraPort {
  FakePlaybackMapCameraPort({this.autoComplete = true});

  final bool autoComplete;
  final List<FakeCameraMove> moves = <FakeCameraMove>[];

  @override
  Future<void> moveTo({
    required MapCoordinate target,
    required double zoom,
    required Duration duration,
  }) {
    final move = FakeCameraMove(
      target: target,
      zoom: zoom,
      duration: duration,
    );
    moves.add(move);

    if (autoComplete) {
      move.complete();
    }

    return move.future;
  }
}

final class FakeCameraMove {
  FakeCameraMove({
    required this.target,
    required this.zoom,
    required this.duration,
  });

  final MapCoordinate target;
  final double zoom;
  final Duration duration;
  final Completer<void> _completer = Completer<void>();

  Future<void> get future => _completer.future;

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  void completeError(Object error) {
    if (!_completer.isCompleted) {
      _completer.completeError(error);
    }
  }
}
