package memory_map.backend.auth.api;

import memory_map.backend.user.domain.User;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class AuthUserResponseTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final Instant NOW =
            Instant.parse("2026-01-10T10:00:00Z");

    @Test
    void shouldUseGoogleAvatarWhenCustomAvatarIsAbsent() {
        AuthUserResponse response = AuthUserResponse.from(new User(
                USER_ID,
                "google-subject-123",
                "Ada Lovelace",
                "https://example.com/avatar.png",
                NOW,
                NOW
        ));

        assertThat(response.avatarUrl())
                .isEqualTo("https://example.com/avatar.png");
        assertThat(response.hasCustomAvatar()).isFalse();
    }

    @Test
    void shouldUseVersionedCurrentUserAvatarPathWhenCustomAvatarExists() {
        AuthUserResponse response = AuthUserResponse.from(new User(
                USER_ID,
                "google-subject-123",
                "Ada Lovelace",
                "https://example.com/avatar.png",
                "users/%s/avatar/avatar-object".formatted(USER_ID),
                NOW,
                NOW,
                NOW,
                null
        ));

        assertThat(response.avatarUrl())
                .isEqualTo("/api/v1/me/avatar/1768039200000");
        assertThat(response.hasCustomAvatar()).isTrue();
    }
}
