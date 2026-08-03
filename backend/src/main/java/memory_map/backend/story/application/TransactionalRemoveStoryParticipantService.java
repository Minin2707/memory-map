package memory_map.backend.story.application;

import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Objects;
import java.util.UUID;

public class TransactionalRemoveStoryParticipantService
        implements RemoveStoryParticipantUseCase {

    private final StoryRepository storyRepository;
    private final StoryParticipantRepository storyParticipantRepository;

    public TransactionalRemoveStoryParticipantService(
            StoryRepository storyRepository,
            StoryParticipantRepository storyParticipantRepository
    ) {
        this.storyRepository = Objects.requireNonNull(
                storyRepository,
                "storyRepository must not be null"
        );
        this.storyParticipantRepository = Objects.requireNonNull(
                storyParticipantRepository,
                "storyParticipantRepository must not be null"
        );
    }

    @Override
    @Transactional
    public void removeParticipant(RemoveStoryParticipantCommand command) {
        Objects.requireNonNull(command, "command must not be null");

        UUID storyId = command.storyId();
        UUID actorUserId = command.authenticatedUser().userId();
        UUID targetUserId = command.participantUserId();

        if (!storyRepository.lockById(storyId)) {
            throw new StoryNotFoundException();
        }

        StoryParticipant actor = storyParticipantRepository
                .find(storyId, actorUserId)
                .orElseThrow(StoryNotFoundException::new);

        if (actor.role() != StoryRole.OWNER) {
            throw new StoryNotFoundException();
        }

        if (actor.userId().equals(targetUserId)) {
            throw new ParticipantCannotRemoveSelfException();
        }

        StoryParticipant target = storyParticipantRepository
                .find(storyId, targetUserId)
                .orElseThrow(StoryNotFoundException::new);

        if (target.role() == StoryRole.OWNER) {
            throw new StoryOwnerCannotBeRemovedException();
        }

        storyParticipantRepository.delete(storyId, targetUserId);
    }
}
