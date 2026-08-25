package memory_map.backend.music.api;

import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.domain.MusicTrackStatus;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MusicTrackResponseTest {

    private static final UUID TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final Instant TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    @Test
    void shouldMapSafePublicFieldsOnly() {
        MusicTrackResponse response = MusicTrackResponse.from(musicTrack());

        assertThat(response.id()).isEqualTo(TRACK_ID);
        assertThat(response.title()).isEqualTo("Calm Piano");
        assertThat(response.artist()).isEqualTo("Memory Story");
        assertThat(response.durationSeconds()).isEqualTo(180);
        assertThat(response.toString())
                .doesNotContain("storageKey")
                .doesNotContain("music/calm-piano.mp3")
                .doesNotContain("audio/mpeg")
                .doesNotContain("4096")
                .doesNotContain("ACTIVE")
                .doesNotContain("sortOrder")
                .doesNotContain(TIME.toString());
    }

    @Test
    void shouldRejectNullMusicTrack() {
        assertThatThrownBy(() -> MusicTrackResponse.from(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("musicTrack must not be null");
    }

    private static MusicTrack musicTrack() {
        return new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                7,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                TIME,
                TIME
        );
    }
}
