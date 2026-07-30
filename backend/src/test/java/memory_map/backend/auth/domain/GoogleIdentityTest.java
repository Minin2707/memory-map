package memory_map.backend.auth.domain;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class GoogleIdentityTest {

    @Test
    void shouldCreateGoogleIdentityWhenSubjectIsValid() {

        GoogleIdentity identity = new GoogleIdentity(
                "google-subject-123",
                "Konstantin",
                "https://example.com/avatar.png"
        );

        assertThat(identity.subject()).isEqualTo("google-subject-123");
        assertThat(identity.displayName()).isEqualTo("Konstantin");
        assertThat(identity.avatarUrl())
                .isEqualTo("https://example.com/avatar.png");
    }

    @Test
    void shouldAllowNullableDisplayName() {

        GoogleIdentity identity = new GoogleIdentity(
                "google-subject-123",
                null,
                "https://example.com/avatar.png"
        );

        assertThat(identity.displayName()).isNull();
    }

    @Test
    void shouldAllowNullableAvatarUrl() {

        GoogleIdentity identity = new GoogleIdentity(
                "google-subject-123",
                "Konstantin",
                null
        );

        assertThat(identity.avatarUrl()).isNull();
    }

    @Test
    void shouldRejectNullSubject() {

        assertThatThrownBy(() -> new GoogleIdentity(
                null,
                "Konstantin",
                "https://example.com/avatar.png"
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("subject must not be null");
    }

    @Test
    void shouldRejectBlankSubject() {

        assertThatThrownBy(() -> new GoogleIdentity(
                "",
                "Konstantin",
                "https://example.com/avatar.png"
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("subject must not be blank");

        assertThatThrownBy(() -> new GoogleIdentity(
                "   ",
                "Konstantin",
                "https://example.com/avatar.png"
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("subject must not be blank");
    }
}
