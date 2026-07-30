package memory_map.backend.story.domain;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StoryTest {

    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");

    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");

    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00.123456Z");

    private static final Instant UPDATED_AT =
            Instant.parse("2026-01-01T10:00:01.123456Z");

    @Test
    void shouldCreateStoryWhenRequiredFieldsAreValid() {

        Story story = new Story(
                STORY_ID,
                OWNER_ID,
                "Our Story",
                "The beginning of our journey",
                CREATED_AT,
                UPDATED_AT
        );

        assertThat(story.id()).isEqualTo(STORY_ID);
        assertThat(story.ownerId()).isEqualTo(OWNER_ID);
        assertThat(story.title()).isEqualTo("Our Story");
        assertThat(story.description()).isEqualTo("The beginning of our journey");
        assertThat(story.createdAt()).isEqualTo(CREATED_AT);
        assertThat(story.updatedAt()).isEqualTo(UPDATED_AT);
    }

    @Test
    void shouldAllowNullableDescription() {

        Story story = new Story(
                STORY_ID,
                OWNER_ID,
                "Our Story",
                null,
                CREATED_AT,
                UPDATED_AT
        );

        assertThat(story.description()).isNull();
    }

    @Test
    void shouldRejectNullId() {

        assertThatThrownBy(() -> new Story(
                null,
                OWNER_ID,
                "Our Story",
                null,
                CREATED_AT,
                UPDATED_AT
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("id must not be null");
    }

    @Test
    void shouldRejectNullOwnerId() {

        assertThatThrownBy(() -> new Story(
                STORY_ID,
                null,
                "Our Story",
                null,
                CREATED_AT,
                UPDATED_AT
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("ownerId must not be null");
    }

    @Test
    void shouldRejectNullTitle() {

        assertThatThrownBy(() -> new Story(
                STORY_ID,
                OWNER_ID,
                null,
                null,
                CREATED_AT,
                UPDATED_AT
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("title must not be null");
    }

    @Test
    void shouldRejectBlankTitle() {

        assertThatThrownBy(() -> new Story(
                STORY_ID,
                OWNER_ID,
                "",
                null,
                CREATED_AT,
                UPDATED_AT
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("title must not be blank");

        assertThatThrownBy(() -> new Story(
                STORY_ID,
                OWNER_ID,
                "   ",
                null,
                CREATED_AT,
                UPDATED_AT
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("title must not be blank");
    }

    @Test
    void shouldRejectNullCreatedAt() {

        assertThatThrownBy(() -> new Story(
                STORY_ID,
                OWNER_ID,
                "Our Story",
                null,
                null,
                UPDATED_AT
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("createdAt must not be null");
    }

    @Test
    void shouldRejectNullUpdatedAt() {

        assertThatThrownBy(() -> new Story(
                STORY_ID,
                OWNER_ID,
                "Our Story",
                null,
                CREATED_AT,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("updatedAt must not be null");
    }

}
