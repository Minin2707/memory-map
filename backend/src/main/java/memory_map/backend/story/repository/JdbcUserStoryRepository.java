package memory_map.backend.story.repository;

import memory_map.backend.story.application.UserStory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Objects;
import java.util.UUID;

@Repository
public class JdbcUserStoryRepository implements UserStoryRepository {

    private static final String FIND_BY_USER_ID_SQL = """
            SELECT
                s.id,
                s.owner_id,
                s.title,
                s.description,
                s.created_at,
                s.updated_at,
                sp.role
            FROM story_participants sp
            JOIN stories s
              ON s.id = sp.story_id
            WHERE sp.user_id = :userId
            ORDER BY sp.joined_at ASC, s.id ASC
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
        return jdbcClient.sql(FIND_BY_USER_ID_SQL)
                .param("userId", userId)
                .query(rowMapper)
                .list();
    }
}
