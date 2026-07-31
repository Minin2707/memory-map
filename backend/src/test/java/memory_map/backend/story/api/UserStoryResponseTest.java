package memory_map.backend.story.api;

import memory_map.backend.story.application.UserStory;
import memory_map.backend.story.domain.Story;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class UserStoryResponseTest {

    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant UPDATED_AT =
            Instant.parse("2026-01-02T10:00:00Z");

    @Test
    void shouldMapAllPublicFields() {

        UserStoryResponse response = UserStoryResponse.from(
                userStory("Our Story", "The beginning", StoryRole.OWNER)
        );

        assertThat(response.id()).isEqualTo(STORY_ID);
        assertThat(response.title()).isEqualTo("Our Story");
        assertThat(response.description()).isEqualTo("The beginning");
        assertThat(response.role()).isEqualTo(StoryRole.OWNER);
        assertThat(response.createdAt()).isEqualTo(CREATED_AT);
        assertThat(response.updatedAt()).isEqualTo(UPDATED_AT);
    }

    @Test
    void shouldMapEditorRole() {

        UserStoryResponse response = UserStoryResponse.from(
                userStory("Our Story", "The beginning", StoryRole.EDITOR)
        );

        assertThat(response.role()).isEqualTo(StoryRole.EDITOR);
    }

    @Test
    void shouldPreserveNullableDescription() {

        UserStoryResponse response = UserStoryResponse.from(
                userStory("Our Story", null, StoryRole.OWNER)
        );

        assertThat(response.description()).isNull();
    }

    @Test
    void shouldRejectNullUserStory() {

        assertThatThrownBy(() -> UserStoryResponse.from(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("userStory must not be null");
    }

    @Test
    void shouldPreserveValueSemantics() {

        UserStoryResponse first = UserStoryResponse.from(
                userStory("Our Story", "The beginning", StoryRole.OWNER)
        );
        UserStoryResponse second = UserStoryResponse.from(
                userStory("Our Story", "The beginning", StoryRole.OWNER)
        );
        UserStoryResponse different = UserStoryResponse.from(
                userStory("Another Story", "The beginning", StoryRole.OWNER)
        );

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(different);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    private static UserStory userStory(
            String title,
            String description,
            StoryRole role
    ) {
        return new UserStory(
                new Story(
                        STORY_ID,
                        OWNER_ID,
                        title,
                        description,
                        CREATED_AT,
                        UPDATED_AT
                ),
                role
        );
    }
}
