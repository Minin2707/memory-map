package memory_map.backend.story.application;

import memory_map.backend.story.domain.Story;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class UserStoryTest {

    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Story STORY = new Story(
            STORY_ID,
            OWNER_ID,
            "Our Story",
            "The beginning",
            CURRENT_TIME,
            CURRENT_TIME
    );

    @Test
    void shouldCreateUserStoryWhenRequiredFieldsAreValid() {

        UserStory userStory = new UserStory(
                STORY,
                StoryRole.OWNER
        );

        assertThat(userStory.story()).isEqualTo(STORY);
        assertThat(userStory.role()).isEqualTo(StoryRole.OWNER);
    }

    @Test
    void shouldRejectNullStory() {

        assertThatThrownBy(() -> new UserStory(
                null,
                StoryRole.OWNER
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("story must not be null");
    }

    @Test
    void shouldRejectNullRole() {

        assertThatThrownBy(() -> new UserStory(
                STORY,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("role must not be null");
    }

    @Test
    void shouldPreserveValueSemantics() {

        UserStory first = new UserStory(
                STORY,
                StoryRole.OWNER
        );
        UserStory second = new UserStory(
                STORY,
                StoryRole.OWNER
        );
        UserStory different = new UserStory(
                STORY,
                StoryRole.EDITOR
        );

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(different);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }
}
