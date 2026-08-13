package memory_map.backend.story.application;

import memory_map.backend.story.domain.Story;
import memory_map.backend.storyparticipant.domain.StoryRole;

import java.util.Objects;

public record UserStory(

        Story story,

        StoryRole role,

        int memoryCount,

        int participantCount,

        StoryPhotoPreview previewPhoto

) {
    public UserStory {
        Objects.requireNonNull(story, "story must not be null");
        Objects.requireNonNull(role, "role must not be null");

        if (memoryCount < 0) {
            throw new IllegalArgumentException(
                    "memoryCount must not be negative"
            );
        }

        if (participantCount < 1) {
            throw new IllegalArgumentException(
                    "participantCount must be positive"
            );
        }
    }

    public UserStory(
            Story story,
            StoryRole role
    ) {
        this(story, role, 0, 1, null);
    }

    @Override
    public String toString() {
        return "UserStory[role=%s, memoryCount=%d, participantCount=%d, hasPreviewPhoto=%s]"
                .formatted(
                        role,
                        memoryCount,
                        participantCount,
                        previewPhoto != null
                );
    }
}
