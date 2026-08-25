package memory_map.backend.music.infrastructure.catalog;

import memory_map.backend.common.database.DatabaseTimestamps;
import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.domain.MusicTrackStatus;
import memory_map.backend.music.repository.MusicTrackRowMapper;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.time.Instant;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

public final class JdbcMusicCatalogWriter implements MusicCatalogWriter {

    private static final String SELECT_COLUMNS_SQL = """
            SELECT
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
            FROM music_tracks
            """;

    private static final String FIND_BY_ID_SQL = SELECT_COLUMNS_SQL + """
            WHERE id = :id
            """;

    private static final String FIND_ID_BY_STORAGE_KEY_SQL = """
            SELECT id
            FROM music_tracks
            WHERE storage_key = :storageKey
            """;

    private static final String INSERT_DISABLED_SQL = """
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
                'DISABLED',
                :sortOrder,
                :storageKey,
                :mimeType,
                :fileSize,
                :createdAt,
                :updatedAt
            )
            """;

    private static final String UPDATE_METADATA_SQL = """
            UPDATE music_tracks
            SET title = :title,
                artist = :artist,
                sort_order = :sortOrder,
                updated_at = :updatedAt
            WHERE id = :id
            """;

    private static final String UPDATE_STATUS_SQL = """
            UPDATE music_tracks
            SET status = :status,
                updated_at = :updatedAt
            WHERE id = :id
            """;

    private final JdbcClient jdbcClient;
    private final MusicTrackRowMapper rowMapper;

    public JdbcMusicCatalogWriter(JdbcClient jdbcClient) {
        this.jdbcClient = Objects.requireNonNull(
                jdbcClient,
                "jdbcClient must not be null"
        );
        this.rowMapper = new MusicTrackRowMapper();
    }

    @Override
    public Optional<MusicTrack> findById(UUID id) {
        Objects.requireNonNull(id, "id must not be null");

        return jdbcClient.sql(FIND_BY_ID_SQL)
                .param("id", id)
                .query(rowMapper)
                .optional();
    }

    @Override
    public Optional<UUID> findTrackIdByStorageKey(String storageKey) {
        Objects.requireNonNull(
                storageKey,
                "storageKey must not be null"
        );

        return jdbcClient.sql(FIND_ID_BY_STORAGE_KEY_SQL)
                .param("storageKey", storageKey)
                .query(UUID.class)
                .optional();
    }

    @Override
    public void insertDisabled(MusicTrack musicTrack) {
        Objects.requireNonNull(
                musicTrack,
                "musicTrack must not be null"
        );

        if (musicTrack.status() != MusicTrackStatus.DISABLED) {
            throw new IllegalArgumentException(
                    "musicTrack status must be DISABLED"
            );
        }

        jdbcClient.sql(INSERT_DISABLED_SQL)
                .param("id", musicTrack.id())
                .param("title", musicTrack.title())
                .param("artist", musicTrack.artist())
                .param("durationSeconds", musicTrack.durationSeconds())
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

    @Override
    public void updateMetadata(
            UUID id,
            String title,
            String artist,
            int sortOrder,
            Instant updatedAt
    ) {
        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(title, "title must not be null");
        Objects.requireNonNull(artist, "artist must not be null");
        Objects.requireNonNull(updatedAt, "updatedAt must not be null");

        jdbcClient.sql(UPDATE_METADATA_SQL)
                .param("id", id)
                .param("title", title)
                .param("artist", artist)
                .param("sortOrder", sortOrder)
                .param(
                        "updatedAt",
                        DatabaseTimestamps.toOffsetDateTime(updatedAt)
                )
                .update();
    }

    @Override
    public void updateStatus(
            UUID id,
            MusicTrackStatus status,
            Instant updatedAt
    ) {
        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(status, "status must not be null");
        Objects.requireNonNull(updatedAt, "updatedAt must not be null");

        jdbcClient.sql(UPDATE_STATUS_SQL)
                .param("id", id)
                .param("status", status.name())
                .param(
                        "updatedAt",
                        DatabaseTimestamps.toOffsetDateTime(updatedAt)
                )
                .update();
    }
}
