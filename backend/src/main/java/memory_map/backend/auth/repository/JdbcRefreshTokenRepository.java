package memory_map.backend.auth.repository;

import memory_map.backend.auth.domain.RefreshToken;
import memory_map.backend.common.database.DatabaseTimestamps;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class JdbcRefreshTokenRepository implements RefreshTokenRepository {

    private static final String SELECT_COLUMNS_SQL = """
            SELECT
                id,
                user_id,
                token_hash,
                created_at,
                expires_at,
                revoked_at
            FROM refresh_tokens
            """;

    private static final String FIND_BY_ID_SQL = SELECT_COLUMNS_SQL + """
            WHERE id = :id
            """;

    private static final String FIND_BY_TOKEN_HASH_SQL = SELECT_COLUMNS_SQL + """
            WHERE token_hash = :tokenHash
            """;

    private static final String FIND_BY_USER_ID_SQL = SELECT_COLUMNS_SQL + """
            WHERE user_id = :userId
            ORDER BY created_at ASC, id ASC
            """;

    private static final String INSERT_SQL = """
            INSERT INTO refresh_tokens (
                id,
                user_id,
                token_hash,
                created_at,
                expires_at,
                revoked_at
            )
            VALUES (
                :id,
                :userId,
                :tokenHash,
                :createdAt,
                :expiresAt,
                :revokedAt
            )
            """;

    private static final String UPDATE_SQL = """
            UPDATE refresh_tokens
            SET revoked_at = :revokedAt
            WHERE id = :id
            """;

    private static final String DELETE_SQL = """
            DELETE FROM refresh_tokens
            WHERE id = :id
            """;

    private final JdbcClient jdbcClient;
    private final RefreshTokenRowMapper rowMapper;

    public JdbcRefreshTokenRepository(JdbcClient jdbcClient) {
        this.jdbcClient = jdbcClient;
        this.rowMapper = new RefreshTokenRowMapper();
    }

    @Override
    public Optional<RefreshToken> findById(UUID id) {

        return jdbcClient.sql(FIND_BY_ID_SQL)
                .param("id", id)
                .query(rowMapper)
                .optional();
    }

    @Override
    public Optional<RefreshToken> findByTokenHash(String tokenHash) {

        return jdbcClient.sql(FIND_BY_TOKEN_HASH_SQL)
                .param("tokenHash", tokenHash)
                .query(rowMapper)
                .optional();
    }

    @Override
    public List<RefreshToken> findByUserId(UUID userId) {

        return jdbcClient.sql(FIND_BY_USER_ID_SQL)
                .param("userId", userId)
                .query(rowMapper)
                .list();
    }

    @Override
    public void save(RefreshToken refreshToken) {

        jdbcClient.sql(INSERT_SQL)
                .param("id", refreshToken.id())
                .param("userId", refreshToken.userId())
                .param("tokenHash", refreshToken.tokenHash())
                .param("createdAt", DatabaseTimestamps.toOffsetDateTime(refreshToken.createdAt()))
                .param("expiresAt", DatabaseTimestamps.toOffsetDateTime(refreshToken.expiresAt()))
                .param(
                        "revokedAt",
                        refreshToken.revokedAt() == null
                                ? null
                                : DatabaseTimestamps.toOffsetDateTime(refreshToken.revokedAt())
                )
                .update();
    }

    @Override
    public void update(RefreshToken refreshToken) {

        jdbcClient.sql(UPDATE_SQL)
                .param("id", refreshToken.id())
                .param(
                        "revokedAt",
                        refreshToken.revokedAt() == null
                                ? null
                                : DatabaseTimestamps.toOffsetDateTime(refreshToken.revokedAt())
                )
                .update();
    }

    @Override
    public void delete(UUID id) {

        jdbcClient.sql(DELETE_SQL)
                .param("id", id)
                .update();
    }

}
