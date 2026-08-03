package memory_map.backend.story.repository;

import memory_map.backend.story.application.StoryParticipantView;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Objects;
import java.util.UUID;

@Repository
public class JdbcStoryParticipantViewRepository
        implements StoryParticipantViewRepository {

    private static final String FIND_BY_STORY_ID_AND_REQUESTER_USER_ID_SQL = """
            SELECT
                target.user_id,
                u.display_name,
                u.avatar_url,
                target.role,
                target.joined_at
            FROM story_participants target
            JOIN users u
              ON u.id = target.user_id
            WHERE target.story_id = :storyId
              AND EXISTS (
                  SELECT 1
                  FROM story_participants requester
                  WHERE requester.story_id = :storyId
                    AND requester.user_id = :requesterUserId
              )
            ORDER BY target.joined_at ASC, target.user_id ASC
            """;

    private final JdbcClient jdbcClient;
    private final StoryParticipantViewRowMapper rowMapper;

    public JdbcStoryParticipantViewRepository(JdbcClient jdbcClient) {
        this.jdbcClient = Objects.requireNonNull(
                jdbcClient,
                "jdbcClient must not be null"
        );
        this.rowMapper = new StoryParticipantViewRowMapper();
    }

    @Override
    public List<StoryParticipantView> findByStoryIdAndRequesterUserId(
            UUID storyId,
            UUID requesterUserId
    ) {
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(
                requesterUserId,
                "requesterUserId must not be null"
        );

        return jdbcClient.sql(FIND_BY_STORY_ID_AND_REQUESTER_USER_ID_SQL)
                .param("storyId", storyId)
                .param("requesterUserId", requesterUserId)
                .query(rowMapper)
                .list();
    }
}
