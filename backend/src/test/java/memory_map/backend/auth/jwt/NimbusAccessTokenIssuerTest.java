package memory_map.backend.auth.jwt;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jwt.SignedJWT;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;

import javax.crypto.SecretKey;
import java.text.ParseException;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class NimbusAccessTokenIssuerTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final Instant ISSUED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Duration ACCESS_TOKEN_TTL =
            Duration.ofMinutes(15);
    private static final String ISSUER = "memory-map-backend";
    private static final String SECRET_BASE64 =
            "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=";

    @Test
    void shouldIssueAccessTokenWithExpectedSubject() throws Exception {

        SignedJWT token = issueParsedToken();

        assertThat(token.getJWTClaimsSet().getSubject())
                .isEqualTo(USER_ID.toString());
    }

    @Test
    void shouldSetConfiguredIssuer() throws Exception {

        SignedJWT token = issueParsedToken();

        assertThat(token.getJWTClaimsSet().getIssuer())
                .isEqualTo(ISSUER);
    }

    @Test
    void shouldSetIssuedAt() throws Exception {

        SignedJWT token = issueParsedToken();

        assertThat(token.getJWTClaimsSet().getIssueTime().toInstant())
                .isEqualTo(ISSUED_AT);
    }

    @Test
    void shouldSetExpirationFromConfiguredTtl() throws Exception {

        SignedJWT token = issueParsedToken();

        assertThat(token.getJWTClaimsSet().getExpirationTime().toInstant())
                .isEqualTo(ISSUED_AT.plus(ACCESS_TOKEN_TTL));
    }

    @Test
    void shouldUseHs256Algorithm() throws Exception {

        SignedJWT token = issueParsedToken();

        assertThat(token.getHeader().getAlgorithm())
                .isEqualTo(JWSAlgorithm.HS256);
    }

    @Test
    void shouldNotIncludeUnexpectedClaims() throws Exception {

        SignedJWT token = issueParsedToken();
        Map<String, Object> claims = token.getJWTClaimsSet().getClaims();

        assertThat(claims)
                .doesNotContainKeys(
                        "jti",
                        "aud",
                        "roles",
                        "permissions",
                        "email",
                        "displayName",
                        "avatarUrl",
                        "googleSubject",
                        "refreshTokenId"
                );
    }

    @Test
    void shouldRejectNullUserId() {

        NimbusAccessTokenIssuer issuer = accessTokenIssuer();

        assertThatThrownBy(() -> issuer.issue(null, ISSUED_AT))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("userId must not be null");
    }

    @Test
    void shouldRejectNullIssuedAt() {

        NimbusAccessTokenIssuer issuer = accessTokenIssuer();

        assertThatThrownBy(() -> issuer.issue(USER_ID, null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("issuedAt must not be null");
    }

    private static SignedJWT issueParsedToken() throws ParseException {
        String token = accessTokenIssuer().issue(USER_ID, ISSUED_AT);

        return SignedJWT.parse(token);
    }

    private static NimbusAccessTokenIssuer accessTokenIssuer() {
        SecretKey secretKey = JwtSecretKeyFactory.create(SECRET_BASE64);

        return new NimbusAccessTokenIssuer(
                NimbusJwtEncoder
                        .withSecretKey(secretKey)
                        .algorithm(MacAlgorithm.HS256)
                        .build(),
                jwtAuthProperties()
        );
    }

    private static JwtAuthProperties jwtAuthProperties() {
        return new JwtAuthProperties(
                ISSUER,
                ACCESS_TOKEN_TTL,
                SECRET_BASE64
        );
    }
}
