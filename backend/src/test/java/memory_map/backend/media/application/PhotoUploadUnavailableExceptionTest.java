package memory_map.backend.media.application;

import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;

import java.util.Locale;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class PhotoUploadUnavailableExceptionTest {

    private static final String SAFE_MESSAGE = "Photo could not be uploaded";
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000004");

    @Test
    void shouldCreateExceptionWithSafeMessage() {
        PhotoUploadUnavailableException exception =
                new PhotoUploadUnavailableException();

        assertThat(exception)
                .hasMessage(SAFE_MESSAGE)
                .hasNoCause();
    }

    @Test
    void shouldUseStableSafeMessageAndToString() {
        PhotoUploadUnavailableException exception =
                new PhotoUploadUnavailableException();

        assertThat(exception.getMessage()).isEqualTo(SAFE_MESSAGE);
        assertThat(exception.toString())
                .isEqualTo(
                        "PhotoUploadUnavailableException[message=%s]"
                                .formatted(SAFE_MESSAGE)
                );
    }

    @Test
    void shouldNotExposeIdentifiersAccessRolesOrInfrastructureDetails() {
        PhotoUploadUnavailableException exception =
                new PhotoUploadUnavailableException();

        assertSafeText(exception.getMessage());
        assertSafeText(exception.toString());
    }

    private static void assertSafeText(String text) {
        assertThat(text)
                .doesNotContain(MEMORY_ID.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(MEDIA_ID.toString())
                .doesNotContain(StoryRole.OWNER.name())
                .doesNotContain(StoryRole.CO_OWNER.name())
                .doesNotContain(StoryRole.EDITOR.name())
                .doesNotContain(StoryRole.VIEWER.name())
                .doesNotContain("image/jpeg")
                .doesNotContain("display-key")
                .doesNotContain("thumbnail-key");

        assertThat(text.toLowerCase(Locale.ROOT))
                .doesNotContain("user")
                .doesNotContain("story")
                .doesNotContain("memory")
                .doesNotContain("media")
                .doesNotContain("role")
                .doesNotContain("owner")
                .doesNotContain("viewer")
                .doesNotContain("participant")
                .doesNotContain("author")
                .doesNotContain("membership")
                .doesNotContain("storage")
                .doesNotContain("minio")
                .doesNotContain("sql")
                .doesNotContain("jdbc")
                .doesNotContain("repository")
                .doesNotContain("forbidden")
                .doesNotContain("access denied")
                .doesNotContain("inaccessible")
                .doesNotContain("not found");
    }
}
