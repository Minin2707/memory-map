package memory_map.backend.memory.repository;

import memory_map.backend.memory.application.MemoryPreviewPhoto;
import memory_map.backend.memory.application.MemoryReadModel;
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
                m.updated_at,
                preview.preview_media_id
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
                m.updated_at,
                preview.preview_media_id
            FROM story_participants requester
            LEFT JOIN memories m
              ON m.story_id = requester.story_id
            LEFT JOIN LATERAL (
                SELECT mf.id AS preview_media_id
                FROM media_files mf
                WHERE mf.memory_id = m.id
                  AND mf.media_type = 'PHOTO'
                ORDER BY mf.created_at ASC, mf.id ASC
                LIMIT 1
            ) preview ON TRUE
            WHERE requester.story_id = :storyId
              AND requester.user_id = :requesterUserId
            ORDER BY
                m.event_date ASC NULLS LAST,
                m.created_at ASC NULLS LAST,
                m.id ASC NULLS LAST
            """;

    private static final String FIND_BY_ID_AND_REQUESTER_USER_ID_SQL =
            SELECT_MEMORY_COLUMNS_SQL + """
            LEFT JOIN LATERAL (
                SELECT mf.id AS preview_media_id
                FROM media_files mf
                WHERE mf.memory_id = m.id
                  AND mf.media_type = 'PHOTO'
                ORDER BY mf.created_at ASC, mf.id ASC
                LIMIT 1
            ) preview ON TRUE
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

        List<MemoryReadModel> memories = new ArrayList<>();
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
            if (row.memoryReadModel() != null) {
                memories.add(row.memoryReadModel());
            }
        }

        return Optional.of(new StoryMemoriesView(memories));
    }

    @Override
    public Optional<MemoryReadModel> findByIdAndRequesterUserId(
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
                .query(this::mapMemoryReadModel)
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

        return new StoryMemoryReadRow(mapMemoryReadModel(rs, rowNum));
    }

    private MemoryReadModel mapMemoryReadModel(
            ResultSet rs,
            int rowNum
    ) throws SQLException {
        Memory memory = rowMapper.mapRow(rs, rowNum);
        UUID previewMediaId = rs.getObject("preview_media_id", UUID.class);

        return new MemoryReadModel(
                memory,
                previewMediaId == null
                        ? null
                        : new MemoryPreviewPhoto(previewMediaId)
        );
    }

    private record StoryMemoryReadRow(

            MemoryReadModel memoryReadModel

    ) {
    }
}
