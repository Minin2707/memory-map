package memory_map.backend.auth.refresh;

import memory_map.backend.auth.domain.RefreshToken;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public class DefaultRefreshTokenIssuer implements RefreshTokenIssuer {

    private final RawRefreshTokenGenerator rawTokenGenerator;
    private final RefreshTokenHasher tokenHasher;
    private final RefreshTokenProperties properties;

    public DefaultRefreshTokenIssuer(
            RawRefreshTokenGenerator rawTokenGenerator,
            RefreshTokenHasher tokenHasher,
            RefreshTokenProperties properties
    ) {
        this.rawTokenGenerator = Objects.requireNonNull(
                rawTokenGenerator,
                "rawTokenGenerator must not be null"
        );
        this.tokenHasher = Objects.requireNonNull(
                tokenHasher,
                "tokenHasher must not be null"
        );
        this.properties = Objects.requireNonNull(
                properties,
                "properties must not be null"
        );
    }

    @Override
    public IssuedRefreshToken issue(
            UUID tokenId,
            UUID userId,
            Instant issuedAt
    ) {
        Objects.requireNonNull(
                tokenId,
                "tokenId must not be null"
        );
        Objects.requireNonNull(
                userId,
                "userId must not be null"
        );
        Objects.requireNonNull(
                issuedAt,
                "issuedAt must not be null"
        );

        RawRefreshToken rawToken =
                rawTokenGenerator.generate();
        String tokenHash =
                tokenHasher.hash(rawToken);
        Instant expiresAt =
                issuedAt.plus(properties.ttl());

        RefreshToken refreshToken = new RefreshToken(
                tokenId,
                userId,
                tokenHash,
                issuedAt,
                expiresAt,
                null
        );

        return new IssuedRefreshToken(
                rawToken,
                refreshToken
        );
    }
}
