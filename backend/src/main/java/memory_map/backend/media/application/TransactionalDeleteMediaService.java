package memory_map.backend.media.application;

import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Objects;
import java.util.UUID;

public class TransactionalDeleteMediaService implements DeleteMediaUseCase {

    private final StoryRepository storyRepository;
    private final MediaFileRepository mediaFileRepository;
    private final MemoryRepository memoryRepository;
    private final StoryParticipantRepository storyParticipantRepository;
    private final DeleteMediaAuthorizationPolicy authorizationPolicy;
    private final StorageCleanupScheduler cleanupScheduler;

    public TransactionalDeleteMediaService(
            StoryRepository storyRepository,
            MediaFileRepository mediaFileRepository,
            MemoryRepository memoryRepository,
            StoryParticipantRepository storyParticipantRepository,
            DeleteMediaAuthorizationPolicy authorizationPolicy,
            StorageCleanupScheduler cleanupScheduler
    ) {
        this.storyRepository = Objects.requireNonNull(
                storyRepository,
                "storyRepository must not be null"
        );
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
        this.cleanupScheduler = Objects.requireNonNull(
                cleanupScheduler,
                "cleanupScheduler must not be null"
        );
    }

    @Override
    @Transactional
    public void deleteMedia(DeleteMediaCommand command) {
        Objects.requireNonNull(command, "command must not be null");

        MediaFile mediaFile = mediaFileRepository.findById(command.mediaId())
                .orElseThrow(MediaDeletionUnavailableException::new);
        Memory parentIdentity = memoryRepository.findById(
                mediaFile.memoryId()
        ).orElseThrow(MediaDeletionUnavailableException::new);

        if (!storyRepository.lockById(parentIdentity.storyId())) {
            throw new MediaDeletionUnavailableException();
        }

        Memory memory = memoryRepository.findByIdForUpdate(
                mediaFile.memoryId()
        ).orElseThrow(MediaDeletionUnavailableException::new);
        MediaFile currentMediaFile = mediaFileRepository.findById(
                command.mediaId()
        ).orElseThrow(MediaDeletionUnavailableException::new);

        if (
                !memory.storyId().equals(parentIdentity.storyId())
                        || !currentMediaFile.memoryId().equals(memory.id())
        ) {
            throw new MediaDeletionUnavailableException();
        }

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
                currentMediaFile.thumbnailStorageKey()
        );
        StorageKey displayKey = new StorageKey(
                currentMediaFile.displayStorageKey()
        );

        mediaFileRepository.delete(currentMediaFile.id());
        cleanupScheduler.schedule(List.of(thumbnailKey, displayKey));
    }
}
