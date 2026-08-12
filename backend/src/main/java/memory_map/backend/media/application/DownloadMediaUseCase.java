package memory_map.backend.media.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.util.UUID;

public interface DownloadMediaUseCase {

    DownloadedMedia downloadMedia(
            AuthenticatedUser authenticatedUser,
            UUID mediaId,
            MediaRepresentation representation
    );
}
