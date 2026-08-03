package memory_map.backend.storyparticipant.repository;

import memory_map.backend.common.database.DatabaseTimestamps;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

@Repository
public class JdbcStoryParticipantRepository implements StoryParticipantRepository {

    private static final String INSERT_SQL = """
            INSERT INTO story_participants (
                story_id,
                user_id,
                role,
                joined_at
            )
            VALUES (
                :storyId,
                :userId,
                :role,
                :joinedAt
            )
            """;

    private static final String FIND_SQL = """
            SELECT
                story_id,
                user_id,
                role,
                joined_at
            FROM story_participants
            WHERE story_id = :storyId
              AND user_id = :userId
            """;

    private static final String FIND_BY_STORY_ID_SQL = """
            SELECT
                story_id,
                user_id,
                role,
                joined_at
            FROM story_participants
            WHERE story_id = :storyId
            ORDER BY joined_at ASC, user_id ASC
            """;

    private static final String FIND_BY_USER_ID_SQL = """
            SELECT
                story_id,
                user_id,
                role,
                joined_at
            FROM story_participants
            WHERE user_id = :userId
            ORDER BY joined_at ASC, story_id ASC
            """;

    private static final String EXISTS_SQL = """
            SELECT EXISTS (
                SELECT 1
                FROM story_participants
                WHERE story_id = :storyId
                  AND user_id = :userId
            )
            """;

    private static final String COUNT_OWNERS_SQL = """
            SELECT COUNT(*)
            FROM story_participants
            WHERE story_id = :storyId
              AND role = 'OWNER'
            """;

    private static final String UPDATE_SQL = """
            UPDATE story_participants
            SET role = :role
            WHERE story_id = :storyId
              AND user_id = :userId
            """;

    private static final String DELETE_SQL = """
            DELETE FROM story_participants
            WHERE story_id = :storyId
              AND user_id = :userId
            """;

    private final JdbcClient jdbcClient;
    private final StoryParticipantRowMapper rowMapper;

    public JdbcStoryParticipantRepository(JdbcClient jdbcClient) {
        this.jdbcClient = jdbcClient;
        this.rowMapper = new StoryParticipantRowMapper();
    }

    @Override
    public Optional<StoryParticipant> find(UUID storyId, UUID userId) {

        return jdbcClient.sql(FIND_SQL)
                .param("storyId", storyId)
                .param("userId", userId)
                .query(rowMapper)
                .optional();
    }

    @Override
    public List<StoryParticipant> findByStoryId(UUID storyId) {

        return jdbcClient.sql(FIND_BY_STORY_ID_SQL)
                .param("storyId", storyId)
                .query(rowMapper)
                .list();
    }

    @Override
    public List<StoryParticipant> findByUserId(UUID userId) {

        return jdbcClient.sql(FIND_BY_USER_ID_SQL)
                .param("userId", userId)
                .query(rowMapper)
                .list();
    }

    @Override
    public long countOwners(UUID storyId) {

        Objects.requireNonNull(storyId, "storyId must not be null");

        return jdbcClient.sql(COUNT_OWNERS_SQL)
                .param("storyId", storyId)
                .query(Long.class)
                .single();
    }

    @Override
    public boolean exists(UUID storyId, UUID userId) {

        return jdbcClient.sql(EXISTS_SQL)
                .param("storyId", storyId)
                .param("userId", userId)
                .query(Boolean.class)
                .single();
    }

    @Override
    public void save(StoryParticipant participant) {

        jdbcClient.sql(INSERT_SQL)
                .param("storyId", participant.storyId())
                .param("userId", participant.userId())
                .param("role", participant.role().name())
                .param("joinedAt", DatabaseTimestamps.toOffsetDateTime(participant.joinedAt()))
                .update();
    }

    @Override
    public void update(StoryParticipant participant) {

        jdbcClient.sql(UPDATE_SQL)
                .param("storyId", participant.storyId())
                .param("userId", participant.userId())
                .param("role", participant.role().name())
                .update();
    }

    @Override
    public void delete(UUID storyId, UUID userId) {

        jdbcClient.sql(DELETE_SQL)
                .param("storyId", storyId)
                .param("userId", userId)
                .update();
    }

}
