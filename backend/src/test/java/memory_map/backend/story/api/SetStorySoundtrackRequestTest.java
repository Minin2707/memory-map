package memory_map.backend.story.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.music.application.SetStorySoundtrackCommand;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class SetStorySoundtrackRequestTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");

    @Test
    void shouldConvertToCommand() {
        AuthenticatedUser authenticatedUser = new AuthenticatedUser(USER_ID);

        SetStorySoundtrackCommand command =
                new SetStorySoundtrackRequest(TRACK_ID).toCommand(
                        authenticatedUser,
                        STORY_ID,
                        CURRENT_TIME
                );

        assertThat(command.authenticatedUser()).isSameAs(authenticatedUser);
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(command.musicTrackId()).isEqualTo(TRACK_ID);
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldRejectNullMusicTrackId() {
        assertThatThrownBy(() -> new SetStorySoundtrackRequest(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("musicTrackId must not be null");
    }
}
