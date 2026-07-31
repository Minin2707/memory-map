package memory_map.backend.story.application;

import memory_map.backend.story.domain.Story;
import memory_map.backend.storyparticipant.domain.StoryRole;

import java.util.Objects;

public record UserStory(

        Story story,

        StoryRole role

) {
    public UserStory {
        Objects.requireNonNull(story, "story must not be null");
        Objects.requireNonNull(role, "role must not be null");
    }
}
