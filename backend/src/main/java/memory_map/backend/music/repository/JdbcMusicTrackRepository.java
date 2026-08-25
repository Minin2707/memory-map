package memory_map.backend.music.repository;

import memory_map.backend.music.domain.MusicTrack;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

@Repository
public class JdbcMusicTrackRepository implements MusicTrackRepository {

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

    private static final String FIND_ACTIVE_SQL = SELECT_COLUMNS_SQL + """
            WHERE status = 'ACTIVE'
            ORDER BY sort_order ASC, id ASC
            """;

    private final JdbcClient jdbcClient;
    private final MusicTrackRowMapper rowMapper;

    public JdbcMusicTrackRepository(JdbcClient jdbcClient) {
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
    public List<MusicTrack> findActive() {
        return jdbcClient.sql(FIND_ACTIVE_SQL)
                .query(rowMapper)
                .list();
    }
}
