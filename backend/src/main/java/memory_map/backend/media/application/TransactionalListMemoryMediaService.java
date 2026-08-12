package memory_map.backend.media.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.repository.MediaFileRepository;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Objects;
import java.util.UUID;

public class TransactionalListMemoryMediaService
        implements ListMemoryMediaUseCase {

    private final MemoryRepository memoryRepository;
    private final StoryParticipantRepository storyParticipantRepository;
    private final MediaFileRepository mediaFileRepository;

    public TransactionalListMemoryMediaService(
            MemoryRepository memoryRepository,
            StoryParticipantRepository storyParticipantRepository,
            MediaFileRepository mediaFileRepository
    ) {
        this.memoryRepository = Objects.requireNonNull(
                memoryRepository,
                "memoryRepository must not be null"
        );
        this.storyParticipantRepository = Objects.requireNonNull(
                storyParticipantRepository,
                "storyParticipantRepository must not be null"
        );
        this.mediaFileRepository = Objects.requireNonNull(
                mediaFileRepository,
                "mediaFileRepository must not be null"
        );
    }

    @Override
    @Transactional(readOnly = true)
    public List<MediaFile> listMedia(
            AuthenticatedUser authenticatedUser,
            UUID memoryId
    ) {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(memoryId, "memoryId must not be null");

        Memory memory = memoryRepository.findById(memoryId)
                .orElseThrow(MediaUnavailableException::new);
        UUID requesterUserId = authenticatedUser.userId();
        StoryParticipant participant = storyParticipantRepository.find(
                memory.storyId(),
                requesterUserId
        ).orElseThrow(MediaUnavailableException::new);

        if (!canRead(participant, memory, requesterUserId)) {
            throw new MediaUnavailableException();
        }

        return mediaFileRepository.findByMemoryId(memory.id());
    }

    private static boolean canRead(
            StoryParticipant participant,
            Memory memory,
            UUID requesterUserId
    ) {
        return participant.storyId().equals(memory.storyId())
                && participant.userId().equals(requesterUserId);
    }
}
