import 'dart:async';

import 'package:memory_map/features/playback/domain/playback_camera_command.dart';
import 'package:memory_map/features/playback/presentation/map/playback_map_camera_port.dart';

typedef PlaybackCameraArrived = void Function(int revision);
typedef PlaybackCameraFailed = void Function(int revision);

const double playbackMapCameraZoom = 12;

final class PlaybackMapCameraAdapter {
  PlaybackMapCameraAdapter({
    required PlaybackCameraArrived onCameraArrived,
    required PlaybackCameraFailed onCameraFailed,
  })  : _onCameraArrived = onCameraArrived,
        _onCameraFailed = onCameraFailed;

  final PlaybackCameraArrived _onCameraArrived;
  final PlaybackCameraFailed _onCameraFailed;
  PlaybackMapCameraPort? _camera;
  PlaybackCameraCommand? _latestCommand;
  int _controllerGeneration = 0;
  int? _lastStartedRevision;
  int? _lastStartedControllerGeneration;
  bool _styleReady = false;
  bool _disposed = false;

  bool get isReady => _camera != null && _styleReady && !_disposed;

  void attachCamera(PlaybackMapCameraPort camera) {
    if (_disposed) {
      return;
    }

    _camera = camera;
    _styleReady = false;
    _controllerGeneration += 1;
    _lastStartedRevision = null;
    _lastStartedControllerGeneration = null;
    _tryExecuteLatest();
  }

  void detachCamera() {
    if (_disposed) {
      return;
    }

    _camera = null;
    _styleReady = false;
    _controllerGeneration += 1;
    _lastStartedRevision = null;
    _lastStartedControllerGeneration = null;
  }

  void markStyleReady() {
    if (_disposed) {
      return;
    }

    _styleReady = true;
    _tryExecuteLatest();
  }

  void updateCommand(PlaybackCameraCommand? command) {
    if (_disposed) {
      return;
    }

    _latestCommand = command;
    _tryExecuteLatest();
  }

  void dispose() {
    _disposed = true;
    _camera = null;
    _latestCommand = null;
    _lastStartedRevision = null;
    _lastStartedControllerGeneration = null;
  }

  void _tryExecuteLatest() {
    final command = _latestCommand;
    final camera = _camera;
    if (command == null || camera == null || !isReady) {
      return;
    }

    if (_lastStartedRevision == command.revision &&
        _lastStartedControllerGeneration == _controllerGeneration) {
      return;
    }

    final generation = _controllerGeneration;
    _lastStartedRevision = command.revision;
    _lastStartedControllerGeneration = generation;

    unawaited(
      camera
          .moveTo(
            target: command.target,
            zoom: playbackMapCameraZoom,
            duration: command.duration,
          )
          .then((_) {
        if (_disposed ||
            _controllerGeneration != generation ||
            _latestCommand?.revision != command.revision) {
          return;
        }

        _onCameraArrived(command.revision);
      }, onError: (_) {
        if (_disposed ||
            _controllerGeneration != generation ||
            _latestCommand?.revision != command.revision) {
          return;
        }

        _onCameraFailed(command.revision);
      }),
    );
  }

  @override
  String toString() {
    return 'PlaybackMapCameraAdapter(isReady: $isReady, '
        'hasCommand: ${_latestCommand != null}, '
        'controllerGeneration: $_controllerGeneration)';
  }
}
