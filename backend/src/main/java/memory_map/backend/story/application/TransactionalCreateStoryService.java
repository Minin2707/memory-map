package memory_map.backend.story.application;

import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public class TransactionalCreateStoryService
        implements CreateStoryUseCase {

    private final StoryRepository storyRepository;
    private final StoryParticipantRepository storyParticipantRepository;

    public TransactionalCreateStoryService(
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
    public Story create(CreateStoryCommand command) {
        Objects.requireNonNull(command, "command must not be null");

        UUID ownerId = command.authenticatedUser().userId();
        UUID storyId = command.storyId();
        Instant currentTime = command.currentTime();

        Story story = new Story(
                storyId,
                ownerId,
                command.title(),
                command.description(),
                null,
                currentTime,
                currentTime
        );
        StoryParticipant owner = new StoryParticipant(
                storyId,
                ownerId,
                StoryRole.OWNER,
                currentTime
        );

        Story savedStory = storyRepository.save(story);
        storyParticipantRepository.save(owner);

        return savedStory;
    }
}
