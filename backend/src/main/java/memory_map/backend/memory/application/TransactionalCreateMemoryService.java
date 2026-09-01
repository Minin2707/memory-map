package memory_map.backend.memory.application;

import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.notification.application.NotificationPublisher;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public class TransactionalCreateMemoryService implements CreateMemoryUseCase {

    private final StoryParticipantRepository storyParticipantRepository;
    private final MemoryRepository memoryRepository;
    private final NotificationPublisher notificationPublisher;

    public TransactionalCreateMemoryService(
            StoryParticipantRepository storyParticipantRepository,
            MemoryRepository memoryRepository,
            NotificationPublisher notificationPublisher
    ) {
        this.storyParticipantRepository = Objects.requireNonNull(
                storyParticipantRepository,
                "storyParticipantRepository must not be null"
        );
        this.memoryRepository = Objects.requireNonNull(
                memoryRepository,
                "memoryRepository must not be null"
        );
        this.notificationPublisher = Objects.requireNonNull(
                notificationPublisher,
                "notificationPublisher must not be null"
        );
    }

    @Override
    @Transactional
    public Memory createMemory(CreateMemoryCommand command) {
        Objects.requireNonNull(command, "command must not be null");

        UUID userId = command.authenticatedUser().userId();
        StoryParticipant participant = storyParticipantRepository.find(
                command.storyId(),
                userId
        ).orElseThrow(MemoryCreationUnavailableException::new);

        if (!canCreateMemory(participant.role())) {
            throw new MemoryCreationUnavailableException();
        }

        Memory memory = memory(command, userId);
        memoryRepository.save(memory);
        notificationPublisher.memoryCreated(memory, command.currentTime());

        return memory;
    }

    private static boolean canCreateMemory(StoryRole role) {
        return role == StoryRole.OWNER
                || role == StoryRole.CO_OWNER
                || role == StoryRole.EDITOR;
    }

    private static Memory memory(
            CreateMemoryCommand command,
            UUID createdBy
    ) {
        Instant currentTime = command.currentTime();

        return new Memory(
                command.memoryId(),
                command.storyId(),
                createdBy,
                command.title(),
                command.description(),
                command.placeName(),
                command.latitude(),
                command.longitude(),
                command.eventDate(),
                currentTime,
                currentTime
        );
    }
}
