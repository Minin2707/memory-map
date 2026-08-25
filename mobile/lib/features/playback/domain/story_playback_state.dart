import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/playback/domain/playback_camera_command.dart';
import 'package:memory_map/features/playback/domain/playback_phase.dart';
import 'package:memory_map/features/playback/domain/playback_policy.dart';
import 'package:memory_map/features/playback/domain/playback_progress.dart';
import 'package:memory_map/features/playback/domain/playback_status.dart';

final class StoryPlaybackState {
  factory StoryPlaybackState.idle({
    PlaybackPolicy policy = const PlaybackPolicy(),
  }) {
    return StoryPlaybackState._(
      snapshot: const <MemoryReadModel>[],
      status: PlaybackStatus.idle,
      phase: null,
      currentIndex: null,
      cameraRevision: 0,
      presentationRevision: 0,
      cameraCommand: null,
      policy: policy,
    );
  }

  factory StoryPlaybackState.start(
    List<MemoryReadModel> memories, {
    PlaybackPolicy policy = const PlaybackPolicy(),
  }) {
    final snapshot = _canonicalSnapshot(memories);
    if (snapshot.isEmpty) {
      return StoryPlaybackState.idle(policy: policy);
    }

    return StoryPlaybackState._(
      snapshot: snapshot,
      status: PlaybackStatus.playing,
      phase: PlaybackPhase.moving,
      currentIndex: 0,
      cameraRevision: 1,
      presentationRevision: 0,
      cameraCommand: _cameraCommandFor(
        snapshot: snapshot,
        index: 0,
        originIndex: null,
        revision: 1,
        policy: policy,
      ),
      policy: policy,
    );
  }

  const StoryPlaybackState._({
    required this.snapshot,
    required this.status,
    required this.phase,
    required this.currentIndex,
    required this.cameraRevision,
    required this.presentationRevision,
    required this.cameraCommand,
    required this.policy,
  });

  final List<MemoryReadModel> snapshot;
  final PlaybackStatus status;
  final PlaybackPhase? phase;
  final int? currentIndex;
  final int cameraRevision;
  final int presentationRevision;
  final PlaybackCameraCommand? cameraCommand;
  final PlaybackPolicy policy;

  bool get hasSnapshot => snapshot.isNotEmpty;

  bool get isIdle => status == PlaybackStatus.idle;

  bool get isPlaying => status == PlaybackStatus.playing;

  bool get isPaused => status == PlaybackStatus.paused;

  bool get isFinished => status == PlaybackStatus.finished;

  bool get isMoving => phase == PlaybackPhase.moving;

  bool get isPresenting => phase == PlaybackPhase.presenting;

  bool get isDismissing => phase == PlaybackPhase.dismissing;

  MemoryReadModel? get currentMemory {
    final index = currentIndex;
    if (index == null || index < 0 || index >= snapshot.length) {
      return null;
    }

    return snapshot[index];
  }

  PlaybackProgress get progress {
    if (snapshot.isEmpty) {
      return PlaybackProgress(currentPosition: 0, total: 0);
    }

    if (status == PlaybackStatus.idle || currentIndex == null) {
      return PlaybackProgress(currentPosition: 0, total: snapshot.length);
    }

    return PlaybackProgress(
      currentPosition: currentIndex! + 1,
      total: snapshot.length,
    );
  }

  StoryPlaybackState cameraArrived(int revision) {
    if (status != PlaybackStatus.playing ||
        phase != PlaybackPhase.moving ||
        revision != cameraRevision ||
        currentIndex == null) {
      return this;
    }

    return _copyWith(
      phase: PlaybackPhase.presenting,
      presentationRevision: presentationRevision + 1,
      clearCameraCommand: true,
    );
  }

