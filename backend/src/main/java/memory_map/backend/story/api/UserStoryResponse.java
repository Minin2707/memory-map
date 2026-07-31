package memory_map.backend.story.api;

import memory_map.backend.story.application.UserStory;
import memory_map.backend.story.domain.Story;
import memory_map.backend.storyparticipant.domain.StoryRole;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record UserStoryResponse(

        UUID id,

        String title,

        String description,

        StoryRole role,

        Instant createdAt,

        Instant updatedAt

) {
    public static UserStoryResponse from(UserStory userStory) {
        Objects.requireNonNull(userStory, "userStory must not be null");

        Story story = userStory.story();

        return new UserStoryResponse(
                story.id(),
                story.title(),
                story.description(),
                userStory.role(),
                story.createdAt(),
                story.updatedAt()
        );
    }
}
