package memory_map.backend.media.repository;

import memory_map.backend.media.application.MediaDownloadReadModel;

import java.util.Optional;
import java.util.UUID;

public interface AuthorizedMediaDownloadRepository {

    Optional<MediaDownloadReadModel> findAuthorizedDownload(
            UUID mediaId,
            UUID requesterUserId
    );

}
