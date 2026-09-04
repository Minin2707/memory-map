package memory_map.backend.memory.application;

import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Objects;
import java.util.UUID;

public class TransactionalDeleteMemoryService implements DeleteMemoryUseCase {

    private final MemoryRepository memoryRepository;
    private final StoryParticipantRepository storyParticipantRepository;
    private final MemoryMediaCleanupCoordinator mediaCleanupCoordinator;

    public TransactionalDeleteMemoryService(
            MemoryRepository memoryRepository,
            StoryParticipantRepository storyParticipantRepository,
            MemoryMediaCleanupCoordinator mediaCleanupCoordinator
    ) {
        this.memoryRepository = Objects.requireNonNull(
                memoryRepository,
                "memoryRepository must not be null"
        );
        this.storyParticipantRepository = Objects.requireNonNull(
                storyParticipantRepository,
                "storyParticipantRepository must not be null"
        );
        this.mediaCleanupCoordinator = Objects.requireNonNull(
                mediaCleanupCoordinator,
                "mediaCleanupCoordinator must not be null"
        );
    }

    @Override
    @Transactional
    public void deleteMemory(DeleteMemoryCommand command) {
        Objects.requireNonNull(command, "command must not be null");

        Memory memory = memoryRepository.findByIdForUpdate(
                command.memoryId()
        ).orElseThrow(MemoryDeletionUnavailableException::new);

        UUID requesterUserId = command.authenticatedUser().userId();
        StoryParticipant participant = storyParticipantRepository.find(
                memory.storyId(),
                requesterUserId
        ).orElseThrow(MemoryDeletionUnavailableException::new);

        if (!canDelete(participant.role(), memory, requesterUserId)) {
            throw new MemoryDeletionUnavailableException();
        }

        mediaCleanupCoordinator.prepareAfterCommitCleanup(memory.id());

        if (!memoryRepository.delete(memory.id())) {
            throw new IllegalStateException(
                    "Memory delete affected no rows after locked lookup"
            );
        }
    }

    private static boolean canDelete(
            StoryRole role,
            Memory memory,
            UUID requesterUserId
    ) {
        return role == StoryRole.OWNER
                || role == StoryRole.CO_OWNER
                || (role == StoryRole.EDITOR
                        && memory.createdBy().equals(requesterUserId));
    }
}