  StoryPlaybackState presentationElapsed(int revision) {
    if (status != PlaybackStatus.playing ||
        (phase != PlaybackPhase.presenting &&
            phase != PlaybackPhase.dismissing) ||
        revision != presentationRevision ||
        currentIndex == null) {
      return this;
    }

    if (currentIndex == snapshot.length - 1) {
      return _copyWith(
        status: PlaybackStatus.finished,
        phase: null,
        clearPhase: true,
        clearCameraCommand: true,
      );
    }

    return _moveTo(currentIndex! + 1, status: PlaybackStatus.playing);
  }

  StoryPlaybackState beginPresentationDismissal(int revision) {
    if (status != PlaybackStatus.playing ||
        phase != PlaybackPhase.presenting ||
        revision != presentationRevision ||
        currentIndex == null ||
        currentIndex == snapshot.length - 1) {
      return this;
    }

    return _copyWith(phase: PlaybackPhase.dismissing);
  }

  StoryPlaybackState pause() {
    if (status != PlaybackStatus.playing) {
      return this;
    }

    return _copyWith(
      status: PlaybackStatus.paused,
      presentationRevision:
          phase == PlaybackPhase.presenting || phase == PlaybackPhase.dismissing
              ? presentationRevision + 1
              : presentationRevision,
    );
  }

  StoryPlaybackState resume() {
    if (status != PlaybackStatus.paused || currentIndex == null) {
      return this;
    }

    if (phase == PlaybackPhase.moving) {
      return _moveTo(currentIndex!, status: PlaybackStatus.playing);
    }

    if (phase == PlaybackPhase.presenting) {
      return _copyWith(
        status: PlaybackStatus.playing,
        presentationRevision: presentationRevision + 1,
      );
    }

    if (phase == PlaybackPhase.dismissing) {
      return _copyWith(status: PlaybackStatus.playing);
    }

    return this;
  }

  StoryPlaybackState retryCamera() {
    if (status != PlaybackStatus.playing ||
        currentIndex == null ||
        phase != PlaybackPhase.moving) {
      return this;
    }

    return _moveTo(currentIndex!, status: PlaybackStatus.playing);
  }

  StoryPlaybackState next() {
    if (!_canNavigate) {
      return this;
    }

    if (currentIndex == snapshot.length - 1) {
      if (phase == PlaybackPhase.presenting) {
        return _copyWith(
          status: PlaybackStatus.finished,
          phase: null,
          clearPhase: true,
          presentationRevision: presentationRevision + 1,
          clearCameraCommand: true,
        );
      }

      return this;
    }

    return _moveTo(
      currentIndex! + 1,
      status: status,
      issueCameraCommand: status == PlaybackStatus.playing,
    );
  }

  StoryPlaybackState previous() {
    if (!_canNavigate || currentIndex == 0) {
      return this;
    }

    return _moveTo(
      currentIndex! - 1,
      status: status,
      issueCameraCommand: status == PlaybackStatus.playing,
    );
  }

  StoryPlaybackState replay() {
    if (snapshot.isEmpty) {
      return this;
    }

    return _moveTo(0, status: PlaybackStatus.playing);
  }

  StoryPlaybackState stop() {
    return StoryPlaybackState.idle(policy: policy)._copyWith(
      cameraRevision: cameraRevision + 1,
      presentationRevision: presentationRevision + 1,
    );
  }

  bool get _canNavigate {
    return snapshot.isNotEmpty &&
        currentIndex != null &&
        (status == PlaybackStatus.playing || status == PlaybackStatus.paused);
  }

  StoryPlaybackState _moveTo(
    int index, {
    required PlaybackStatus status,
    bool issueCameraCommand = true,
  }) {
    final nextCameraRevision = cameraRevision + 1;

    return _copyWith(
      status: status,
      phase: PlaybackPhase.moving,
      currentIndex: index,
      cameraRevision: nextCameraRevision,
      presentationRevision: presentationRevision + 1,
      cameraCommand: issueCameraCommand
          ? _cameraCommandFor(
              snapshot: snapshot,
              index: index,
              originIndex: currentIndex,
              revision: nextCameraRevision,
              policy: policy,
            )
          : null,
      clearCameraCommand: !issueCameraCommand,
    );
  }

