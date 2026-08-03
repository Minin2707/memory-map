package memory_map.backend.invite.application;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.Test;

import java.net.URI;
import java.time.Duration;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class InvitePropertiesTest {

    @Test
    void shouldAcceptDefaultThirtyDayTtlAndHttpsBaseUrl() {

        InviteProperties properties = new InviteProperties(
                Duration.ofDays(30),
                URI.create("https://app.memorymap.app")
        );

        Set<ConstraintViolation<InviteProperties>> violations =
                validate(properties);

        assertThat(violations).isEmpty();
        assertThat(properties.ttl()).isEqualTo(Duration.ofDays(30));
        assertThat(properties.baseUrl())
                .isEqualTo(URI.create("https://app.memorymap.app"));
    }

    @Test
    void shouldAcceptPositiveCustomTtl() {

        InviteProperties properties = new InviteProperties(
                Duration.ofHours(12),
                URI.create("https://app.memorymap.app")
        );

        assertThat(properties.ttl()).isEqualTo(Duration.ofHours(12));
    }

    @Test
    void shouldNormalizeTrailingSlashBaseUrl() {

        InviteProperties properties = new InviteProperties(
                Duration.ofDays(30),
                URI.create("https://app.memorymap.app/")
        );

        assertThat(properties.baseUrl())
                .isEqualTo(URI.create("https://app.memorymap.app"));
    }

    @Test
    void shouldAllowLocalHttpBaseUrl() {

        InviteProperties properties = new InviteProperties(
                Duration.ofDays(30),
                URI.create("http://localhost:8080")
        );

        assertThat(properties.baseUrl())
                .isEqualTo(URI.create("http://localhost:8080"));
    }

    @Test
    void shouldRejectNullTtlThroughBeanValidation() {

        InviteProperties properties = new InviteProperties(
                null,
                URI.create("https://app.memorymap.app")
        );

        Set<ConstraintViolation<InviteProperties>> violations =
                validate(properties);

        assertThat(violations).hasSize(1);
        assertThat(violations)
                .singleElement()
                .extracting(violation -> violation.getPropertyPath().toString())
                .isEqualTo("ttl");
    }

    @Test
    void shouldRejectZeroTtl() {

        assertThatThrownBy(() -> new InviteProperties(
                Duration.ZERO,
                URI.create("https://app.memorymap.app")
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("ttl must be positive");
    }

    @Test
    void shouldRejectNegativeTtl() {

        assertThatThrownBy(() -> new InviteProperties(
                Duration.ofSeconds(-1),
                URI.create("https://app.memorymap.app")
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("ttl must be positive");
    }

    @Test
    void shouldRejectNullBaseUrlThroughBeanValidation() {

        InviteProperties properties = new InviteProperties(
                Duration.ofDays(30),
                null
        );

        Set<ConstraintViolation<InviteProperties>> violations =
                validate(properties);

        assertThat(violations).hasSize(1);
        assertThat(violations)
                .singleElement()
                .extracting(violation -> violation.getPropertyPath().toString())
                .isEqualTo("baseUrl");
    }

    @Test
    void shouldRejectRelativeBaseUrl() {

        assertThatThrownBy(() -> new InviteProperties(
                Duration.ofDays(30),
                URI.create("/invite")
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("baseUrl must be absolute");
    }

    @Test
    void shouldRejectMissingHost() {

        assertThatThrownBy(() -> new InviteProperties(
                Duration.ofDays(30),
                URI.create("https:/invite")
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("baseUrl host must not be null");
    }

    @Test
    void shouldRejectDisallowedScheme() {

        assertThatThrownBy(() -> new InviteProperties(
                Duration.ofDays(30),
                URI.create("ftp://app.memorymap.app")
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("baseUrl scheme must be http or https");
    }

    @Test
    void shouldRejectQuery() {

        assertThatThrownBy(() -> new InviteProperties(
                Duration.ofDays(30),
                URI.create("https://app.memorymap.app?token=value")
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("baseUrl query must not be present");
    }

    @Test
    void shouldRejectFragment() {

        assertThatThrownBy(() -> new InviteProperties(
                Duration.ofDays(30),
                URI.create("https://app.memorymap.app#invite")
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("baseUrl fragment must not be present");
    }

    @Test
    void shouldRejectUserInfo() {

        assertThatThrownBy(() -> new InviteProperties(
                Duration.ofDays(30),
                URI.create("https://user@app.memorymap.app")
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("baseUrl user info must not be present");
    }

    @Test
    void shouldRejectPathPrefix() {

        assertThatThrownBy(() -> new InviteProperties(
                Duration.ofDays(30),
                URI.create("https://app.memorymap.app/app")
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("baseUrl path must not be present");
    }

    @Test
    void shouldHaveSafeToString() {

        InviteProperties properties = new InviteProperties(
                Duration.ofDays(30),
                URI.create("https://app.memorymap.app")
        );

        assertThat(properties.toString())
                .contains(properties.ttl().toString())
                .contains("https://app.memorymap.app")
                .doesNotContain("token")
                .doesNotContain("hash");
    }

    private static Set<ConstraintViolation<InviteProperties>> validate(
            InviteProperties properties
    ) {
        try (ValidatorFactory factory =
                     Validation.buildDefaultValidatorFactory()) {

            Validator validator = factory.getValidator();

            return validator.validate(properties);
        }
    }
}
