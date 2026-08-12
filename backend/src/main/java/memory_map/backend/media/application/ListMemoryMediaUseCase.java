package memory_map.backend.media.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.domain.MediaFile;

import java.util.List;
import java.util.UUID;

public interface ListMemoryMediaUseCase {

    List<MediaFile> listMedia(
            AuthenticatedUser authenticatedUser,
            UUID memoryId
    );
}
