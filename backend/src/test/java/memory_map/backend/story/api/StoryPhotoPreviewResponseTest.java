package memory_map.backend.story.api;

import memory_map.backend.story.application.StoryPhotoPreview;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StoryPhotoPreviewResponseTest {

    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");

    @Test
    void shouldGenerateBackendRelativeThumbnailUrl() {

        StoryPhotoPreviewResponse response =
                StoryPhotoPreviewResponse.from(
                        new StoryPhotoPreview(MEDIA_ID)
                );

        assertThat(response.mediaId()).isEqualTo(MEDIA_ID);
        assertThat(response.thumbnailUrl())
                .isEqualTo("/api/v1/media/%s/thumbnail".formatted(MEDIA_ID));
    }

    @Test
    void shouldRejectNullPreviewPhoto() {

        assertThatThrownBy(() -> StoryPhotoPreviewResponse.from(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("previewPhoto must not be null");
    }
}
