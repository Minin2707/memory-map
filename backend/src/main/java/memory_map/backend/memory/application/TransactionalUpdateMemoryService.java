package memory_map.backend.memory.application;

import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.Objects;
import java.util.UUID;

public class TransactionalUpdateMemoryService implements UpdateMemoryUseCase {

    private final MemoryRepository memoryRepository;
    private final StoryParticipantRepository storyParticipantRepository;

    public TransactionalUpdateMemoryService(
            MemoryRepository memoryRepository,
            StoryParticipantRepository storyParticipantRepository
    ) {
        this.memoryRepository = Objects.requireNonNull(
                memoryRepository,
                "memoryRepository must not be null"
        );
        this.storyParticipantRepository = Objects.requireNonNull(
                storyParticipantRepository,
                "storyParticipantRepository must not be null"
        );
    }

    @Override
    @Transactional
    public Memory updateMemory(UpdateMemoryCommand command) {
        Objects.requireNonNull(command, "command must not be null");

        Memory existing = memoryRepository.findByIdForUpdate(
                command.memoryId()
        ).orElseThrow(MemoryUpdateUnavailableException::new);

        UUID requesterUserId = command.authenticatedUser().userId();
        StoryParticipant participant = storyParticipantRepository.find(
                existing.storyId(),
                requesterUserId
        ).orElseThrow(MemoryUpdateUnavailableException::new);

        if (!canUpdate(participant.role(), existing, requesterUserId)) {
            throw new MemoryUpdateUnavailableException();
        }

        Memory candidate = candidateMemory(command, existing);

        if (!hasEffectiveChange(existing, candidate)) {
            return existing;
        }

        if (!memoryRepository.update(candidate)) {
            throw new IllegalStateException(
                    "Memory update affected no rows after locked lookup"
            );
        }

        return candidate;
    }

    private static boolean canUpdate(
            StoryRole role,
            Memory memory,
            UUID requesterUserId
    ) {
        return role == StoryRole.OWNER
                || role == StoryRole.CO_OWNER
                || (role == StoryRole.EDITOR
                        && memory.createdBy().equals(requesterUserId));
    }

    private static Memory candidateMemory(
            UpdateMemoryCommand command,
            Memory existing
    ) {
        return new Memory(
                existing.id(),
                existing.storyId(),
                existing.createdBy(),
                updatedString(command.title(), existing.title()),
                updatedString(command.description(), existing.description()),
                updatedString(command.placeName(), existing.placeName()),
                updatedDouble(command.latitude(), existing.latitude()),
                updatedDouble(command.longitude(), existing.longitude()),
                updatedEventDate(command.eventDate(), existing.eventDate()),
                existing.createdAt(),
                command.currentTime()
        );
    }

    private static String updatedString(
            PatchField<String> field,
            String existing
    ) {
        if (field.isProvided()) {
            return field.value();
        }

        return existing;
    }

    private static double updatedDouble(
            PatchField<Double> field,
            double existing
    ) {
        if (field.isProvided()) {
            return field.value();
        }

        return existing;
    }

    private static LocalDate updatedEventDate(
            PatchField<LocalDate> field,
            LocalDate existing
    ) {
        if (field.isProvided()) {
            return field.value();
        }

        return existing;
    }

    private static boolean hasEffectiveChange(
            Memory existing,
            Memory candidate
    ) {
        return !Objects.equals(existing.title(), candidate.title())
                || !Objects.equals(
                        existing.description(),
                        candidate.description()
                )
                || !Objects.equals(
                        existing.placeName(),
                        candidate.placeName()
                )
                || Double.compare(
                        existing.latitude(),
                        candidate.latitude()
                ) != 0
                || Double.compare(
                        existing.longitude(),
                        candidate.longitude()
                ) != 0
                || !Objects.equals(
                        existing.eventDate(),
                        candidate.eventDate()
                );
    }
}
