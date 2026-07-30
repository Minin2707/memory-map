package memory_map.backend.auth.jwt;

import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public class NimbusAccessTokenIssuer implements AccessTokenIssuer {

    private final JwtEncoder jwtEncoder;
    private final JwtAuthProperties properties;

    public NimbusAccessTokenIssuer(
            JwtEncoder jwtEncoder,
            JwtAuthProperties properties
    ) {
        this.jwtEncoder = Objects.requireNonNull(jwtEncoder);
        this.properties = Objects.requireNonNull(properties);
    }

    @Override
    public String issue(
            UUID userId,
            Instant issuedAt
    ) {
        Objects.requireNonNull(userId, "userId must not be null");
        Objects.requireNonNull(issuedAt, "issuedAt must not be null");

        Instant expiresAt = issuedAt.plus(properties.accessTokenTtl());

        JwsHeader header = JwsHeader
                .with(MacAlgorithm.HS256)
                .build();

        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(properties.issuer())
                .subject(userId.toString())
                .issuedAt(issuedAt)
                .expiresAt(expiresAt)
                .build();

        Jwt jwt = jwtEncoder.encode(
                JwtEncoderParameters.from(
                        header,
                        claims
                )
        );

        return jwt.getTokenValue();
    }
}
