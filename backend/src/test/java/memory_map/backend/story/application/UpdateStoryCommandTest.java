package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class UpdateStoryCommandTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final AuthenticatedUser AUTHENTICATED_USER =
            new AuthenticatedUser(USER_ID);
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    @Test
    void shouldCreateCommandWhenTitleIsProvided() {

        UpdateStoryCommand command = new UpdateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.notProvided(),
                CURRENT_TIME
        );

        assertThat(command.authenticatedUser())
                .isEqualTo(AUTHENTICATED_USER);
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(command.title().value()).isEqualTo("Updated Story");
        assertThat(command.description().isProvided()).isFalse();
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldCreateCommandWhenDescriptionIsProvided() {

        UpdateStoryCommand command = new UpdateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                UpdateStoryField.notProvided(),
                UpdateStoryField.provided("Updated description"),
                CURRENT_TIME
        );

        assertThat(command.title().isProvided()).isFalse();
        assertThat(command.description().value())
                .isEqualTo("Updated description");
    }

    @Test
    void shouldAllowProvidedNullDescription() {

        UpdateStoryCommand command = new UpdateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                UpdateStoryField.notProvided(),
                UpdateStoryField.<String>provided(null),
                CURRENT_TIME
        );

        assertThat(command.description().isProvided()).isTrue();
        assertThat(command.description().value()).isNull();
    }

    @Test
    void shouldPreserveTitleAndDescriptionWithoutNormalization() {

        UpdateStoryCommand command = new UpdateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                UpdateStoryField.provided("  Updated Story  "),
                UpdateStoryField.provided("  Updated description  "),
                CURRENT_TIME
        );

        assertThat(command.title().value())
                .isEqualTo("  Updated Story  ");
        assertThat(command.description().value())
                .isEqualTo("  Updated description  ");
    }

    @Test
    void shouldRejectNullAuthenticatedUser() {

        assertThatThrownBy(() -> new UpdateStoryCommand(
                null,
                STORY_ID,
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.notProvided(),
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
    }

    @Test
    void shouldRejectNullStoryId() {

        assertThatThrownBy(() -> new UpdateStoryCommand(
                AUTHENTICATED_USER,
                null,
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.notProvided(),
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");
    }

    @Test
    void shouldRejectNullTitleField() {

        assertThatThrownBy(() -> new UpdateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                null,
                UpdateStoryField.provided("Updated description"),
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("title must not be null");
    }

    @Test
    void shouldRejectNullDescriptionField() {

        assertThatThrownBy(() -> new UpdateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                UpdateStoryField.provided("Updated Story"),
                null,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("description must not be null");
    }

    @Test
    void shouldRejectNullCurrentTime() {

        assertThatThrownBy(() -> new UpdateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.notProvided(),
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("currentTime must not be null");
    }

    @Test
    void shouldRejectNoProvidedFields() {

        assertThatThrownBy(() -> new UpdateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                UpdateStoryField.notProvided(),
                UpdateStoryField.notProvided(),
                CURRENT_TIME
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("at least one update field must be provided");
    }

    @Test
    void shouldRejectProvidedNullTitle() {

        assertThatThrownBy(() -> new UpdateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                UpdateStoryField.<String>provided(null),
                UpdateStoryField.notProvided(),
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("title value must not be null");
    }

    @Test
    void shouldRejectProvidedBlankTitle() {

        assertThatThrownBy(() -> new UpdateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                UpdateStoryField.provided(""),
                UpdateStoryField.notProvided(),
                CURRENT_TIME
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("title value must not be blank");

        assertThatThrownBy(() -> new UpdateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                UpdateStoryField.provided("   "),
                UpdateStoryField.notProvided(),
                CURRENT_TIME
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("title value must not be blank");
    }

    @Test
    void shouldPreserveValueSemantics() {

        UpdateStoryCommand first = new UpdateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.provided("Updated description"),
                CURRENT_TIME
        );
        UpdateStoryCommand second = new UpdateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                UpdateStoryField.provided("Updated Story"),
                UpdateStoryField.provided("Updated description"),
                CURRENT_TIME
        );
        UpdateStoryCommand different = new UpdateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                UpdateStoryField.provided("Another Story"),
                UpdateStoryField.provided("Updated description"),
                CURRENT_TIME
        );

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(different);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    @Test
    void shouldUseSafeToString() {

        UpdateStoryCommand command = new UpdateStoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                UpdateStoryField.provided("Secret title"),
                UpdateStoryField.provided("Secret description"),
                CURRENT_TIME
        );

        assertThat(command.toString())
                .contains("authenticatedUser=<redacted>")
                .contains("storyId=<redacted>")
                .contains("title=provided")
                .contains("description=provided")
                .contains(CURRENT_TIME.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain("Secret title")
                .doesNotContain("Secret description");
    }
}
