import 'package:memory_map/features/media/domain/selected_photo.dart';

abstract interface class PhotoSelectionGateway {
  Future<SelectedPhoto?> selectPhoto();
}
