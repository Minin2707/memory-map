package memory_map.backend.story.repository;

import memory_map.backend.story.application.UserStory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

@Repository
public class JdbcUserStoryRepository implements UserStoryRepository {

    private static final String FIND_BY_USER_ID_SQL = """
            SELECT
                s.id,
                s.owner_id,
                s.title,
                s.description,
                s.soundtrack_id,
                s.created_at,
                s.updated_at,
                requester.role,
                memory_count.memory_count,
                participant_count.participant_count,
                preview.preview_media_id
            FROM story_participants requester
            JOIN stories s
              ON s.id = requester.story_id
            LEFT JOIN LATERAL (
                SELECT COUNT(*) AS memory_count
                FROM memories m_count
                WHERE m_count.story_id = s.id
            ) memory_count ON TRUE
            LEFT JOIN LATERAL (
                SELECT COUNT(*) AS participant_count
                FROM story_participants sp_count
                WHERE sp_count.story_id = s.id
            ) participant_count ON TRUE
            LEFT JOIN LATERAL (
                SELECT selected_photo.id AS preview_media_id
                FROM memories selected_memory
                JOIN LATERAL (
                    SELECT mf.id
                    FROM media_files mf
                    WHERE mf.memory_id = selected_memory.id
                      AND mf.media_type = 'PHOTO'
                    ORDER BY mf.created_at ASC, mf.id ASC
                    LIMIT 1
                ) selected_photo ON TRUE
                WHERE selected_memory.story_id = s.id
                ORDER BY
                    selected_memory.event_date DESC,
                    selected_memory.created_at DESC,
                    selected_memory.id DESC
                LIMIT 1
            ) preview ON TRUE
            WHERE requester.user_id = :userId
            ORDER BY requester.joined_at ASC, s.id ASC
            """;

    private static final String FIND_BY_STORY_ID_AND_USER_ID_SQL = """
            SELECT
                s.id,
                s.owner_id,
                s.title,
                s.description,
                s.soundtrack_id,
                s.created_at,
                s.updated_at,
                requester.role,
                memory_count.memory_count,
                participant_count.participant_count,
                preview.preview_media_id
            FROM story_participants requester
            JOIN stories s
              ON s.id = requester.story_id
            LEFT JOIN LATERAL (
                SELECT COUNT(*) AS memory_count
                FROM memories m_count
                WHERE m_count.story_id = s.id
            ) memory_count ON TRUE
            LEFT JOIN LATERAL (
                SELECT COUNT(*) AS participant_count
                FROM story_participants sp_count
                WHERE sp_count.story_id = s.id
            ) participant_count ON TRUE
            LEFT JOIN LATERAL (
                SELECT selected_photo.id AS preview_media_id
                FROM memories selected_memory
                JOIN LATERAL (
                    SELECT mf.id
                    FROM media_files mf
                    WHERE mf.memory_id = selected_memory.id
                      AND mf.media_type = 'PHOTO'
                    ORDER BY mf.created_at ASC, mf.id ASC
                    LIMIT 1
                ) selected_photo ON TRUE
                WHERE selected_memory.story_id = s.id
                ORDER BY
                    selected_memory.event_date DESC,
                    selected_memory.created_at DESC,
                    selected_memory.id DESC
                LIMIT 1
            ) preview ON TRUE
            WHERE requester.story_id = :storyId
              AND requester.user_id = :userId
            """;

    private final JdbcClient jdbcClient;
    private final UserStoryRowMapper rowMapper;

    public JdbcUserStoryRepository(JdbcClient jdbcClient) {
        this.jdbcClient = Objects.requireNonNull(
                jdbcClient,
                "jdbcClient must not be null"
        );
        this.rowMapper = new UserStoryRowMapper();
    }

    @Override
    public List<UserStory> findByUserId(UUID userId) {
        Objects.requireNonNull(userId, "userId must not be null");

        return jdbcClient.sql(FIND_BY_USER_ID_SQL)
                .param("userId", userId)
                .query(rowMapper)
                .list();
    }

    @Override
    public Optional<UserStory> findByStoryIdAndUserId(
            UUID storyId,
            UUID userId
    ) {
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(userId, "userId must not be null");

        return jdbcClient.sql(FIND_BY_STORY_ID_AND_USER_ID_SQL)
                .param("storyId", storyId)
                .param("userId", userId)
                .query(rowMapper)
                .optional();
    }
}
