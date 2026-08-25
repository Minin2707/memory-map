package memory_map.backend.story.api;

import memory_map.backend.music.application.StorySoundtrack;
import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.domain.MusicTrackStatus;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StorySoundtrackResponseTest {

    private static final UUID TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final Instant TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    @Test
    void shouldMapActiveSelectedAndEffectiveSoundtrack() {
        MusicTrack track = musicTrack(MusicTrackStatus.ACTIVE);

        StorySoundtrackResponse response = StorySoundtrackResponse.from(
                StorySoundtrack.selected(track)
        );

        assertThat(response.selectedSoundtrack().id()).isEqualTo(TRACK_ID);
        assertThat(response.effectiveSoundtrack().id()).isEqualTo(TRACK_ID);
    }

    @Test
    void shouldMapDisabledSelectedSoundtrackWithoutEffectiveSoundtrack() {
        MusicTrack track = musicTrack(MusicTrackStatus.DISABLED);

        StorySoundtrackResponse response = StorySoundtrackResponse.from(
                StorySoundtrack.selected(track)
        );

        assertThat(response.selectedSoundtrack().id()).isEqualTo(TRACK_ID);
        assertThat(response.effectiveSoundtrack()).isNull();
        assertThat(response.toString())
                .doesNotContain("DISABLED")
                .doesNotContain("music/calm-piano.mp3")
                .doesNotContain("audio/mpeg")
                .doesNotContain("4096");
    }

    @Test
    void shouldMapNoMusic() {
        StorySoundtrackResponse response = StorySoundtrackResponse.from(
                StorySoundtrack.noMusic()
        );

        assertThat(response.selectedSoundtrack()).isNull();
        assertThat(response.effectiveSoundtrack()).isNull();
    }

    @Test
    void shouldRejectNullStorySoundtrack() {
        assertThatThrownBy(() -> StorySoundtrackResponse.from(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storySoundtrack must not be null");
    }

    private static MusicTrack musicTrack(MusicTrackStatus status) {
        return new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                180,
                status,
                7,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                TIME,
                TIME
        );
    }
}
