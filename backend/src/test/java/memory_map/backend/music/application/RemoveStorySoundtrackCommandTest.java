package memory_map.backend.music.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class RemoveStorySoundtrackCommandTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");

    @Test
    void shouldCreateCommandWhenValuesAreValid() {
        AuthenticatedUser authenticatedUser = new AuthenticatedUser(USER_ID);

        RemoveStorySoundtrackCommand command =
                new RemoveStorySoundtrackCommand(
                        authenticatedUser,
                        STORY_ID,
                        CURRENT_TIME
                );

        assertThat(command.authenticatedUser()).isSameAs(authenticatedUser);
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldRejectNullValues() {
        AuthenticatedUser authenticatedUser = new AuthenticatedUser(USER_ID);

        assertThatThrownBy(() -> new RemoveStorySoundtrackCommand(
                null,
                STORY_ID,
                CURRENT_TIME
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");

        assertThatThrownBy(() -> new RemoveStorySoundtrackCommand(
                authenticatedUser,
                null,
                CURRENT_TIME
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");

        assertThatThrownBy(() -> new RemoveStorySoundtrackCommand(
                authenticatedUser,
                STORY_ID,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("currentTime must not be null");
    }

    @Test
    void shouldUseValueEqualityAndHashCode() {
        RemoveStorySoundtrackCommand first = command();
        RemoveStorySoundtrackCommand same = command();
        RemoveStorySoundtrackCommand other =
                new RemoveStorySoundtrackCommand(
                        new AuthenticatedUser(USER_ID),
                        UUID.fromString(
                                "00000000-0000-0000-0000-000000000012"
                        ),
                        CURRENT_TIME
                );

        assertThat(first)
                .isEqualTo(same)
                .hasSameHashCodeAs(same)
                .isNotEqualTo(other);
    }

    @Test
    void shouldHaveSafeToString() {
        String value = command().toString();

        assertThat(value)
                .contains("RemoveStorySoundtrackCommand")
                .contains("currentTime=" + CURRENT_TIME)
                .doesNotContain(USER_ID.toString())
                .doesNotContain(STORY_ID.toString());
    }

    private static RemoveStorySoundtrackCommand command() {
        return new RemoveStorySoundtrackCommand(
                new AuthenticatedUser(USER_ID),
                STORY_ID,
                CURRENT_TIME
        );
    }
}
