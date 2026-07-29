package memory_map.backend.auth.repository;

import memory_map.backend.auth.domain.RefreshToken;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.UUID;

public class RefreshTokenRowMapper implements RowMapper<RefreshToken> {

    @Override
    public RefreshToken mapRow(ResultSet rs, int rowNum) throws SQLException {

        UUID id = rs.getObject("id", UUID.class);
        UUID userId = rs.getObject("user_id", UUID.class);
        String tokenHash = rs.getString("token_hash");
        OffsetDateTime createdAt = rs.getObject("created_at", OffsetDateTime.class);
        OffsetDateTime expiresAt = rs.getObject("expires_at", OffsetDateTime.class);
        OffsetDateTime revokedAt = rs.getObject("revoked_at", OffsetDateTime.class);
        Instant revokedAtInstant = revokedAt == null ? null : revokedAt.toInstant();

        return new RefreshToken(
                id,
                userId,
                tokenHash,
                createdAt.toInstant(),
                expiresAt.toInstant(),
                revokedAtInstant
        );
    }

}
