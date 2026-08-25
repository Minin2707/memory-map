package memory_map.backend.music.application;

import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.domain.MusicTrackStatus;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StorySoundtrackTest {

    private static final Instant TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    @Test
    void shouldRepresentNoMusic() {
        StorySoundtrack result = StorySoundtrack.noMusic();

        assertThat(result.selectedSoundtrack()).isNull();
        assertThat(result.effectiveSoundtrack()).isNull();
    }

    @Test
    void shouldMakeActiveSelectedTrackEffective() {
        MusicTrack active = musicTrack(MusicTrackStatus.ACTIVE);

        StorySoundtrack result = StorySoundtrack.selected(active);

        assertThat(result.selectedSoundtrack()).isSameAs(active);
        assertThat(result.effectiveSoundtrack()).isSameAs(active);
    }

    @Test
    void shouldKeepDisabledSelectedTrackIneffective() {
        MusicTrack disabled = musicTrack(MusicTrackStatus.DISABLED);

        StorySoundtrack result = StorySoundtrack.selected(disabled);

        assertThat(result.selectedSoundtrack()).isSameAs(disabled);
        assertThat(result.effectiveSoundtrack()).isNull();
    }

    @Test
    void shouldRejectEffectiveWithoutSelected() {
        MusicTrack active = musicTrack(MusicTrackStatus.ACTIVE);

        assertThatThrownBy(() -> new StorySoundtrack(null, active))
                .isInstanceOf(NullPointerException.class)
                .hasMessage(
                        "selectedSoundtrack must not be null when effectiveSoundtrack is provided"
                );
    }

    @Test
    void shouldRejectDifferentEffectiveTrack() {
        MusicTrack selected = musicTrack(MusicTrackStatus.ACTIVE);
        MusicTrack other = new MusicTrack(
                UUID.fromString("00000000-0000-0000-0000-000000000012"),
                "Other",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                1,
                "music/other.mp3",
                "audio/mpeg",
                4_096L,
                TIME,
                TIME
        );

        assertThatThrownBy(() -> new StorySoundtrack(selected, other))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("effectiveSoundtrack must match selectedSoundtrack");
    }

    @Test
    void shouldRejectDisabledEffectiveTrack() {
        MusicTrack disabled = musicTrack(MusicTrackStatus.DISABLED);

        assertThatThrownBy(() -> new StorySoundtrack(disabled, disabled))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("effectiveSoundtrack must be active");
    }

    @Test
    void shouldRejectActiveSelectedWithoutEffectiveTrack() {
        MusicTrack active = musicTrack(MusicTrackStatus.ACTIVE);

        assertThatThrownBy(() -> new StorySoundtrack(active, null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("active selectedSoundtrack must also be effective");
    }

    @Test
    void shouldRejectNullSelectedFactoryArgument() {
        assertThatThrownBy(() -> StorySoundtrack.selected(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("musicTrack must not be null");
    }

    @Test
    void shouldHaveSafeToString() {
        String value = StorySoundtrack.selected(
                musicTrack(MusicTrackStatus.ACTIVE)
        ).toString();

        assertThat(value)
                .contains("StorySoundtrack")
                .contains("Calm Piano")
                .doesNotContain("music/calm-piano.mp3")
                .doesNotContain("audio/mpeg")
                .doesNotContain("4096");
    }

    private static MusicTrack musicTrack(MusicTrackStatus status) {
        return new MusicTrack(
                UUID.fromString("00000000-0000-0000-0000-000000000011"),
                "Calm Piano",
                "Memory Story",
                180,
                status,
                0,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                TIME,
                TIME
        );
    }
}
