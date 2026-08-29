package memory_map.backend.user.domain;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class UserTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");

    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00.123456Z");

    private static final Instant UPDATED_AT =
            Instant.parse("2026-01-01T10:00:01.123456Z");

    @Test
    void shouldCreateUserWhenRequiredFieldsAreValid() {

        User user = new User(
                USER_ID,
                "google-subject-123",
                "Konstantin",
                "https://example.com/avatar.png",
                CREATED_AT,
                UPDATED_AT
        );

        assertThat(user.id()).isEqualTo(USER_ID);
        assertThat(user.googleSubject()).isEqualTo("google-subject-123");
        assertThat(user.displayName()).isEqualTo("Konstantin");
        assertThat(user.displayNameCustomized()).isFalse();
        assertThat(user.avatarUrl()).isEqualTo("https://example.com/avatar.png");
        assertThat(user.createdAt()).isEqualTo(CREATED_AT);
        assertThat(user.updatedAt()).isEqualTo(UPDATED_AT);
        assertThat(user.deletedAt()).isNull();
        assertThat(user.isDeleted()).isFalse();
    }

    @Test
    void shouldAllowCustomizedDisplayNameMarker() {

        User user = new User(
                USER_ID,
                "google-subject-123",
                "Konstantin",
                true,
                "https://example.com/avatar.png",
                null,
                null,
                CREATED_AT,
                UPDATED_AT,
                null
        );

        assertThat(user.displayNameCustomized()).isTrue();
    }

    @Test
    void shouldAllowNullableAvatarUrl() {

        User user = new User(
                USER_ID,
                "google-subject-123",
                "Konstantin",
                null,
                CREATED_AT,
                UPDATED_AT
        );

        assertThat(user.avatarUrl()).isNull();
    }

    @Test
    void shouldAllowCustomAvatarMetadataPair() {

        User user = new User(
                USER_ID,
                "google-subject-123",
                "Konstantin",
                "https://example.com/avatar.png",
                "users/%s/avatar/avatar-object".formatted(USER_ID),
                UPDATED_AT,
                CREATED_AT,
                UPDATED_AT,
                null
        );

        assertThat(user.customAvatarStorageKey())
                .isEqualTo("users/%s/avatar/avatar-object".formatted(USER_ID));
        assertThat(user.customAvatarUpdatedAt()).isEqualTo(UPDATED_AT);
        assertThat(user.hasCustomAvatar()).isTrue();
    }

    @Test
    void shouldRejectIncompleteCustomAvatarMetadata() {

        assertThatThrownBy(() -> new User(
                USER_ID,
                "google-subject-123",
                "Konstantin",
                "https://example.com/avatar.png",
                "users/%s/avatar/avatar-object".formatted(USER_ID),
                null,
                CREATED_AT,
                UPDATED_AT,
                null
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("custom avatar key and timestamp must be set together");

        assertThatThrownBy(() -> new User(
                USER_ID,
                "google-subject-123",
                "Konstantin",
                "https://example.com/avatar.png",
                null,
                UPDATED_AT,
                CREATED_AT,
                UPDATED_AT,
                null
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("custom avatar key and timestamp must be set together");
    }

    @Test
    void shouldRejectBlankCustomAvatarStorageKey() {

        assertThatThrownBy(() -> new User(
                USER_ID,
                "google-subject-123",
                "Konstantin",
                "https://example.com/avatar.png",
                "   ",
                UPDATED_AT,
                CREATED_AT,
                UPDATED_AT,
                null
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("customAvatarStorageKey must not be blank");
    }

    @Test
    void shouldRejectNullId() {

        assertThatThrownBy(() -> new User(
                null,
                "google-subject-123",
                "Konstantin",
                null,
                CREATED_AT,
                UPDATED_AT
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("id must not be null");
    }

    @Test
    void shouldRejectNullGoogleSubject() {

        assertThatThrownBy(() -> new User(
                USER_ID,
                null,
                "Konstantin",
                null,
                CREATED_AT,
                UPDATED_AT
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("googleSubject must not be null");
    }

    @Test
    void shouldAllowNullGoogleSubjectForDeletedUser() {

        User user = new User(
                USER_ID,
                null,
                "Deleted user",
                null,
                CREATED_AT,
                UPDATED_AT,
                UPDATED_AT
        );

        assertThat(user.googleSubject()).isNull();
        assertThat(user.deletedAt()).isEqualTo(UPDATED_AT);
        assertThat(user.isDeleted()).isTrue();
    }

    @Test
    void shouldRejectBlankGoogleSubject() {

        assertThatThrownBy(() -> new User(
                USER_ID,
                "",
                "Konstantin",
                null,
                CREATED_AT,
                UPDATED_AT
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("googleSubject must not be blank");

        assertThatThrownBy(() -> new User(
                USER_ID,
                "   ",
                "Konstantin",
                null,
                CREATED_AT,
                UPDATED_AT
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("googleSubject must not be blank");
    }

    @Test
    void shouldRejectNullDisplayName() {

        assertThatThrownBy(() -> new User(
                USER_ID,
                "google-subject-123",
                null,
                null,
                CREATED_AT,
                UPDATED_AT
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("displayName must not be null");
    }

    @Test
    void shouldRejectBlankDisplayName() {

        assertThatThrownBy(() -> new User(
                USER_ID,
                "google-subject-123",
                "",
                null,
                CREATED_AT,
                UPDATED_AT
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("displayName must not be blank");

        assertThatThrownBy(() -> new User(
                USER_ID,
                "google-subject-123",
                "   ",
                null,
                CREATED_AT,
                UPDATED_AT
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("displayName must not be blank");
    }

    @Test
    void shouldRejectNullCreatedAt() {

        assertThatThrownBy(() -> new User(
                USER_ID,
                "google-subject-123",
                "Konstantin",
                null,
                null,
                UPDATED_AT
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("createdAt must not be null");
    }

    @Test
    void shouldRejectNullUpdatedAt() {

        assertThatThrownBy(() -> new User(
                USER_ID,
                "google-subject-123",
                "Konstantin",
                null,
                CREATED_AT,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("updatedAt must not be null");
    }

}
