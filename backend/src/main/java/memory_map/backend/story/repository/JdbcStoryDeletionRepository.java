package memory_map.backend.story.repository;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

@Repository
public class JdbcStoryDeletionRepository implements StoryDeletionRepository {

    private static final String FIND_MEDIA_STORAGE_KEYS_BY_STORY_ID_SQL = """
            SELECT
                mf.thumbnail_storage_key,
                mf.display_storage_key
            FROM media_files mf
            JOIN memories m
              ON m.id = mf.memory_id
            WHERE m.story_id = :storyId
            ORDER BY m.created_at ASC, mf.created_at ASC, mf.id ASC
            """;

    private static final String DELETE_INVITES_BY_STORY_ID_SQL = """
            DELETE FROM invites
            WHERE story_id = :storyId
            """;

    private static final String DELETE_MEMORIES_BY_STORY_ID_SQL = """
            DELETE FROM memories
            WHERE story_id = :storyId
            """;

    private static final String DELETE_STORY_BY_ID_SQL = """
            DELETE FROM stories
            WHERE id = :storyId
            """;

    private final JdbcClient jdbcClient;

    public JdbcStoryDeletionRepository(JdbcClient jdbcClient) {
        this.jdbcClient = Objects.requireNonNull(
                jdbcClient,
                "jdbcClient must not be null"
        );
    }

    @Override
    public List<StoryDeletionMediaStorageKeys> findMediaStorageKeysByStoryId(
            UUID storyId
    ) {
        Objects.requireNonNull(storyId, "storyId must not be null");

        return jdbcClient.sql(FIND_MEDIA_STORAGE_KEYS_BY_STORY_ID_SQL)
                .param("storyId", storyId)
                .query(this::mapMediaStorageKeys)
                .list();
    }

    @Override
    public int deleteInvitesByStoryId(UUID storyId) {
        Objects.requireNonNull(storyId, "storyId must not be null");

        return jdbcClient.sql(DELETE_INVITES_BY_STORY_ID_SQL)
                .param("storyId", storyId)
                .update();
    }

    @Override
    public int deleteMemoriesByStoryId(UUID storyId) {
        Objects.requireNonNull(storyId, "storyId must not be null");

        return jdbcClient.sql(DELETE_MEMORIES_BY_STORY_ID_SQL)
                .param("storyId", storyId)
                .update();
    }

    @Override
    public boolean deleteStoryById(UUID storyId) {
        Objects.requireNonNull(storyId, "storyId must not be null");

        int deletedRows = jdbcClient.sql(DELETE_STORY_BY_ID_SQL)
                .param("storyId", storyId)
                .update();

        return deletedRows == 1;
    }

    private StoryDeletionMediaStorageKeys mapMediaStorageKeys(
            ResultSet rs,
            int rowNum
    ) throws SQLException {
        return new StoryDeletionMediaStorageKeys(
                rs.getString("thumbnail_storage_key"),
                rs.getString("display_storage_key")
        );
    }
}
