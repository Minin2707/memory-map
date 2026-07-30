package memory_map.backend.auth.google;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.Test;

import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

class GoogleAuthPropertiesTest {

    @Test
    void shouldAcceptNonBlankClientId() {

        GoogleAuthProperties properties = new GoogleAuthProperties(
                "google-client-id.apps.googleusercontent.com"
        );

        Set<ConstraintViolation<GoogleAuthProperties>> violations =
                validate(properties);

        assertThat(violations).isEmpty();
    }

    @Test
    void shouldRejectNullClientId() {

        GoogleAuthProperties properties = new GoogleAuthProperties(null);

        assertSingleClientIdViolation(properties);
    }

    @Test
    void shouldRejectEmptyClientId() {

        GoogleAuthProperties properties = new GoogleAuthProperties("");

        assertSingleClientIdViolation(properties);
    }

    @Test
    void shouldRejectWhitespaceClientId() {

        GoogleAuthProperties properties = new GoogleAuthProperties("   ");

        assertSingleClientIdViolation(properties);
    }

    private static Set<ConstraintViolation<GoogleAuthProperties>> validate(
            GoogleAuthProperties properties
    ) {
        try (ValidatorFactory factory =
                     Validation.buildDefaultValidatorFactory()) {

            Validator validator = factory.getValidator();

            return validator.validate(properties);
        }
    }

    private static void assertSingleClientIdViolation(
            GoogleAuthProperties properties
    ) {
        Set<ConstraintViolation<GoogleAuthProperties>> violations =
                validate(properties);

        assertThat(violations).hasSize(1);
        assertThat(violations)
                .singleElement()
                .extracting(violation -> violation.getPropertyPath().toString())
                .isEqualTo("clientId");
    }
}
