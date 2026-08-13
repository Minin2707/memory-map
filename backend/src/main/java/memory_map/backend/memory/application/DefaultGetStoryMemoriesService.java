package memory_map.backend.memory.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.memory.repository.MemoryReadRepository;
import memory_map.backend.story.application.StoryNotFoundException;

import java.util.List;
import java.util.Objects;
import java.util.UUID;

public class DefaultGetStoryMemoriesService
        implements GetStoryMemoriesUseCase {

    private final MemoryReadRepository repository;

    public DefaultGetStoryMemoriesService(
            MemoryReadRepository repository
    ) {
        this.repository = Objects.requireNonNull(
                repository,
                "repository must not be null"
        );
    }

    @Override
    public List<MemoryReadModel> getMemories(
            AuthenticatedUser authenticatedUser,
            UUID storyId
    ) {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(storyId, "storyId must not be null");

        return repository.findByStoryIdAndRequesterUserId(
                storyId,
                authenticatedUser.userId()
        ).orElseThrow(StoryNotFoundException::new).memories();
    }
}
