package memory_map.backend.music.application;

import memory_map.backend.story.application.StoryAccessPolicy;
import memory_map.backend.story.application.StoryNotFoundException;
import memory_map.backend.story.application.UserStory;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.story.repository.UserStoryRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Objects;

public class TransactionalRemoveStorySoundtrackService
        implements RemoveStorySoundtrackUseCase {

    private final UserStoryRepository userStoryRepository;
    private final StoryRepository storyRepository;
    private final StoryAccessPolicy storyAccessPolicy;

    public TransactionalRemoveStorySoundtrackService(
            UserStoryRepository userStoryRepository,
            StoryRepository storyRepository,
            StoryAccessPolicy storyAccessPolicy
    ) {
        this.userStoryRepository = Objects.requireNonNull(
                userStoryRepository,
                "userStoryRepository must not be null"
        );
        this.storyRepository = Objects.requireNonNull(
                storyRepository,
                "storyRepository must not be null"
        );
        this.storyAccessPolicy = Objects.requireNonNull(
                storyAccessPolicy,
                "storyAccessPolicy must not be null"
        );
    }

    @Override
    @Transactional
    public StorySoundtrack removeStorySoundtrack(
            RemoveStorySoundtrackCommand command
    ) {
        Objects.requireNonNull(command, "command must not be null");

        UserStory current = userStoryRepository.findByStoryIdAndUserId(
                command.storyId(),
                command.authenticatedUser().userId()
        ).orElseThrow(StoryNotFoundException::new);

        if (!storyAccessPolicy.canChangeStorySoundtrack(current.role())) {
            throw new StoryNotFoundException();
        }

        Story existing = current.story();

        if (existing.soundtrackId() == null) {
            return StorySoundtrack.noMusic();
        }

        Story updated = new Story(
                existing.id(),
                existing.ownerId(),
                existing.title(),
                existing.description(),
                null,
                existing.createdAt(),
                command.currentTime()
        );
        storyRepository.update(updated);

        return StorySoundtrack.noMusic();
    }
}
