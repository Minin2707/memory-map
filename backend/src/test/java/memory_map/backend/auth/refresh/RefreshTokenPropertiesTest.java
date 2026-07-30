package memory_map.backend.auth.refresh;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class RefreshTokenPropertiesTest {

    @Test
    void shouldAcceptThirtyDayTtl() {

        RefreshTokenProperties properties =
                new RefreshTokenProperties(Duration.ofDays(30));

        Set<ConstraintViolation<RefreshTokenProperties>> violations =
                validate(properties);

        assertThat(violations).isEmpty();
    }

    @Test
    void shouldRejectNullTtl() {

        RefreshTokenProperties properties =
                new RefreshTokenProperties(null);

        Set<ConstraintViolation<RefreshTokenProperties>> violations =
                validate(properties);

        assertThat(violations).hasSize(1);
        assertThat(violations)
                .singleElement()
                .extracting(violation -> violation.getPropertyPath().toString())
                .isEqualTo("ttl");
    }

    @Test
    void shouldRejectZeroTtl() {

        assertThatThrownBy(
                () -> new RefreshTokenProperties(Duration.ZERO)
        )
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("ttl must be positive");
    }

    @Test
    void shouldRejectNegativeTtl() {

        assertThatThrownBy(
                () -> new RefreshTokenProperties(Duration.ofSeconds(-1))
        )
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("ttl must be positive");
    }

    private static Set<ConstraintViolation<RefreshTokenProperties>> validate(
            RefreshTokenProperties properties
    ) {
        try (ValidatorFactory factory =
                     Validation.buildDefaultValidatorFactory()) {

            Validator validator = factory.getValidator();

            return validator.validate(properties);
        }
    }
}
