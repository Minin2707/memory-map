import 'package:image_picker/image_picker.dart';
import 'package:memory_map/features/media/domain/photo_selection_gateway.dart';
import 'package:memory_map/features/media/domain/selected_photo.dart';

final class ImagePickerPhotoSelectionGateway
    implements PhotoSelectionGateway {
  ImagePickerPhotoSelectionGateway({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<SelectedPhoto?> selectPhoto() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
      requestFullMetadata: true,
    );

    if (file == null) {
      return null;
    }

    return SelectedPhoto(
      readBytes: file.readAsBytes,
      declaredContentType: file.mimeType,
    );
  }
}
