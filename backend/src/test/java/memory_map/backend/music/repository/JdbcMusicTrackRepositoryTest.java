package memory_map.backend.music.repository;

import memory_map.backend.IntegrationTest;
import memory_map.backend.common.database.DatabaseTimestamps;
import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.domain.MusicTrackStatus;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JdbcMusicTrackRepositoryTest extends IntegrationTest {

    @Autowired
    private MusicTrackRepository repository;

    @Autowired
    private JdbcClient jdbcClient;

    private static final UUID TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID SECOND_TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID THIRD_TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final Instant BASE_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE music_tracks
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
    }

    @Test
    void shouldFindMusicTrackById() {
        MusicTrack musicTrack = musicTrack(TRACK_ID);
        insertMusicTrack(musicTrack);

        Optional<MusicTrack> result = repository.findById(TRACK_ID);

        assertThat(result).contains(musicTrack);
    }

    @Test
    void shouldReturnEmptyWhenMusicTrackDoesNotExist() {
        Optional<MusicTrack> result = repository.findById(TRACK_ID);

        assertThat(result).isEmpty();
    }

    @Test
    void shouldMapAllFields() {
        MusicTrack musicTrack = new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                180,
                MusicTrackStatus.DISABLED,
                7,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                BASE_TIME,
                BASE_TIME.plusSeconds(60)
        );
        insertMusicTrack(musicTrack);

        MusicTrack result = repository.findById(TRACK_ID)
                .orElseThrow();

        assertThat(result).isEqualTo(musicTrack);
    }

    @Test
    void shouldFindActiveTracksOnly() {
        MusicTrack active = musicTrack(TRACK_ID);
        MusicTrack disabled = new MusicTrack(
                SECOND_TRACK_ID,
                "Disabled Track",
                "Memory Story",
                180,
                MusicTrackStatus.DISABLED,
                1,
                "music/disabled.mp3",
                "audio/mpeg",
                4_096L,
                BASE_TIME,
                BASE_TIME
        );
        insertMusicTrack(active);
        insertMusicTrack(disabled);

        List<MusicTrack> result = repository.findActive();

        assertThat(result).containsExactly(active);
    }

    @Test
    void shouldFindActiveTracksSortedBySortOrderAndId() {
        MusicTrack first = new MusicTrack(
                TRACK_ID,
                "First",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                1,
                "music/first.mp3",
                "audio/mpeg",
                4_096L,
                BASE_TIME,
                BASE_TIME
        );
        MusicTrack second = new MusicTrack(
                SECOND_TRACK_ID,
                "Second",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                1,
                "music/second.mp3",
                "audio/mpeg",
                4_096L,
                BASE_TIME,
                BASE_TIME
        );
        MusicTrack earlierSortOrder = new MusicTrack(
                THIRD_TRACK_ID,
                "Earlier",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                0,
                "music/earlier.mp3",
                "audio/mpeg",
                4_096L,
                BASE_TIME,
                BASE_TIME
        );
        insertMusicTrack(second);
        insertMusicTrack(earlierSortOrder);
        insertMusicTrack(first);

        List<MusicTrack> result = repository.findActive();

        assertThat(result)
                .extracting(MusicTrack::id)
                .containsExactly(
                        earlierSortOrder.id(),
                        first.id(),
                        second.id()
                );
    }

    @Test
    void shouldRejectDuplicateStorageKey() {
        MusicTrack first = musicTrack(TRACK_ID);
        MusicTrack duplicate = new MusicTrack(
                SECOND_TRACK_ID,
                "Duplicate",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                1,
                first.storageKey(),
                "audio/mpeg",
                4_096L,
                BASE_TIME,
                BASE_TIME
        );
        insertMusicTrack(first);

        assertThatThrownBy(() -> insertMusicTrack(duplicate))
                .isInstanceOf(DuplicateKeyException.class);
    }

    private MusicTrack musicTrack(UUID id) {
        return new MusicTrack(
                id,
                "Calm Piano",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                0,
                "music/" + id + ".mp3",
                "audio/mpeg",
                4_096L,
                BASE_TIME,
                BASE_TIME
        );
    }

    private void insertMusicTrack(MusicTrack musicTrack) {
        jdbcClient.sql("""
                INSERT INTO music_tracks (
                    id,
                    title,
                    artist,
                    duration_seconds,
                    status,
                    sort_order,
                    storage_key,
                    mime_type,
                    file_size,
                    created_at,
                    updated_at
                )
                VALUES (
                    :id,
                    :title,
                    :artist,
                    :durationSeconds,
                    :status,
                    :sortOrder,
                    :storageKey,
                    :mimeType,
                    :fileSize,
                    :createdAt,
                    :updatedAt
                )
                """)
                .param("id", musicTrack.id())
                .param("title", musicTrack.title())
                .param("artist", musicTrack.artist())
                .param("durationSeconds", musicTrack.durationSeconds())
                .param("status", musicTrack.status().name())
                .param("sortOrder", musicTrack.sortOrder())
                .param("storageKey", musicTrack.storageKey())
                .param("mimeType", musicTrack.mimeType())
                .param("fileSize", musicTrack.fileSize())
                .param(
                        "createdAt",
                        DatabaseTimestamps.toOffsetDateTime(
                                musicTrack.createdAt()
                        )
                )
                .param(
                        "updatedAt",
                        DatabaseTimestamps.toOffsetDateTime(
                                musicTrack.updatedAt()
                        )
                )
                .update();
    }
}
