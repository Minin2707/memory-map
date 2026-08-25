package memory_map.backend.music.infrastructure.catalog;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MusicTrackStorageKeyFactoryTest {

    private static final UUID TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");

    @Test
    void shouldCreateExpectedProviderNeutralKey() {
        MusicTrackStorageKeyFactory factory =
                new MusicTrackStorageKeyFactory();

        String result = factory.storageKeyFor(TRACK_ID);

        assertThat(result)
                .isEqualTo(
                        "music/tracks/00000000-0000-0000-0000-000000000001/audio.mp3"
                );
    }

    @Test
    void shouldKeepMappingStable() {
        MusicTrackStorageKeyFactory factory =
                new MusicTrackStorageKeyFactory();

        assertThat(factory.storageKeyFor(TRACK_ID))
                .isEqualTo(factory.storageKeyFor(TRACK_ID));
    }

    @Test
    void shouldRejectNullTrackId() {
        MusicTrackStorageKeyFactory factory =
                new MusicTrackStorageKeyFactory();

        assertThatThrownBy(() -> factory.storageKeyFor(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("musicTrackId must not be null");
    }
}
