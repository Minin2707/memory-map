package memory_map.backend.auth.jwt;

import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.JOSEObjectType;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.MACSigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import memory_map.backend.auth.domain.AuthenticatedUser;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwtIssuerValidator;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Base64;
import java.util.Date;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class NimbusAccessTokenVerifierTest {

    private static final String FAILURE_MESSAGE =
            "Access token verification failed";
    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final String ISSUER = "memory-map-backend";
    private static final String OTHER_ISSUER = "other-issuer";
    private static final Duration ACCESS_TOKEN_TTL =
            Duration.ofMinutes(15);
    private static final Instant ISSUED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant VERIFICATION_TIME =
            Instant.parse("2026-01-01T10:05:00Z");
    private static final String SECRET_BASE64 =
            "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=";
    private static final String OTHER_SECRET_BASE64 =
            "ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA=";
    private static final String LONG_SECRET_BASE64 =
            "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWYwMTIzNDU2Nzg5YWJjZGVmMDEyMzQ1Njc4OWFiY2RlZg==";

    @Test
    void shouldVerifyValidAccessToken() {

        String token = validToken();
        NimbusAccessTokenVerifier verifier = verifier();

        AuthenticatedUser authenticatedUser = verifier.verify(token);

        assertThat(authenticatedUser.userId()).isEqualTo(USER_ID);
    }

    @Test
    void shouldRejectNullToken() {

        assertVerificationFailure(() -> verifier().verify(null), null);
    }

    @Test
    void shouldRejectEmptyToken() {

        assertVerificationFailure(() -> verifier().verify(""), "");
    }

    @Test
    void shouldRejectWhitespaceToken() {

        assertVerificationFailure(() -> verifier().verify("   "), "   ");
    }

    @Test
    void shouldRejectMalformedToken() {

        assertVerificationFailureWithCause(
                () -> verifier().verify("malformed-token"),
                "malformed-token"
        );
    }

    @Test
    void shouldRejectTokenSignedWithDifferentSecret() {

        String token = issueToken(
                OTHER_SECRET_BASE64,
                MacAlgorithm.HS256,
                validClaims(ISSUER)
        );

        assertVerificationFailureWithCause(
                () -> verifier().verify(token),
                token
        );
    }

    @Test
    void shouldRejectTokenUsingDifferentAlgorithm() {

        String token = issueToken(
                LONG_SECRET_BASE64,
                MacAlgorithm.HS512,
                validClaims(ISSUER)
        );

        assertVerificationFailureWithCause(
                () -> verifier(LONG_SECRET_BASE64).verify(token),
                token
        );
    }

    @Test
    void shouldRejectWrongIssuer() {

        String token = issueToken(
                SECRET_BASE64,
                MacAlgorithm.HS256,
                validClaims(OTHER_ISSUER)
        );

        assertVerificationFailureWithCause(
                () -> verifier().verify(token),
                token
        );
    }

    @Test
    void shouldRejectExpiredToken() {

        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(ISSUER)
                .subject(USER_ID.toString())
                .issuedAt(Instant.parse("2025-12-31T09:45:00Z"))
                .expiresAt(Instant.parse("2025-12-31T10:00:00Z"))
                .build();
        String token = issueToken(SECRET_BASE64, MacAlgorithm.HS256, claims);

        assertVerificationFailureWithCause(
                () -> verifier().verify(token),
                token
        );
    }

    @Test
    void shouldRejectTokenWithoutExpiration() {

        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(ISSUER)
                .subject(USER_ID.toString())
                .issuedAt(ISSUED_AT)
                .build();
        String token = issueToken(SECRET_BASE64, MacAlgorithm.HS256, claims);

        assertVerificationFailureWithCause(
                () -> verifier().verify(token),
                token
        );
    }

    @Test
    void shouldRejectTokenWithoutIssuedAt() throws JOSEException {

        String token = issueTokenWithoutIssuedAt();

        assertVerificationFailureWithCause(
                () -> verifier().verify(token),
                token
        );
    }

    @Test
    void shouldRejectTokenWithoutSubject() {

        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(ISSUER)
                .issuedAt(ISSUED_AT)
                .expiresAt(ISSUED_AT.plus(ACCESS_TOKEN_TTL))
                .build();
        String token = issueToken(SECRET_BASE64, MacAlgorithm.HS256, claims);

        assertVerificationFailure(
                () -> verifier().verify(token),
                token
        );
    }

    @Test
    void shouldRejectTokenWithBlankSubject() {

        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(ISSUER)
                .subject("   ")
                .issuedAt(ISSUED_AT)
                .expiresAt(ISSUED_AT.plus(ACCESS_TOKEN_TTL))
                .build();
        String token = issueToken(SECRET_BASE64, MacAlgorithm.HS256, claims);

        assertVerificationFailure(
                () -> verifier().verify(token),
                token
        );
    }

    @Test
    void shouldRejectTokenWithNonUuidSubject() {

        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(ISSUER)
                .subject("not-a-uuid")
                .issuedAt(ISSUED_AT)
                .expiresAt(ISSUED_AT.plus(ACCESS_TOKEN_TTL))
                .build();
        String token = issueToken(SECRET_BASE64, MacAlgorithm.HS256, claims);

        assertVerificationFailureWithCause(
                () -> verifier().verify(token),
                token
        );
    }

    private static String validToken() {
        return new NimbusAccessTokenIssuer(
                jwtEncoder(SECRET_BASE64, MacAlgorithm.HS256),
                jwtAuthProperties(ISSUER)
        )
                .issue(USER_ID, ISSUED_AT);
    }

    private static JwtClaimsSet validClaims(String issuer) {
        return JwtClaimsSet.builder()
                .issuer(issuer)
                .subject(USER_ID.toString())
                .issuedAt(ISSUED_AT)
                .expiresAt(ISSUED_AT.plus(ACCESS_TOKEN_TTL))
                .build();
    }

    private static String issueToken(
            String secretBase64,
            MacAlgorithm algorithm,
            JwtClaimsSet claims
    ) {
        JwsHeader header = JwsHeader
                .with(algorithm)
                .build();

        return jwtEncoder(secretBase64, algorithm)
                .encode(JwtEncoderParameters.from(header, claims))
                .getTokenValue();
    }

    private static String issueTokenWithoutIssuedAt()
            throws JOSEException {
        JWSHeader header = new JWSHeader.Builder(JWSAlgorithm.HS256)
                .type(JOSEObjectType.JWT)
                .build();
        JWTClaimsSet claims = new JWTClaimsSet.Builder()
                .issuer(ISSUER)
                .subject(USER_ID.toString())
                .expirationTime(Date.from(ISSUED_AT.plus(ACCESS_TOKEN_TTL)))
                .build();
        SignedJWT jwt = new SignedJWT(header, claims);

        jwt.sign(new MACSigner(JwtSecretKeyFactory
                .create(SECRET_BASE64)
                .getEncoded()));

        return jwt.serialize();
    }

    private static NimbusAccessTokenVerifier verifier() {
        return verifier(SECRET_BASE64);
    }

    private static NimbusAccessTokenVerifier verifier(String secretBase64) {
        return new NimbusAccessTokenVerifier(
                jwtDecoder(secretBase64, ISSUER)
        );
    }

    private static JwtEncoder jwtEncoder(
            String secretBase64,
            MacAlgorithm algorithm
    ) {
        SecretKey secretKey = secretKey(secretBase64, algorithm);

        return NimbusJwtEncoder
                .withSecretKey(secretKey)
                .algorithm(algorithm)
                .build();
    }

    private static SecretKey secretKey(
            String secretBase64,
            MacAlgorithm algorithm
    ) {
        if (MacAlgorithm.HS512.equals(algorithm)) {
            return new SecretKeySpec(
                    Base64.getDecoder().decode(secretBase64),
                    "HmacSHA512"
            );
        }

        return JwtSecretKeyFactory.create(secretBase64);
    }

    private static JwtDecoder jwtDecoder(
            String secretBase64,
            String issuer
    ) {
        SecretKey secretKey = JwtSecretKeyFactory.create(secretBase64);
        NimbusJwtDecoder jwtDecoder = NimbusJwtDecoder
                .withSecretKey(secretKey)
                .macAlgorithm(MacAlgorithm.HS256)
                .build();

        JwtTimestampValidator timestampValidator =
                new JwtTimestampValidator();
        timestampValidator.setClock(
                Clock.fixed(
                        VERIFICATION_TIME,
                        ZoneOffset.UTC
                )
        );
        timestampValidator.setAllowEmptyExpiryClaim(false);

        OAuth2TokenValidator<Jwt> validator =
                new DelegatingOAuth2TokenValidator<>(
                        timestampValidator,
                        new JwtIssuerValidator(issuer),
                        new JwtIssuedAtValidator()
                );

        jwtDecoder.setJwtValidator(validator);

        return jwtDecoder;
    }

    private static JwtAuthProperties jwtAuthProperties(String issuer) {
        return new JwtAuthProperties(
                issuer,
                ACCESS_TOKEN_TTL,
                SECRET_BASE64
        );
    }

    private static void assertVerificationFailure(
            ThrowingAction action,
            String rawToken
    ) {
        assertThatThrownBy(action::run)
                .isInstanceOf(AccessTokenVerificationException.class)
                .hasMessage(FAILURE_MESSAGE)
                .satisfies(throwable -> assertSafeMessage(
                        throwable,
                        rawToken
                ));
    }

    private static void assertVerificationFailureWithCause(
            ThrowingAction action,
            String rawToken
    ) {
        assertThatThrownBy(action::run)
                .isInstanceOf(AccessTokenVerificationException.class)
                .hasMessage(FAILURE_MESSAGE)
                .hasCauseInstanceOf(Throwable.class)
                .satisfies(throwable -> assertSafeMessage(
                        throwable,
                        rawToken
                ));
    }

    private static void assertSafeMessage(
            Throwable throwable,
            String rawToken
    ) {
        if (rawToken != null && !rawToken.isEmpty()) {
            assertThat(throwable.getMessage()).doesNotContain(rawToken);
        }
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();

    }
}
