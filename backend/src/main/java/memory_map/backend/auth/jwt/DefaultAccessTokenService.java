package memory_map.backend.auth.jwt;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public class DefaultAccessTokenService implements AccessTokenService {

    private final AccessTokenIssuer accessTokenIssuer;
    private final AccessTokenVerifier accessTokenVerifier;

    public DefaultAccessTokenService(
            AccessTokenIssuer accessTokenIssuer,
            AccessTokenVerifier accessTokenVerifier
    ) {
        this.accessTokenIssuer = Objects.requireNonNull(accessTokenIssuer);
        this.accessTokenVerifier = Objects.requireNonNull(accessTokenVerifier);
    }

    @Override
    public String issueAccessToken(
            UUID userId,
            Instant issuedAt
    ) {
        return accessTokenIssuer.issue(userId, issuedAt);
    }

    @Override
    public AuthenticatedUser verifyAccessToken(String accessToken) {
        return accessTokenVerifier.verify(accessToken);
    }
}
