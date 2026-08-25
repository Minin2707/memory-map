package memory_map.backend.music.infrastructure.catalog;

import memory_map.backend.IntegrationTest;
import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.domain.MusicTrackStatus;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JdbcMusicCatalogWriterTest extends IntegrationTest {

    private static final UUID TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant UPDATED_AT =
            Instant.parse("2026-01-01T10:00:01Z");

    @Autowired
    private JdbcClient jdbcClient;

    private JdbcMusicCatalogWriter writer;

    @BeforeEach
    void setUp() {
        jdbcClient.sql("""
                TRUNCATE TABLE music_tracks
                RESTART IDENTITY CASCADE
                """).update();
        writer = new JdbcMusicCatalogWriter(jdbcClient);
    }

    @Test
    void shouldInsertDisabledTrack() {
        MusicTrack track = disabledTrack();

        writer.insertDisabled(track);

        assertThat(writer.findById(TRACK_ID)).contains(track);
    }

    @Test
    void shouldRejectInsertWhenTrackIsNotDisabled() {
        MusicTrack track = new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                270,
                MusicTrackStatus.ACTIVE,
                10,
                storageKey(),
                "audio/mpeg",
                5L,
                CREATED_AT,
                UPDATED_AT
        );

        assertThatThrownBy(() -> writer.insertDisabled(track))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("musicTrack status must be DISABLED");
    }

    @Test
    void shouldFindTrackIdByStorageKey() {
        writer.insertDisabled(disabledTrack());

        Optional<UUID> result = writer.findTrackIdByStorageKey(storageKey());

        assertThat(result).contains(TRACK_ID);
    }

    @Test
    void shouldUpdateMetadataAndPreserveImmutableFields() {
        writer.insertDisabled(disabledTrack());

        writer.updateMetadata(
                TRACK_ID,
                "Updated",
                "Updated Artist",
                99,
                UPDATED_AT.plusSeconds(10)
        );

        MusicTrack result = writer.findById(TRACK_ID).orElseThrow();
        assertThat(result.title()).isEqualTo("Updated");
        assertThat(result.artist()).isEqualTo("Updated Artist");
        assertThat(result.sortOrder()).isEqualTo(99);
        assertThat(result.id()).isEqualTo(TRACK_ID);
        assertThat(result.durationSeconds()).isEqualTo(270);
        assertThat(result.storageKey()).isEqualTo(storageKey());
        assertThat(result.mimeType()).isEqualTo("audio/mpeg");
        assertThat(result.fileSize()).isEqualTo(5L);
        assertThat(result.createdAt()).isEqualTo(CREATED_AT);
        assertThat(result.updatedAt()).isEqualTo(UPDATED_AT.plusSeconds(10));
    }

    @Test
    void shouldUpdateStatusWithoutDeletingTrack() {
        writer.insertDisabled(disabledTrack());

        writer.updateStatus(
                TRACK_ID,
                MusicTrackStatus.ACTIVE,
                UPDATED_AT.plusSeconds(20)
        );

        MusicTrack result = writer.findById(TRACK_ID).orElseThrow();
        assertThat(result.status()).isEqualTo(MusicTrackStatus.ACTIVE);
        assertThat(result.updatedAt()).isEqualTo(UPDATED_AT.plusSeconds(20));
        assertThat(writer.findById(TRACK_ID)).isPresent();
    }

    private static MusicTrack disabledTrack() {
        return new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                270,
                MusicTrackStatus.DISABLED,
                10,
                storageKey(),
                "audio/mpeg",
                5L,
                CREATED_AT,
                UPDATED_AT
        );
    }

    private static String storageKey() {
        return "music/tracks/" + TRACK_ID + "/audio.mp3";
    }
}
