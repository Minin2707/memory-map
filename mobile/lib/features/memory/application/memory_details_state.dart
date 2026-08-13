import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';

final class MemoryDetailsState {
  factory MemoryDetailsState.loaded({
    required Memory memory,
    MemoryPhotoPreview? previewPhoto,
    bool isRefreshing = false,
    MemoryFailure? refreshFailure,
  }) {
    return MemoryDetailsState._(
      readModel: MemoryReadModel(
        memory: memory,
        previewPhoto: previewPhoto,
      ),
      isRefreshing: isRefreshing,
      loadFailure: null,
      refreshFailure: refreshFailure,
    );
  }

  factory MemoryDetailsState.loadedRead({
    required MemoryReadModel readModel,
    bool isRefreshing = false,
    MemoryFailure? refreshFailure,
  }) {
    return MemoryDetailsState._(
      readModel: readModel,
      isRefreshing: isRefreshing,
      loadFailure: null,
      refreshFailure: refreshFailure,
    );
  }

  factory MemoryDetailsState.loadFailure(MemoryFailure failure) {
    return MemoryDetailsState._(
      readModel: null,
      isRefreshing: false,
      loadFailure: failure,
      refreshFailure: null,
    );
  }

  const MemoryDetailsState._({
    required this.readModel,
    required this.isRefreshing,
    required this.loadFailure,
    required this.refreshFailure,
  });

  final MemoryReadModel? readModel;
  final bool isRefreshing;
  final MemoryFailure? loadFailure;
  final MemoryFailure? refreshFailure;

  Memory? get memory => readModel?.memory;

  MemoryPhotoPreview? get previewPhoto => readModel?.previewPhoto;

  bool get hasMemory => memory != null;

  bool get isLoaded => memory != null && loadFailure == null;

  bool get hasLoadFailure => loadFailure != null;

  MemoryDetailsState copyWith({
    Memory? memory,
    MemoryReadModel? readModel,
    MemoryPhotoPreview? previewPhoto,
    bool? isRefreshing,
    MemoryFailure? loadFailure,
    MemoryFailure? refreshFailure,
    bool clearLoadFailure = false,
    bool clearRefreshFailure = false,
  }) {
    return MemoryDetailsState._(
      readModel: readModel ??
          _updatedReadModel(
            memory: memory,
            previewPhoto: previewPhoto,
          ),
      isRefreshing: isRefreshing ?? this.isRefreshing,
      loadFailure: clearLoadFailure ? null : loadFailure ?? this.loadFailure,
      refreshFailure:
          clearRefreshFailure ? null : refreshFailure ?? this.refreshFailure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MemoryDetailsState &&
            memory == other.memory &&
            previewPhoto == other.previewPhoto &&
            isRefreshing == other.isRefreshing &&
            loadFailure == other.loadFailure &&
            refreshFailure == other.refreshFailure;
  }

  @override
  int get hashCode => Object.hash(
        memory,
        previewPhoto,
        isRefreshing,
        loadFailure,
        refreshFailure,
      );

  @override
  String toString() {
    return 'MemoryDetailsState(hasMemory: $hasMemory, '
        'isRefreshing: $isRefreshing, '
        'hasLoadFailure: ${loadFailure != null}, '
        'hasRefreshFailure: ${refreshFailure != null})';
  }

  MemoryReadModel? _updatedReadModel({
    Memory? memory,
    MemoryPhotoPreview? previewPhoto,
  }) {
    final current = readModel;
    final nextMemory = memory ?? current?.memory;
    if (nextMemory == null) {
      return null;
    }

    return MemoryReadModel(
      memory: nextMemory,
      previewPhoto: previewPhoto ?? current?.previewPhoto,
    );
  }
}
