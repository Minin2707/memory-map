package memory_map.backend.auth.jwt;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.time.Instant;
import java.util.UUID;

public interface AccessTokenService {

    String issueAccessToken(
            UUID userId,
            Instant issuedAt
    );

    AuthenticatedUser verifyAccessToken(String accessToken);

}
