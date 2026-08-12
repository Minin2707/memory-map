package memory_map.backend.media.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.image.ImageProcessingInput;
import org.junit.jupiter.api.Test;

import java.lang.reflect.RecordComponent;
import java.time.Instant;
import java.util.Arrays;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class UploadPhotoCommandTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final AuthenticatedUser AUTHENTICATED_USER =
            new AuthenticatedUser(USER_ID);
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000004");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000005");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final ImageProcessingInput IMAGE =
            new ImageProcessingInput(new byte[] {1, 2, 3}, "image/jpeg");

    @Test
    void shouldCreateCommandWhenRequiredFieldsAreValid() {
        UploadPhotoCommand command = command();

        assertThat(command.authenticatedUser()).isEqualTo(AUTHENTICATED_USER);
        assertThat(command.memoryId()).isEqualTo(MEMORY_ID);
        assertThat(command.mediaId()).isEqualTo(MEDIA_ID);
        assertThat(command.image()).isEqualTo(IMAGE);
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldRejectNullRequiredFields() {
        assertThatThrownBy(() -> new UploadPhotoCommand(
                null,
                MEMORY_ID,
                MEDIA_ID,
                IMAGE,
                CURRENT_TIME
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");

        assertThatThrownBy(() -> new UploadPhotoCommand(
                AUTHENTICATED_USER,
                null,
                MEDIA_ID,
                IMAGE,
                CURRENT_TIME
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("memoryId must not be null");

        assertThatThrownBy(() -> new UploadPhotoCommand(
                AUTHENTICATED_USER,
                MEMORY_ID,
                null,
                IMAGE,
                CURRENT_TIME
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("mediaId must not be null");

        assertThatThrownBy(() -> new UploadPhotoCommand(
                AUTHENTICATED_USER,
                MEMORY_ID,
                MEDIA_ID,
                null,
                CURRENT_TIME
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("image must not be null");

        assertThatThrownBy(() -> new UploadPhotoCommand(
                AUTHENTICATED_USER,
                MEMORY_ID,
                MEDIA_ID,
                IMAGE,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("currentTime must not be null");
    }

    @Test
    void shouldPreserveValueSemantics() {
        UploadPhotoCommand first = command();
        UploadPhotoCommand second = command();
        UploadPhotoCommand different = new UploadPhotoCommand(
                AUTHENTICATED_USER,
                MEMORY_ID,
                UUID.fromString("00000000-0000-0000-0000-000000000006"),
                IMAGE,
                CURRENT_TIME
        );

        assertThat(first)
                .isEqualTo(second)
                .hasSameHashCodeAs(second)
                .isNotEqualTo(different);
    }

    @Test
    void shouldUseSafeToString() {
        UploadPhotoCommand command = command();

        assertThat(command.toString())
                .isEqualTo("UploadPhotoCommand[hasImage=true]")
                .doesNotContain(USER_ID.toString())
                .doesNotContain(MEMORY_ID.toString())
                .doesNotContain(MEDIA_ID.toString())
                .doesNotContain(CURRENT_TIME.toString())
                .doesNotContain("image/jpeg")
                .doesNotContain("[1, 2, 3]")
                .doesNotContain("authenticatedUser")
                .doesNotContain("memoryId")
                .doesNotContain("mediaId")
                .doesNotContain("currentTime")
                .doesNotContain("storage")
                .doesNotContain("thumbnail");
    }

    @Test
    void shouldContainOnlyUploadBoundaryFields() {
        assertThat(recordComponentNames())
                .containsExactly(
                        "authenticatedUser",
                        "memoryId",
                        "mediaId",
                        "image",
                        "currentTime"
                );
    }

    @Test
    void shouldUseExpectedRecordComponentTypes() {
        assertThat(recordComponentTypes())
                .containsExactly(
                        AuthenticatedUser.class,
                        UUID.class,
                        UUID.class,
                        ImageProcessingInput.class,
                        Instant.class
                );
    }

    @Test
    void shouldNotContainClientChosenAuthorizationOrStorageFields() {
        assertThat(recordComponentNames())
                .doesNotContain(
                        "storyId",
                        "userId",
                        "role",
                        "ownerId",
                        "createdBy",
                        "mediaType",
                        "storageKey",
                        "displayStorageKey",
                        "thumbnailStorageKey",
                        "display",
                        "thumbnail",
                        "mimeType",
                        "fileSize",
                        "filename",
                        "url",
                        "repository"
                );
    }

    @Test
    void shouldNotNormalizeOrGenerateBoundaryValues() {
        ImageProcessingInput image = new ImageProcessingInput(
                new byte[] {9},
                "IMAGE/JPEG"
        );

        UploadPhotoCommand command = new UploadPhotoCommand(
                new AuthenticatedUser(USER_ID),
                MEMORY_ID,
                MEDIA_ID,
                image,
                CURRENT_TIME
        );

        assertThat(command.authenticatedUser().userId()).isEqualTo(USER_ID);
        assertThat(command.memoryId()).isEqualTo(MEMORY_ID);
        assertThat(command.mediaId()).isEqualTo(MEDIA_ID);
        assertThat(command.image()).isEqualTo(image);
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
        assertThat(command.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(OWNER_ID.toString())
                .doesNotContain("IMAGE/JPEG");
    }

    private static UploadPhotoCommand command() {
        return new UploadPhotoCommand(
                AUTHENTICATED_USER,
                MEMORY_ID,
                MEDIA_ID,
                IMAGE,
                CURRENT_TIME
        );
    }

    private static String[] recordComponentNames() {
        return Arrays.stream(UploadPhotoCommand.class.getRecordComponents())
                .map(RecordComponent::getName)
                .toArray(String[]::new);
    }

    private static Class<?>[] recordComponentTypes() {
        return Arrays.stream(UploadPhotoCommand.class.getRecordComponents())
                .map(RecordComponent::getType)
                .toArray(Class<?>[]::new);
    }
}
