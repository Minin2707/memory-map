package memory_map.backend.story.api;

import memory_map.backend.story.application.StoryPhotoPreview;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StoryPhotoPreviewResponseTest {

    private static final String THUMBNAIL_URL =
            "/api/v1/media/media-id/thumbnail";
    private static final String DISPLAY_URL =
            "/api/v1/media/media-id/display";

    @Test
    void shouldMapBackendRelativePreviewUrls() {

        StoryPhotoPreviewResponse response =
                StoryPhotoPreviewResponse.from(
                        new StoryPhotoPreview(THUMBNAIL_URL, DISPLAY_URL)
                );

        assertThat(response.thumbnailUrl()).isEqualTo(THUMBNAIL_URL);
        assertThat(response.displayUrl()).isEqualTo(DISPLAY_URL);
    }

    @Test
    void shouldRejectNullPreviewPhoto() {

        assertThatThrownBy(() -> StoryPhotoPreviewResponse.from(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("previewPhoto must not be null");
    }
}
