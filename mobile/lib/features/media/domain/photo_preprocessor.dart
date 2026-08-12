import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/media/domain/selected_photo.dart';

abstract interface class PhotoPreprocessor {
  Future<PreparedPhotoUpload> process(SelectedPhoto photo);
}
