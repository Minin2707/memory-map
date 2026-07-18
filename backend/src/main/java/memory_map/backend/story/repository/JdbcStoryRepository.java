package memory_map.backend.story.repository;

import memory_map.backend.common.database.DatabaseTimestamps;
import memory_map.backend.story.domain.Story;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class JdbcStoryRepository implements StoryRepository {

    private static final String INSERT_SQL = """
            INSERT INTO stories (
                id,
                owner_id,
                title,
                description,
                created_at,
                updated_at
            )
            VALUES (
                :id,
                :ownerId,
                :title,
                :description,
                :createdAt,
                :updatedAt
            )
            RETURNING
                id,
                owner_id,
                title,
                description,
                created_at,
                updated_at
            """;

    private static final String FIND_BY_ID_SQL = """
            SELECT
                id,
                owner_id,
                title,
                description,
                created_at,
                updated_at
            FROM stories
            WHERE id = :id
            """;

    private static final String FIND_BY_OWNER_ID_SQL = """
            SELECT
                id,
                owner_id,
                title,
                description,
                created_at,
                updated_at
            FROM stories
            WHERE owner_id = :ownerId
            ORDER BY created_at DESC
            """;

    private final JdbcClient jdbcClient;
    private final StoryRowMapper rowMapper;

    public JdbcStoryRepository(
            JdbcClient jdbcClient,
            StoryRowMapper rowMapper
    ) {
        this.jdbcClient = jdbcClient;
        this.rowMapper = rowMapper;
    }

    @Override
    public Story save(Story story) {

        return jdbcClient.sql(INSERT_SQL)
                .param("id", story.id())
                .param("ownerId", story.ownerId())
                .param("title", story.title())
                .param("description", story.description())
                .param("createdAt", DatabaseTimestamps.toOffsetDateTime(story.createdAt()))
                .param("updatedAt", DatabaseTimestamps.toOffsetDateTime(story.updatedAt()))
                .query(rowMapper)
                .single();
    }

    @Override
    public Optional<Story> findById(UUID id) {

        return jdbcClient.sql(FIND_BY_ID_SQL)
                .param("id", id)
                .query(rowMapper)
                .optional();
    }

    @Override
    public List<Story> findByOwnerId(UUID ownerId) {

        return jdbcClient.sql(FIND_BY_OWNER_ID_SQL)
                .param("ownerId", ownerId)
                .query(rowMapper)
                .list();
    }
}
