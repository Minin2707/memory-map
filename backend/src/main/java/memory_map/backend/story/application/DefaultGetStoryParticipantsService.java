package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.story.repository.StoryParticipantViewRepository;

import java.util.List;
import java.util.Objects;
import java.util.UUID;

public class DefaultGetStoryParticipantsService
        implements GetStoryParticipantsUseCase {

    private final StoryParticipantViewRepository repository;

    public DefaultGetStoryParticipantsService(
            StoryParticipantViewRepository repository
    ) {
        this.repository = Objects.requireNonNull(
                repository,
                "repository must not be null"
        );
    }

    @Override
    public List<StoryParticipantView> getParticipants(
            AuthenticatedUser authenticatedUser,
            UUID storyId
    ) {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(storyId, "storyId must not be null");

        List<StoryParticipantView> participants =
                repository.findByStoryIdAndRequesterUserId(
                        storyId,
                        authenticatedUser.userId()
                );

        if (participants.isEmpty()) {
            throw new StoryNotFoundException();
        }

        return participants;
    }
}
