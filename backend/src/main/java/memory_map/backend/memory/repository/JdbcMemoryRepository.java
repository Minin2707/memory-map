package memory_map.backend.memory.repository;

import memory_map.backend.common.database.DatabaseTimestamps;
import memory_map.backend.memory.domain.Memory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class JdbcMemoryRepository implements MemoryRepository {

    private static final String SELECT_COLUMNS_SQL = """
            SELECT
                id,
                story_id,
                created_by,
                title,
                description,
                place_name,
                ST_Y(location::geometry) AS latitude,
                ST_X(location::geometry) AS longitude,
                event_date,
                created_at,
                updated_at
            FROM memories
            """;

    private static final String FIND_BY_ID_SQL = SELECT_COLUMNS_SQL + """
            WHERE id = :id
            """;

    private static final String FIND_BY_STORY_ID_SQL = SELECT_COLUMNS_SQL + """
            WHERE story_id = :storyId
            ORDER BY event_date ASC, created_at ASC, id ASC
            """;

    private static final String INSERT_SQL = """
            INSERT INTO memories (
                id,
                story_id,
                created_by,
                title,
                description,
                place_name,
                location,
                event_date,
                created_at,
                updated_at
            )
            VALUES (
                :id,
                :storyId,
                :createdBy,
                :title,
                :description,
                :placeName,
                ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)::geography,
                :eventDate,
                :createdAt,
                :updatedAt
            )
            """;

    private static final String UPDATE_SQL = """
            UPDATE memories
            SET
                title = :title,
                description = :description,
                place_name = :placeName,
                location = ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)::geography,
                event_date = :eventDate,
                updated_at = :updatedAt
            WHERE id = :id
            """;

    private static final String DELETE_SQL = """
            DELETE FROM memories
            WHERE id = :id
            """;

    private final JdbcClient jdbcClient;
    private final MemoryRowMapper rowMapper;

    public JdbcMemoryRepository(JdbcClient jdbcClient) {
        this.jdbcClient = jdbcClient;
        this.rowMapper = new MemoryRowMapper();
    }

    @Override
    public Optional<Memory> findById(UUID id) {

        return jdbcClient.sql(FIND_BY_ID_SQL)
                .param("id", id)
                .query(rowMapper)
                .optional();
    }

    @Override
    public List<Memory> findByStoryId(UUID storyId) {

        return jdbcClient.sql(FIND_BY_STORY_ID_SQL)
                .param("storyId", storyId)
                .query(rowMapper)
                .list();
    }

    @Override
    public void save(Memory memory) {

        jdbcClient.sql(INSERT_SQL)
                .param("id", memory.id())
                .param("storyId", memory.storyId())
                .param("createdBy", memory.createdBy())
                .param("title", memory.title())
                .param("description", memory.description())
                .param("placeName", memory.placeName())
                .param("longitude", memory.longitude())
                .param("latitude", memory.latitude())
                .param("eventDate", memory.eventDate())
                .param("createdAt", DatabaseTimestamps.toOffsetDateTime(memory.createdAt()))
                .param("updatedAt", DatabaseTimestamps.toOffsetDateTime(memory.updatedAt()))
                .update();
    }

    @Override
    public void update(Memory memory) {

        jdbcClient.sql(UPDATE_SQL)
                .param("id", memory.id())
                .param("title", memory.title())
                .param("description", memory.description())
                .param("placeName", memory.placeName())
                .param("longitude", memory.longitude())
                .param("latitude", memory.latitude())
                .param("eventDate", memory.eventDate())
                .param("updatedAt", DatabaseTimestamps.toOffsetDateTime(memory.updatedAt()))
                .update();
    }

    @Override
    public void delete(UUID id) {

        jdbcClient.sql(DELETE_SQL)
                .param("id", id)
                .update();
    }

}
