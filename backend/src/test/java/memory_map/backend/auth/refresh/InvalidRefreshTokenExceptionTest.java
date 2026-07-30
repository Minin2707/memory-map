package memory_map.backend.auth.refresh;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class InvalidRefreshTokenExceptionTest {

    @Test
    void shouldCreateExceptionWithMessage() {

        InvalidRefreshTokenException exception =
                new InvalidRefreshTokenException(
                        "Refresh token is invalid"
                );

        assertThat(exception)
                .hasMessage("Refresh token is invalid")
                .hasNoCause();
    }

    @Test
    void shouldCreateExceptionWithMessageAndCause() {

        RuntimeException cause = new RuntimeException("cause");

        InvalidRefreshTokenException exception =
                new InvalidRefreshTokenException(
                        "Refresh token is invalid",
                        cause
                );

        assertThat(exception)
                .hasMessage("Refresh token is invalid")
                .hasCause(cause);
    }
}
