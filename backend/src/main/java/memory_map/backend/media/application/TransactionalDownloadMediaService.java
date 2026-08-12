package memory_map.backend.media.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageObjectNotFoundException;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Objects;
import java.util.UUID;

public class TransactionalDownloadMediaService
        implements DownloadMediaUseCase {

    private final MediaFileRepository mediaFileRepository;
    private final MemoryRepository memoryRepository;
    private final StoryParticipantRepository storyParticipantRepository;
    private final StorageService storageService;

    public TransactionalDownloadMediaService(
            MediaFileRepository mediaFileRepository,
            MemoryRepository memoryRepository,
            StoryParticipantRepository storyParticipantRepository,
            StorageService storageService
    ) {
        this.mediaFileRepository = Objects.requireNonNull(
                mediaFileRepository,
                "mediaFileRepository must not be null"
        );
        this.memoryRepository = Objects.requireNonNull(
                memoryRepository,
                "memoryRepository must not be null"
        );
        this.storyParticipantRepository = Objects.requireNonNull(
                storyParticipantRepository,
                "storyParticipantRepository must not be null"
        );
        this.storageService = Objects.requireNonNull(
                storageService,
                "storageService must not be null"
        );
    }

    @Override
    @Transactional(readOnly = true)
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

        MediaFile mediaFile = mediaFileRepository.findById(mediaId)
                .orElseThrow(MediaUnavailableException::new);
        Memory memory = memoryRepository.findById(mediaFile.memoryId())
                .orElseThrow(MediaUnavailableException::new);
        UUID requesterUserId = authenticatedUser.userId();
        StoryParticipant participant = storyParticipantRepository.find(
                memory.storyId(),
                requesterUserId
        ).orElseThrow(MediaUnavailableException::new);

        if (!canRead(participant, memory, requesterUserId)) {
            throw new MediaUnavailableException();
        }

        try {
            StoredObject storedObject = storageService.read(storageKey(
                    mediaFile,
                    representation
            ));

            return new DownloadedMedia(
                    storedObject.content(),
                    contentLength(mediaFile, representation),
                    mediaFile.mimeType()
            );
        } catch (StorageObjectNotFoundException exception) {
            throw new MediaUnavailableException();
        }
    }

    private static boolean canRead(
            StoryParticipant participant,
            Memory memory,
            UUID requesterUserId
    ) {
        return participant.storyId().equals(memory.storyId())
                && participant.userId().equals(requesterUserId);
    }

    private static StorageKey storageKey(
            MediaFile mediaFile,
            MediaRepresentation representation
    ) {
        return switch (representation) {
            case DISPLAY -> new StorageKey(mediaFile.displayStorageKey());
            case THUMBNAIL -> new StorageKey(mediaFile.thumbnailStorageKey());
        };
    }

    private static long contentLength(
            MediaFile mediaFile,
            MediaRepresentation representation
    ) {
        return switch (representation) {
            case DISPLAY -> mediaFile.displayFileSize();
            case THUMBNAIL -> mediaFile.thumbnailFileSize();
        };
    }
}
