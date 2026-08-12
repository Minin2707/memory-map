package memory_map.backend.media.application;

import memory_map.backend.media.domain.MediaFile;

public interface UploadPhotoUseCase {

    MediaFile uploadPhoto(UploadPhotoCommand command);
}
