package memory_map.backend.auth.jwt;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtAuthPropertiesTest {

    private static final String ISSUER = "memory-map-backend";
    private static final Duration ACCESS_TOKEN_TTL = Duration.ofMinutes(15);
    private static final String SECRET_BASE64 =
            "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=";

    @Test
    void shouldAcceptValidProperties() {

        JwtAuthProperties properties = new JwtAuthProperties(
                ISSUER,
                ACCESS_TOKEN_TTL,
                SECRET_BASE64
        );

        Set<ConstraintViolation<JwtAuthProperties>> violations =
                validate(properties);

        assertThat(violations).isEmpty();
    }

    @Test
    void shouldRejectNullIssuer() {

        JwtAuthProperties properties = new JwtAuthProperties(
                null,
                ACCESS_TOKEN_TTL,
                SECRET_BASE64
        );

        assertSingleViolation(properties, "issuer");
    }

    @Test
    void shouldRejectEmptyIssuer() {

        JwtAuthProperties properties = new JwtAuthProperties(
                "",
                ACCESS_TOKEN_TTL,
                SECRET_BASE64
        );

        assertSingleViolation(properties, "issuer");
    }

    @Test
    void shouldRejectWhitespaceIssuer() {

        JwtAuthProperties properties = new JwtAuthProperties(
                "   ",
                ACCESS_TOKEN_TTL,
                SECRET_BASE64
        );

        assertSingleViolation(properties, "issuer");
    }

    @Test
    void shouldRejectNullAccessTokenTtl() {

        JwtAuthProperties properties = new JwtAuthProperties(
                ISSUER,
                null,
                SECRET_BASE64
        );

        assertSingleViolation(properties, "accessTokenTtl");
    }

    @Test
    void shouldRejectZeroAccessTokenTtl() {

        assertThatThrownBy(() -> new JwtAuthProperties(
                ISSUER,
                Duration.ZERO,
                SECRET_BASE64
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("accessTokenTtl must be positive");
    }

    @Test
    void shouldRejectNegativeAccessTokenTtl() {

        assertThatThrownBy(() -> new JwtAuthProperties(
                ISSUER,
                Duration.ofSeconds(-1),
                SECRET_BASE64
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("accessTokenTtl must be positive");
    }

    @Test
    void shouldRejectNullSecretBase64() {

        JwtAuthProperties properties = new JwtAuthProperties(
                ISSUER,
                ACCESS_TOKEN_TTL,
                null
        );

        assertSingleViolation(properties, "secretBase64");
    }

    @Test
    void shouldRejectEmptySecretBase64() {

        JwtAuthProperties properties = new JwtAuthProperties(
                ISSUER,
                ACCESS_TOKEN_TTL,
                ""
        );

        assertSingleViolation(properties, "secretBase64");
    }

    @Test
    void shouldRejectWhitespaceSecretBase64() {

        JwtAuthProperties properties = new JwtAuthProperties(
                ISSUER,
                ACCESS_TOKEN_TTL,
                "   "
        );

        assertSingleViolation(properties, "secretBase64");
    }

    private static Set<ConstraintViolation<JwtAuthProperties>> validate(
            JwtAuthProperties properties
    ) {
        try (ValidatorFactory factory =
                     Validation.buildDefaultValidatorFactory()) {

            Validator validator = factory.getValidator();

            return validator.validate(properties);
        }
    }

    private static void assertSingleViolation(
            JwtAuthProperties properties,
            String propertyPath
    ) {
        Set<ConstraintViolation<JwtAuthProperties>> violations =
                validate(properties);

        assertThat(violations).hasSize(1);
        assertThat(violations)
                .singleElement()
                .extracting(violation -> violation.getPropertyPath().toString())
                .isEqualTo(propertyPath);
    }
}
