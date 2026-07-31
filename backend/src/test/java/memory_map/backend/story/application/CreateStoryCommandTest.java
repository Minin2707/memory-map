package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class CreateStoryCommandTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");

    private static final AuthenticatedUser AUTHENTICATED_USER =
            new AuthenticatedUser(USER_ID);

    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");

    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    @Test
    void shouldCreateCommandWhenRequiredFieldsAreValid() {

        CreateStoryCommand command = new CreateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                "Our Story",
                "The beginning of our journey",
                CURRENT_TIME
        );

        assertThat(command.authenticatedUser()).isEqualTo(AUTHENTICATED_USER);
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(command.title()).isEqualTo("Our Story");
        assertThat(command.description())
                .isEqualTo("The beginning of our journey");
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldAllowNullableDescription() {

        CreateStoryCommand command = new CreateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                "Our Story",
                null,
                CURRENT_TIME
        );

        assertThat(command.description()).isNull();
    }

    @Test
    void shouldPreserveTitleAndDescriptionWithoutNormalization() {

        CreateStoryCommand command = new CreateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                "  Our Story  ",
                "  The beginning of our journey  ",
                CURRENT_TIME
        );

        assertThat(command.title()).isEqualTo("  Our Story  ");
        assertThat(command.description())
                .isEqualTo("  The beginning of our journey  ");
    }

    @Test
    void shouldRejectNullAuthenticatedUser() {

        assertThatThrownBy(() -> new CreateStoryCommand(
                null,
                STORY_ID,
                "Our Story",
                null,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
    }

    @Test
    void shouldRejectNullStoryId() {

        assertThatThrownBy(() -> new CreateStoryCommand(
                AUTHENTICATED_USER,
                null,
                "Our Story",
                null,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");
    }

    @Test
    void shouldRejectNullTitle() {

        assertThatThrownBy(() -> new CreateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                null,
                null,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("title must not be null");
    }

    @Test
    void shouldRejectBlankTitle() {

        assertThatThrownBy(() -> new CreateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                "",
                null,
                CURRENT_TIME
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("title must not be blank");

        assertThatThrownBy(() -> new CreateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                "   ",
                null,
                CURRENT_TIME
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("title must not be blank");
    }

    @Test
    void shouldRejectNullCurrentTime() {

        assertThatThrownBy(() -> new CreateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                "Our Story",
                null,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("currentTime must not be null");
    }

    @Test
    void shouldPreserveValueSemantics() {

        CreateStoryCommand first = new CreateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                "Our Story",
                "The beginning of our journey",
                CURRENT_TIME
        );

        CreateStoryCommand second = new CreateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                "Our Story",
                "The beginning of our journey",
                CURRENT_TIME
        );

        CreateStoryCommand different = new CreateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                "Another Story",
                "The beginning of our journey",
                CURRENT_TIME
        );

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(different);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }
}