  StoryPlaybackState _copyWith({
    List<MemoryReadModel>? snapshot,
    PlaybackStatus? status,
    PlaybackPhase? phase,
    int? currentIndex,
    int? cameraRevision,
    int? presentationRevision,
    PlaybackCameraCommand? cameraCommand,
    PlaybackPolicy? policy,
    bool clearPhase = false,
    bool clearCameraCommand = false,
  }) {
    return StoryPlaybackState._(
      snapshot: snapshot ?? this.snapshot,
      status: status ?? this.status,
      phase: clearPhase ? null : phase ?? this.phase,
      currentIndex: currentIndex ?? this.currentIndex,
      cameraRevision: cameraRevision ?? this.cameraRevision,
      presentationRevision: presentationRevision ?? this.presentationRevision,
      cameraCommand: clearCameraCommand
          ? null
          : cameraCommand ?? this.cameraCommand,
      policy: policy ?? this.policy,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryPlaybackState &&
            _listEquals(snapshot, other.snapshot) &&
            status == other.status &&
            phase == other.phase &&
            currentIndex == other.currentIndex &&
            cameraRevision == other.cameraRevision &&
            presentationRevision == other.presentationRevision &&
            cameraCommand == other.cameraCommand &&
            policy == other.policy;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(snapshot),
        status,
        phase,
        currentIndex,
        cameraRevision,
        presentationRevision,
        cameraCommand,
        policy,
      );

  @override
  String toString() {
    return 'StoryPlaybackState(status: $status, phase: $phase, '
        'currentIndex: $currentIndex, count: ${snapshot.length}, '
        'cameraRevision: $cameraRevision, '
        'presentationRevision: $presentationRevision, '
        'hasCameraCommand: ${cameraCommand != null})';
  }
}

List<MemoryReadModel> _canonicalSnapshot(List<MemoryReadModel> memories) {
  final snapshot = memories.toList(growable: false)
    ..sort(_comparePlaybackReadModels);

  return List<MemoryReadModel>.unmodifiable(snapshot);
}

int _comparePlaybackReadModels(
  MemoryReadModel left,
  MemoryReadModel right,
) {
  final leftMemory = left.memory;
  final rightMemory = right.memory;
  final eventDateComparison = leftMemory.eventDate.compareTo(
    rightMemory.eventDate,
  );
  if (eventDateComparison != 0) {
    return eventDateComparison;
  }

  final createdAtComparison = leftMemory.createdAt.compareTo(
    rightMemory.createdAt,
  );
  if (createdAtComparison != 0) {
    return createdAtComparison;
  }

  return leftMemory.id.compareTo(rightMemory.id);
}

PlaybackCameraCommand _cameraCommandFor({
  required List<MemoryReadModel> snapshot,
  required int index,
  required int? originIndex,
  required int revision,
  required PlaybackPolicy policy,
}) {
  final memory = snapshot[index].memory;
  final target = MapCoordinate(
    latitude: memory.location.latitude,
    longitude: memory.location.longitude,
  );
  final origin = _cameraOriginFor(snapshot: snapshot, originIndex: originIndex);

  return PlaybackCameraCommand(
    revision: revision,
    memoryIndex: index,
    target: target,
    duration: policy.cameraDurationFor(from: origin, to: target),
  );
}

MapCoordinate? _cameraOriginFor({
  required List<MemoryReadModel> snapshot,
  required int? originIndex,
}) {
  if (originIndex == null || originIndex < 0 || originIndex >= snapshot.length) {
    return null;
  }

  final memory = snapshot[originIndex].memory;
  return MapCoordinate(
    latitude: memory.location.latitude,
    longitude: memory.location.longitude,
  );
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) {
    return true;
  }

  if (left.length != right.length) {
    return false;
  }

  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }

  return true;
}
