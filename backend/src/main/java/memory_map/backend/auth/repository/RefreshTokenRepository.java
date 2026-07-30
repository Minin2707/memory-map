package memory_map.backend.auth.repository;

import memory_map.backend.auth.domain.RefreshToken;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface RefreshTokenRepository {

    Optional<RefreshToken> findById(UUID id);

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    List<RefreshToken> findByUserId(UUID userId);

    void save(RefreshToken refreshToken);

    void update(RefreshToken refreshToken);

    boolean revokeIfActive(
            UUID id,
            Instant revokedAt
    );

    void delete(UUID id);

}
