import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/media/application/default_media_repository.dart';
import 'package:memory_map/features/media/data/picker/image_picker_photo_selection_gateway.dart';
import 'package:memory_map/features/media/data/preprocessing/image_photo_preprocessor.dart';
import 'package:memory_map/features/media/data/remote/dio_media_remote_data_source.dart';
import 'package:memory_map/features/media/domain/media_repository.dart';
import 'package:memory_map/features/media/domain/photo_preprocessor.dart';
import 'package:memory_map/features/media/domain/photo_selection_gateway.dart';

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return DefaultMediaRepository(
    mediaRemoteDataSource: ref.watch(mediaRemoteDataSourceProvider),
  );
});

final photoSelectionGatewayProvider = Provider<PhotoSelectionGateway>((ref) {
  return ImagePickerPhotoSelectionGateway();
});

final photoPreprocessorProvider = Provider<PhotoPreprocessor>((ref) {
  return const ImagePhotoPreprocessor();
});
