package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.story.repository.UserStoryRepository;

import java.util.Objects;
import java.util.UUID;

public class DefaultGetStoryService implements GetStoryUseCase {

    private final UserStoryRepository userStoryRepository;

    public DefaultGetStoryService(
            UserStoryRepository userStoryRepository
    ) {
        this.userStoryRepository = Objects.requireNonNull(
                userStoryRepository,
                "userStoryRepository must not be null"
        );
    }

    @Override
    public UserStory getStory(
            AuthenticatedUser authenticatedUser,
            UUID storyId
    ) {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(storyId, "storyId must not be null");

        return userStoryRepository.findByStoryIdAndUserId(
                storyId,
                authenticatedUser.userId()
        ).orElseThrow(StoryNotFoundException::new);
    }
}
