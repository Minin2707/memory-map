package memory_map.backend.media.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.repository.AuthorizedMediaDownloadRepository;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectNotFoundException;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;

import java.util.Objects;
import java.util.UUID;

public class TransactionalDownloadMediaService
        implements DownloadMediaUseCase {

    private final AuthorizedMediaDownloadRepository
            authorizedMediaDownloadRepository;
    private final StorageService storageService;

    public TransactionalDownloadMediaService(
            AuthorizedMediaDownloadRepository
                    authorizedMediaDownloadRepository,
            StorageService storageService
    ) {
        this.authorizedMediaDownloadRepository = Objects.requireNonNull(
                authorizedMediaDownloadRepository,
                "authorizedMediaDownloadRepository must not be null"
        );
        this.storageService = Objects.requireNonNull(
                storageService,
                "storageService must not be null"
        );
    }

    @Override
    public DownloadedMedia downloadMedia(
            AuthenticatedUser authenticatedUser,
            UUID mediaId,
            MediaRepresentation representation
    ) {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(mediaId, "mediaId must not be null");
        Objects.requireNonNull(
                representation,
                "representation must not be null"
        );

        MediaDownloadReadModel media = authorizedMediaDownloadRepository
                .findAuthorizedDownload(mediaId, authenticatedUser.userId())
                .orElseThrow(MediaUnavailableException::new);

        try {
            StoredObject storedObject = storageService.read(new StorageKey(
                    media.storageKey(representation)
            ));

            return new DownloadedMedia(
                    storedObject.content(),
                    media.contentLength(representation),
                    media.mimeType()
            );
        } catch (StorageObjectNotFoundException exception) {
            throw new MediaUnavailableException();
        }
    }
}
