package memory_map.backend.media.application;

import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.transaction.annotation.Transactional;

import java.util.Objects;
import java.util.UUID;

public class TransactionalDeleteMediaService implements DeleteMediaUseCase {

    private static final Logger LOGGER = LoggerFactory.getLogger(
            TransactionalDeleteMediaService.class
    );

    private final MediaFileRepository mediaFileRepository;
    private final MemoryRepository memoryRepository;
    private final StoryParticipantRepository storyParticipantRepository;
    private final DeleteMediaAuthorizationPolicy authorizationPolicy;
    private final StorageService storageService;
    private final TransactionCommitCoordinator commitCoordinator;

    public TransactionalDeleteMediaService(
            MediaFileRepository mediaFileRepository,
            MemoryRepository memoryRepository,
            StoryParticipantRepository storyParticipantRepository,
            DeleteMediaAuthorizationPolicy authorizationPolicy,
            StorageService storageService,
            TransactionCommitCoordinator commitCoordinator
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
        this.authorizationPolicy = Objects.requireNonNull(
                authorizationPolicy,
                "authorizationPolicy must not be null"
        );
        this.storageService = Objects.requireNonNull(
                storageService,
                "storageService must not be null"
        );
        this.commitCoordinator = Objects.requireNonNull(
                commitCoordinator,
                "commitCoordinator must not be null"
        );
    }

    @Override
    @Transactional
    public void deleteMedia(DeleteMediaCommand command) {
        Objects.requireNonNull(command, "command must not be null");

        MediaFile mediaFile = mediaFileRepository.findById(command.mediaId())
                .orElseThrow(MediaDeletionUnavailableException::new);
        Memory memory = memoryRepository.findByIdForUpdate(
                mediaFile.memoryId()
        ).orElseThrow(MediaDeletionUnavailableException::new);

        UUID requesterUserId = command.authenticatedUser().userId();
        StoryParticipant participant = storyParticipantRepository.find(
                memory.storyId(),
                requesterUserId
        ).orElseThrow(MediaDeletionUnavailableException::new);

        if (!authorizationPolicy.canDeleteMedia(
                participant,
                memory,
                requesterUserId
        )) {
            throw new MediaDeletionUnavailableException();
        }

        StorageKey thumbnailKey = new StorageKey(
                mediaFile.thumbnailStorageKey()
        );
        StorageKey displayKey = new StorageKey(mediaFile.displayStorageKey());

        mediaFileRepository.delete(mediaFile.id());
        commitCoordinator.onCommit(() -> cleanupStorage(
                thumbnailKey,
                displayKey
        ));
    }

    private void cleanupStorage(
            StorageKey thumbnailKey,
            StorageKey displayKey
    ) {
        cleanupQuietly(thumbnailKey);
        cleanupQuietly(displayKey);
    }

    private void cleanupQuietly(StorageKey key) {
        try {
            storageService.delete(key);
        } catch (RuntimeException exception) {
            LOGGER.warn(
                    "Media storage cleanup failed after metadata deletion: {}",
                    exception.getClass().getName()
            );
        }
    }
}
