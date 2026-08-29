package memory_map.backend.account.repository;

import memory_map.backend.common.database.DatabaseTimestamps;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRowMapper;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRowMapper;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

@Repository
public class JdbcAccountDeletionRepository
        implements AccountDeletionRepository {

    private static final String FIND_OWNED_STORIES_FOR_UPDATE_SQL = """
            SELECT
                id,
                owner_id,
                title,
                description,
                soundtrack_id,
                created_at,
                updated_at
            FROM stories
            WHERE owner_id = :ownerId
            ORDER BY created_at ASC, id ASC
            FOR UPDATE
            """;

    private static final String FIND_PARTICIPANTS_FOR_STORIES_FOR_UPDATE_SQL =
            """
            SELECT
                story_id,
                user_id,
                role,
                joined_at
            FROM story_participants
            WHERE story_id IN (:storyIds)
            ORDER BY story_id ASC, joined_at ASC, user_id ASC
            FOR UPDATE
            """;

    private static final String FIND_USER_PARTICIPATIONS_FOR_UPDATE_SQL = """
            SELECT
                story_id,
                user_id,
                role,
                joined_at
            FROM story_participants
            WHERE user_id = :userId
            ORDER BY story_id ASC
            FOR UPDATE
            """;

    private static final String FIND_MEDIA_STORAGE_KEYS_BY_STORY_IDS_SQL = """
            SELECT
                mf.thumbnail_storage_key,
                mf.display_storage_key
            FROM media_files mf
            JOIN memories m
              ON m.id = mf.memory_id
            WHERE m.story_id IN (:storyIds)
            ORDER BY m.story_id ASC, m.created_at ASC, mf.created_at ASC, mf.id ASC
            """;

    private static final String TRANSFER_STORY_OWNER_SQL = """
            UPDATE stories
            SET owner_id = :newOwnerId,
                updated_at = :updatedAt
            WHERE id = :storyId
            """;

    private static final String UPDATE_PARTICIPANT_ROLE_SQL = """
            UPDATE story_participants
            SET role = :role
            WHERE story_id = :storyId
              AND user_id = :userId
            """;

    private static final String DELETE_PARTICIPANT_SQL = """
            DELETE FROM story_participants
            WHERE story_id = :storyId
              AND user_id = :userId
            """;

    private static final String DELETE_INVITES_BY_STORY_IDS_SQL = """
            DELETE FROM invites
            WHERE story_id IN (:storyIds)
            """;

    private static final String DELETE_UNUSED_INVITES_CREATED_BY_SQL = """
            DELETE FROM invites
            WHERE created_by = :userId
              AND used_at IS NULL
            """;

    private static final String DELETE_MEMORIES_BY_STORY_IDS_SQL = """
            DELETE FROM memories
            WHERE story_id IN (:storyIds)
            """;

    private static final String DELETE_STORIES_BY_IDS_SQL = """
            DELETE FROM stories
            WHERE id IN (:storyIds)
            """;

    private final JdbcClient jdbcClient;
    private final StoryRowMapper storyRowMapper;
    private final StoryParticipantRowMapper storyParticipantRowMapper;

    public JdbcAccountDeletionRepository(
            JdbcClient jdbcClient,
            StoryRowMapper storyRowMapper
    ) {
        this.jdbcClient = Objects.requireNonNull(
                jdbcClient,
                "jdbcClient must not be null"
        );
        this.storyRowMapper = Objects.requireNonNull(
                storyRowMapper,
                "storyRowMapper must not be null"
        );
        this.storyParticipantRowMapper = new StoryParticipantRowMapper();
    }

    @Override
    public List<Story> findOwnedStoriesForUpdate(UUID ownerId) {
        Objects.requireNonNull(ownerId, "ownerId must not be null");

        return jdbcClient.sql(FIND_OWNED_STORIES_FOR_UPDATE_SQL)
                .param("ownerId", ownerId)
                .query(storyRowMapper)
                .list();
    }

    @Override
    public List<StoryParticipant> findParticipantsForStoriesForUpdate(
            Collection<UUID> storyIds
    ) {
        if (storyIds.isEmpty()) {
            return List.of();
        }

        return jdbcClient.sql(FIND_PARTICIPANTS_FOR_STORIES_FOR_UPDATE_SQL)
                .param("storyIds", storyIds)
                .query(storyParticipantRowMapper)
                .list();
    }

    @Override
    public List<StoryParticipant> findUserParticipationsForUpdate(
            UUID userId
    ) {
        Objects.requireNonNull(userId, "userId must not be null");

        return jdbcClient.sql(FIND_USER_PARTICIPATIONS_FOR_UPDATE_SQL)
                .param("userId", userId)
                .query(storyParticipantRowMapper)
                .list();
    }

    @Override
    public List<AccountDeletionMediaStorageKeys> findMediaStorageKeysByStoryIds(
            Collection<UUID> storyIds
    ) {
        if (storyIds.isEmpty()) {
            return List.of();
        }

        return jdbcClient.sql(FIND_MEDIA_STORAGE_KEYS_BY_STORY_IDS_SQL)
                .param("storyIds", storyIds)
                .query(this::mapMediaStorageKeys)
                .list();
    }

    @Override
    public void transferStoryOwner(
            UUID storyId,
            UUID newOwnerId,
            Instant updatedAt
    ) {
        int updatedRows = jdbcClient.sql(TRANSFER_STORY_OWNER_SQL)
                .param("storyId", storyId)
                .param("newOwnerId", newOwnerId)
                .param(
                        "updatedAt",
                        DatabaseTimestamps.toOffsetDateTime(updatedAt)
                )
                .update();

        if (updatedRows != 1) {
            throw new IllegalStateException(
                    "Story owner transfer affected no rows after locked lookup"
            );
        }
    }

    @Override
    public void updateParticipantRole(
            UUID storyId,
            UUID userId,
            StoryRole role
    ) {
        int updatedRows = jdbcClient.sql(UPDATE_PARTICIPANT_ROLE_SQL)
                .param("storyId", storyId)
                .param("userId", userId)
                .param("role", role.name())
                .update();

        if (updatedRows != 1) {
            throw new IllegalStateException(
                    "Participant role update affected no rows after locked lookup"
            );
        }
    }

    @Override
    public void deleteParticipant(UUID storyId, UUID userId) {
        jdbcClient.sql(DELETE_PARTICIPANT_SQL)
                .param("storyId", storyId)
                .param("userId", userId)
                .update();
    }

    @Override
    public int deleteInvitesByStoryIds(Collection<UUID> storyIds) {
        if (storyIds.isEmpty()) {
            return 0;
        }

        return jdbcClient.sql(DELETE_INVITES_BY_STORY_IDS_SQL)
                .param("storyIds", storyIds)
                .update();
    }

    @Override
    public int deleteUnusedInvitesCreatedBy(UUID userId) {
        return jdbcClient.sql(DELETE_UNUSED_INVITES_CREATED_BY_SQL)
                .param("userId", userId)
                .update();
    }

    @Override
    public int deleteMemoriesByStoryIds(Collection<UUID> storyIds) {
        if (storyIds.isEmpty()) {
            return 0;
        }

        return jdbcClient.sql(DELETE_MEMORIES_BY_STORY_IDS_SQL)
                .param("storyIds", storyIds)
                .update();
    }

    @Override
    public int deleteStoriesByIds(Collection<UUID> storyIds) {
        if (storyIds.isEmpty()) {
            return 0;
        }

        return jdbcClient.sql(DELETE_STORIES_BY_IDS_SQL)
                .param("storyIds", storyIds)
                .update();
    }

    private AccountDeletionMediaStorageKeys mapMediaStorageKeys(
            ResultSet rs,
            int rowNum
    ) throws SQLException {
        return new AccountDeletionMediaStorageKeys(
                rs.getString("thumbnail_storage_key"),
                rs.getString("display_storage_key")
        );
    }
}
