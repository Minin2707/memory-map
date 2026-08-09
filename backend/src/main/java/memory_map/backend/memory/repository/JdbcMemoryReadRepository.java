package memory_map.backend.memory.repository;

import memory_map.backend.memory.application.StoryMemoriesView;
import memory_map.backend.memory.domain.Memory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

@Repository
public class JdbcMemoryReadRepository implements MemoryReadRepository {

    private static final String SELECT_MEMORY_COLUMNS_SQL = """
            SELECT
                m.id,
                m.story_id,
                m.created_by,
                m.title,
                m.description,
                m.place_name,
                ST_Y(m.location::geometry) AS latitude,
                ST_X(m.location::geometry) AS longitude,
                m.event_date,
                m.created_at,
                m.updated_at
            FROM memories m
            """;

    private static final String FIND_BY_STORY_ID_AND_REQUESTER_USER_ID_SQL = """
            SELECT
                m.id,
                m.story_id,
                m.created_by,
                m.title,
                m.description,
                m.place_name,
                ST_Y(m.location::geometry) AS latitude,
                ST_X(m.location::geometry) AS longitude,
                m.event_date,
                m.created_at,
                m.updated_at
            FROM story_participants requester
            LEFT JOIN memories m
              ON m.story_id = requester.story_id
            WHERE requester.story_id = :storyId
              AND requester.user_id = :requesterUserId
            ORDER BY
                m.event_date ASC NULLS LAST,
                m.created_at ASC NULLS LAST,
                m.id ASC NULLS LAST
            """;

    private static final String FIND_BY_ID_AND_REQUESTER_USER_ID_SQL =
            SELECT_MEMORY_COLUMNS_SQL + """
            WHERE m.id = :memoryId
              AND EXISTS (
                  SELECT 1
                  FROM story_participants requester
                  WHERE requester.story_id = m.story_id
                    AND requester.user_id = :requesterUserId
              )
            """;

    private final JdbcClient jdbcClient;
    private final MemoryRowMapper rowMapper;

    public JdbcMemoryReadRepository(JdbcClient jdbcClient) {
        this.jdbcClient = Objects.requireNonNull(
                jdbcClient,
                "jdbcClient must not be null"
        );
        this.rowMapper = new MemoryRowMapper();
    }

    @Override
    public Optional<StoryMemoriesView> findByStoryIdAndRequesterUserId(
            UUID storyId,
            UUID requesterUserId
    ) {
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(
                requesterUserId,
                "requesterUserId must not be null"
        );

        List<Memory> memories = new ArrayList<>();
        List<StoryMemoryReadRow> rows =
                jdbcClient.sql(FIND_BY_STORY_ID_AND_REQUESTER_USER_ID_SQL)
                        .param("storyId", storyId)
                        .param("requesterUserId", requesterUserId)
                        .query(this::mapStoryMemoryReadRow)
                        .list();

        if (rows.isEmpty()) {
            return Optional.empty();
        }

        for (StoryMemoryReadRow row : rows) {
            if (row.memory() != null) {
                memories.add(row.memory());
            }
        }

        return Optional.of(new StoryMemoriesView(memories));
    }

    @Override
    public Optional<Memory> findByIdAndRequesterUserId(
            UUID memoryId,
            UUID requesterUserId
    ) {
        Objects.requireNonNull(memoryId, "memoryId must not be null");
        Objects.requireNonNull(
                requesterUserId,
                "requesterUserId must not be null"
        );

        return jdbcClient.sql(FIND_BY_ID_AND_REQUESTER_USER_ID_SQL)
                .param("memoryId", memoryId)
                .param("requesterUserId", requesterUserId)
                .query(rowMapper)
                .optional();
    }

    private StoryMemoryReadRow mapStoryMemoryReadRow(
            ResultSet rs,
            int rowNum
    ) throws SQLException {
        UUID id = rs.getObject("id", UUID.class);

        if (id == null) {
            return new StoryMemoryReadRow(null);
        }

        return new StoryMemoryReadRow(rowMapper.mapRow(rs, rowNum));
    }

    private record StoryMemoryReadRow(

            Memory memory

    ) {
    }
}
