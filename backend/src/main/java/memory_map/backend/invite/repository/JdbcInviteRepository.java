package memory_map.backend.invite.repository;

import memory_map.backend.common.database.DatabaseTimestamps;
import memory_map.backend.invite.domain.Invite;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

@Repository
public class JdbcInviteRepository implements InviteRepository {

    private static final String SELECT_COLUMNS_SQL = """
            SELECT
                id,
                story_id,
                role,
                token_hash,
                created_by,
                created_at,
                expires_at,
                used_at
            FROM invites
            """;

    private static final String FIND_BY_ID_SQL = SELECT_COLUMNS_SQL + """
            WHERE id = :id
            """;

    private static final String FIND_BY_TOKEN_HASH_SQL = SELECT_COLUMNS_SQL + """
            WHERE token_hash = :tokenHash
            """;

    private static final String FIND_BY_TOKEN_HASH_FOR_UPDATE_SQL =
            SELECT_COLUMNS_SQL + """
            WHERE token_hash = :tokenHash
            FOR UPDATE
            """;

    private static final String FIND_BY_STORY_ID_SQL = SELECT_COLUMNS_SQL + """
            WHERE story_id = :storyId
            ORDER BY created_at ASC, id ASC
            """;

    private static final String INSERT_SQL = """
            INSERT INTO invites (
                id,
                story_id,
                role,
                token_hash,
                created_by,
                created_at,
                expires_at,
                used_at
            )
            VALUES (
                :id,
                :storyId,
                :role,
                :tokenHash,
                :createdBy,
                :createdAt,
                :expiresAt,
                :usedAt
            )
            """;

    private static final String MARK_USED_IF_UNUSED_SQL = """
            UPDATE invites
            SET used_at = :usedAt
            WHERE id = :id
              AND used_at IS NULL
            """;

    private static final String DELETE_SQL = """
            DELETE FROM invites
            WHERE id = :id
            """;

    private final JdbcClient jdbcClient;
    private final InviteRowMapper rowMapper;

    public JdbcInviteRepository(JdbcClient jdbcClient) {
        this.jdbcClient = jdbcClient;
        this.rowMapper = new InviteRowMapper();
    }

    @Override
    public Optional<Invite> findById(UUID id) {

        return jdbcClient.sql(FIND_BY_ID_SQL)
                .param("id", id)
                .query(rowMapper)
                .optional();
    }

    @Override
    public Optional<Invite> findByTokenHash(String tokenHash) {

        Objects.requireNonNull(tokenHash, "tokenHash must not be null");

        return jdbcClient.sql(FIND_BY_TOKEN_HASH_SQL)
                .param("tokenHash", tokenHash)
                .query(rowMapper)
                .optional();
    }

    @Override
    public Optional<Invite> findByTokenHashForUpdate(String tokenHash) {

        Objects.requireNonNull(tokenHash, "tokenHash must not be null");

        return jdbcClient.sql(FIND_BY_TOKEN_HASH_FOR_UPDATE_SQL)
                .param("tokenHash", tokenHash)
                .query(rowMapper)
                .optional();
    }

    @Override
    public List<Invite> findByStoryId(UUID storyId) {

        return jdbcClient.sql(FIND_BY_STORY_ID_SQL)
                .param("storyId", storyId)
                .query(rowMapper)
                .list();
    }

    @Override
    public void save(Invite invite) {

        jdbcClient.sql(INSERT_SQL)
                .param("id", invite.id())
                .param("storyId", invite.storyId())
                .param("role", invite.role().name())
                .param("tokenHash", invite.tokenHash())
                .param("createdBy", invite.createdBy())
                .param("createdAt", DatabaseTimestamps.toOffsetDateTime(invite.createdAt()))
                .param("expiresAt", DatabaseTimestamps.toOffsetDateTime(invite.expiresAt()))
                .param(
                        "usedAt",
                        invite.usedAt() == null
                                ? null
                                : DatabaseTimestamps.toOffsetDateTime(invite.usedAt())
                )
                .update();
    }

    @Override
    public boolean markUsedIfUnused(
            UUID inviteId,
            Instant usedAt
    ) {

        Objects.requireNonNull(inviteId, "inviteId must not be null");
        Objects.requireNonNull(usedAt, "usedAt must not be null");

        int updatedRows = jdbcClient.sql(MARK_USED_IF_UNUSED_SQL)
                .param("id", inviteId)
                .param(
                        "usedAt",
                        DatabaseTimestamps.toOffsetDateTime(usedAt)
                )
                .update();

        return updatedRows == 1;
    }

    @Override
    public void delete(UUID id) {

        jdbcClient.sql(DELETE_SQL)
                .param("id", id)
                .update();
    }

}
