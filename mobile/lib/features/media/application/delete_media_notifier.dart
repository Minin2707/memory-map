import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/media/application/delete_media_state.dart';
import 'package:memory_map/features/media/application/media_application_exception.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/application/memory_media_notifier.dart';
import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';

final deleteMediaProvider = AsyncNotifierProvider.autoDispose
    .family<DeleteMediaNotifier, DeleteMediaState, String>(
  DeleteMediaNotifier.new,
  retry: (retryCount, error) => null,
);

final class DeleteMediaNotifier extends AsyncNotifier<DeleteMediaState> {
  DeleteMediaNotifier(this._mediaId);

  final String _mediaId;

  @override
  Future<DeleteMediaState> build() async {
    return const DeleteMediaState();
  }

  Future<bool> deleteMedia(Media media) async {
    final currentState = _currentState;
    if (_isLoading || currentState == null || currentState.isDeleting) {
      return false;
    }

    if (media.id != _mediaId || _mediaId.trim().isEmpty) {
      state = AsyncData<DeleteMediaState>(
        currentState.copyWith(
          isDeleting: false,
          deleteFailure: const MediaValidationFailure(),
        ),
      );
      return false;
    }

    final deletingState = currentState.copyWith(
      isDeleting: true,
      clearDeleteFailure: true,
    );
    state = AsyncData<DeleteMediaState>(deletingState);

    try {
      await ref.read(mediaRepositoryProvider).deleteMedia(media.id);
      if (!ref.mounted) {
        return false;
      }

      _removeFromLoadedMemoryMedia(media);
      state = const AsyncData<DeleteMediaState>(DeleteMediaState());
      return true;
    } on MediaApplicationException catch (error) {
      if (!ref.mounted) {
        return false;
      }

      state = AsyncData<DeleteMediaState>(
        deletingState.copyWith(
          isDeleting: false,
          deleteFailure: error.failure,
        ),
      );
      return false;
    } on Object catch (error, stackTrace) {
      if (!ref.mounted) {
        return false;
      }

      state = AsyncData<DeleteMediaState>(
        deletingState.copyWith(isDeleting: false),
      );
      state = AsyncError<DeleteMediaState>(error, stackTrace);
      return false;
    }
  }

  void reset() {
    state = const AsyncData<DeleteMediaState>(DeleteMediaState());
  }

  void _removeFromLoadedMemoryMedia(Media media) {
    final provider = memoryMediaProvider(media.memoryId);
    if (!ref.exists(provider)) {
      return;
    }

    ref.read(provider.notifier).removeMediaById(media.id);
  }

  bool get _isLoading => state is AsyncLoading<DeleteMediaState>;

  DeleteMediaState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<DeleteMediaState>) {
      return currentState.value;
    }

    return null;
  }
}
