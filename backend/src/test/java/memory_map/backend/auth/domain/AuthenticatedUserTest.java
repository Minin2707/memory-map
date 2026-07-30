package memory_map.backend.auth.domain;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AuthenticatedUserTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");

    @Test
    void shouldCreateAuthenticatedUser() {

        AuthenticatedUser authenticatedUser =
                new AuthenticatedUser(USER_ID);

        assertThat(authenticatedUser.userId()).isEqualTo(USER_ID);
    }

    @Test
    void shouldRejectNullUserId() {

        assertThatThrownBy(() -> new AuthenticatedUser(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("userId must not be null");
    }
}
