package memory_map.backend.music.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class SetStorySoundtrackCommandTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");

    @Test
    void shouldCreateCommandWhenValuesAreValid() {
        AuthenticatedUser authenticatedUser = new AuthenticatedUser(USER_ID);

        SetStorySoundtrackCommand command = new SetStorySoundtrackCommand(
                authenticatedUser,
                STORY_ID,
                TRACK_ID,
                CURRENT_TIME
        );

        assertThat(command.authenticatedUser()).isSameAs(authenticatedUser);
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(command.musicTrackId()).isEqualTo(TRACK_ID);
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldRejectNullValues() {
        AuthenticatedUser authenticatedUser = new AuthenticatedUser(USER_ID);

        assertThatThrownBy(() -> new SetStorySoundtrackCommand(
                null,
                STORY_ID,
                TRACK_ID,
                CURRENT_TIME
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");

        assertThatThrownBy(() -> new SetStorySoundtrackCommand(
                authenticatedUser,
                null,
                TRACK_ID,
                CURRENT_TIME
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");

        assertThatThrownBy(() -> new SetStorySoundtrackCommand(
                authenticatedUser,
                STORY_ID,
                null,
                CURRENT_TIME
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("musicTrackId must not be null");

        assertThatThrownBy(() -> new SetStorySoundtrackCommand(
                authenticatedUser,
                STORY_ID,
                TRACK_ID,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("currentTime must not be null");
    }

    @Test
    void shouldUseValueEqualityAndHashCode() {
        SetStorySoundtrackCommand first = command();
        SetStorySoundtrackCommand same = command();
        SetStorySoundtrackCommand other = new SetStorySoundtrackCommand(
                new AuthenticatedUser(USER_ID),
                STORY_ID,
                UUID.fromString("00000000-0000-0000-0000-000000000022"),
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
                .contains("SetStorySoundtrackCommand")
                .contains("currentTime=" + CURRENT_TIME)
                .doesNotContain(USER_ID.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(TRACK_ID.toString());
    }

    private static SetStorySoundtrackCommand command() {
        return new SetStorySoundtrackCommand(
                new AuthenticatedUser(USER_ID),
                STORY_ID,
                TRACK_ID,
                CURRENT_TIME
        );
    }
}
