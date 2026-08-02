package memory_map.backend.story.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.story.application.UpdateStoryCommand;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class UpdateStoryRequestTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final AuthenticatedUser AUTHENTICATED_USER =
            new AuthenticatedUser(USER_ID);

    @Test
    void shouldMapTitleOnlyToCommand() {

        UpdateStoryCommand command = request(
                PatchField.present("Updated Story"),
                PatchField.omitted()
        ).toCommand(AUTHENTICATED_USER, STORY_ID, CURRENT_TIME);

        assertThat(command.authenticatedUser())
                .isEqualTo(AUTHENTICATED_USER);
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(command.title().isProvided()).isTrue();
        assertThat(command.title().value()).isEqualTo("Updated Story");
        assertThat(command.description().isProvided()).isFalse();
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldMapDescriptionOnlyToCommand() {

        UpdateStoryCommand command = request(
                PatchField.omitted(),
                PatchField.present("Updated description")
        ).toCommand(AUTHENTICATED_USER, STORY_ID, CURRENT_TIME);

        assertThat(command.title().isProvided()).isFalse();
        assertThat(command.description().isProvided()).isTrue();
        assertThat(command.description().value())
                .isEqualTo("Updated description");
    }

    @Test
    void shouldMapClearDescriptionToCommand() {

        UpdateStoryCommand command = request(
                PatchField.omitted(),
                PatchField.<String>present(null)
        ).toCommand(AUTHENTICATED_USER, STORY_ID, CURRENT_TIME);

        assertThat(command.description().isProvided()).isTrue();
        assertThat(command.description().value()).isNull();
    }

    @Test
    void shouldMapBothFieldsToCommand() {

        UpdateStoryCommand command = request(
                PatchField.present("Updated Story"),
                PatchField.present("Updated description")
        ).toCommand(AUTHENTICATED_USER, STORY_ID, CURRENT_TIME);

        assertThat(command.title().value()).isEqualTo("Updated Story");
        assertThat(command.description().value())
                .isEqualTo("Updated description");
    }

    @Test
    void shouldMapTitleAndClearDescriptionToCommand() {

        UpdateStoryCommand command = request(
                PatchField.present("Updated Story"),
                PatchField.<String>present(null)
        ).toCommand(AUTHENTICATED_USER, STORY_ID, CURRENT_TIME);

        assertThat(command.title().value()).isEqualTo("Updated Story");
        assertThat(command.description().isProvided()).isTrue();
        assertThat(command.description().value()).isNull();
    }

    @Test
    void shouldRejectEmptyPatch() {

        assertThatThrownBy(() -> request(
                PatchField.omitted(),
                PatchField.omitted()
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("at least one update field must be provided");
    }

    @Test
    void shouldRejectNullTitle() {

        assertThatThrownBy(() -> request(
                PatchField.<String>present(null),
                PatchField.omitted()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("title value must not be null");
    }

    @Test
    void shouldRejectEmptyTitle() {

        assertThatThrownBy(() -> request(
                PatchField.present(""),
                PatchField.omitted()
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("title value must not be blank");
    }

    @Test
    void shouldRejectBlankTitle() {

        assertThatThrownBy(() -> request(
                PatchField.present("   "),
                PatchField.omitted()
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("title value must not be blank");
    }

    @Test
    void shouldPreserveBlankDescription() {

        UpdateStoryCommand command = request(
                PatchField.omitted(),
                PatchField.present("   ")
        ).toCommand(AUTHENTICATED_USER, STORY_ID, CURRENT_TIME);

        assertThat(command.description().value()).isEqualTo("   ");
    }

    @Test
    void shouldNotNormalizeValues() {

        UpdateStoryCommand command = request(
                PatchField.present("  Updated Story  "),
                PatchField.present("  Updated description  ")
        ).toCommand(AUTHENTICATED_USER, STORY_ID, CURRENT_TIME);

        assertThat(command.title().value())
                .isEqualTo("  Updated Story  ");
        assertThat(command.description().value())
                .isEqualTo("  Updated description  ");
    }

    @Test
    void shouldRejectNullFields() {

        assertThatThrownBy(() -> request(null, PatchField.omitted()))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("title must not be null");

        assertThatThrownBy(() -> request(PatchField.omitted(), null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("description must not be null");
    }

    @Test
    void shouldPreserveValueSemantics() {

        UpdateStoryRequest first = request(
                PatchField.present("Updated Story"),
                PatchField.present("Updated description")
        );
        UpdateStoryRequest second = request(
                PatchField.present("Updated Story"),
                PatchField.present("Updated description")
        );
        UpdateStoryRequest different = request(
                PatchField.present("Another Story"),
                PatchField.present("Updated description")
        );

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(different);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    private static UpdateStoryRequest request(
            PatchField<String> title,
            PatchField<String> description
    ) {
        return new UpdateStoryRequest(title, description);
    }
}
