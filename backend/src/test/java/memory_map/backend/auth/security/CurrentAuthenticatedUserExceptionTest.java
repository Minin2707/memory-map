package memory_map.backend.auth.security;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class CurrentAuthenticatedUserExceptionTest {

    private static final String MESSAGE =
            "Authenticated user is unavailable";

    @Test
    void shouldCreateExceptionWithMessage() {

        CurrentAuthenticatedUserException exception =
                new CurrentAuthenticatedUserException(MESSAGE);

        assertThat(exception).hasMessage(MESSAGE);
    }

    @Test
    void shouldCreateExceptionWithMessageAndCause() {

        IllegalArgumentException cause =
                new IllegalArgumentException("invalid subject");

        CurrentAuthenticatedUserException exception =
                new CurrentAuthenticatedUserException(
                        MESSAGE,
                        cause
                );

        assertThat(exception).hasMessage(MESSAGE);
        assertThat(exception).hasCause(cause);
    }
}
