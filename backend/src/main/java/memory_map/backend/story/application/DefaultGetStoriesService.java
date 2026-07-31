package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.story.repository.UserStoryRepository;

import java.util.List;
import java.util.Objects;

public class DefaultGetStoriesService implements GetStoriesUseCase {

    private final UserStoryRepository userStoryRepository;

    public DefaultGetStoriesService(
            UserStoryRepository userStoryRepository
    ) {
        this.userStoryRepository = Objects.requireNonNull(
                userStoryRepository,
                "userStoryRepository must not be null"
        );
    }

    @Override
    public List<UserStory> getStories(
            AuthenticatedUser authenticatedUser
    ) {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );

        return userStoryRepository.findByUserId(
                authenticatedUser.userId()
        );
    }
}
