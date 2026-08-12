import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/media/application/media_application_exception.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/application/memory_media_notifier.dart';
import 'package:memory_map/features/media/application/upload_photo_state.dart';
import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';

final uploadPhotoProvider =
    AsyncNotifierProvider.autoDispose.family<UploadPhotoNotifier,
        UploadPhotoState, String>(
  UploadPhotoNotifier.new,
  retry: (retryCount, error) => null,
);

final class UploadPhotoNotifier extends AsyncNotifier<UploadPhotoState> {
  UploadPhotoNotifier(this._memoryId);

  final String _memoryId;

  @override
  Future<UploadPhotoState> build() async {
    return const UploadPhotoState();
  }

  Future<Media?> selectPrepareAndUpload() async {
    final currentState = _currentState;
    if (_isLoading || currentState == null || currentState.isBusy) {
      return null;
    }

    if (_memoryId.trim().isEmpty) {
      state = AsyncData<UploadPhotoState>(
        currentState.copyWith(
          phase: UploadPhotoPhase.idle,
          failure: const MediaValidationFailure(),
        ),
      );
      return null;
    }

    state = AsyncData<UploadPhotoState>(
      currentState.copyWith(
        phase: UploadPhotoPhase.selecting,
        clearFailure: true,
      ),
    );

    try {
      final selected =
          await ref.read(photoSelectionGatewayProvider).selectPhoto();
      if (!ref.mounted) {
        return null;
      }

      if (selected == null) {
        state = const AsyncData<UploadPhotoState>(UploadPhotoState());
        return null;
      }

      state = const AsyncData<UploadPhotoState>(
        UploadPhotoState(phase: UploadPhotoPhase.preparing),
      );
      final prepared = await ref.read(photoPreprocessorProvider).process(
            selected,
          );
      if (!ref.mounted) {
        return null;
      }

      state = const AsyncData<UploadPhotoState>(
        UploadPhotoState(phase: UploadPhotoPhase.uploading),
      );
      final media = await ref.read(mediaRepositoryProvider).uploadPhoto(
            _memoryId,
            prepared,
          );
      if (!ref.mounted) {
        return null;
      }

      _upsertIntoLoadedMemoryMedia(media);

      state = const AsyncData<UploadPhotoState>(UploadPhotoState());
      return media;
    } on MediaApplicationException catch (error) {
      if (!ref.mounted) {
        return null;
      }

      state = AsyncData<UploadPhotoState>(
        const UploadPhotoState().copyWith(failure: error.failure),
      );
      return null;
    } on Object catch (error, stackTrace) {
      if (!ref.mounted) {
        return null;
      }

      state = const AsyncData<UploadPhotoState>(UploadPhotoState());
      state = AsyncError<UploadPhotoState>(error, stackTrace);
      return null;
    }
  }

  void reset() {
    state = const AsyncData<UploadPhotoState>(UploadPhotoState());
  }

  void _upsertIntoLoadedMemoryMedia(Media media) {
    final provider = memoryMediaProvider(_memoryId);
    if (!ref.exists(provider)) {
      return;
    }

    ref.read(provider.notifier).upsertMedia(media);
  }

  bool get _isLoading => state is AsyncLoading<UploadPhotoState>;

  UploadPhotoState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<UploadPhotoState>) {
      return currentState.value;
    }

    return null;
  }
}
