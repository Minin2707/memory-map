package memory_map.backend.story.application;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StoryPhotoPreviewTest {

    private static final String THUMBNAIL_URL =
            "/api/v1/media/media-id/thumbnail";
    private static final String DISPLAY_URL =
            "/api/v1/media/media-id/display";

    @Test
    void shouldCreatePreviewWhenPathsAreValid() {

        StoryPhotoPreview preview =
                new StoryPhotoPreview(THUMBNAIL_URL, DISPLAY_URL);

        assertThat(preview.thumbnailUrl()).isEqualTo(THUMBNAIL_URL);
        assertThat(preview.displayUrl()).isEqualTo(DISPLAY_URL);
    }

    @Test
    void shouldRejectNullThumbnailUrl() {

        assertThatThrownBy(() -> new StoryPhotoPreview(null, DISPLAY_URL))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("thumbnailUrl must not be null");
    }

    @Test
    void shouldRejectBlankThumbnailUrl() {

        assertThatThrownBy(() -> new StoryPhotoPreview(" ", DISPLAY_URL))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("thumbnailUrl must not be blank");
    }

    @Test
    void shouldRejectNullDisplayUrl() {

        assertThatThrownBy(() -> new StoryPhotoPreview(THUMBNAIL_URL, null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("displayUrl must not be null");
    }

    @Test
    void shouldRejectBlankDisplayUrl() {

        assertThatThrownBy(() -> new StoryPhotoPreview(THUMBNAIL_URL, " "))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("displayUrl must not be blank");
    }

    @Test
    void shouldPreserveValueSemantics() {

        StoryPhotoPreview first =
                new StoryPhotoPreview(THUMBNAIL_URL, DISPLAY_URL);
        StoryPhotoPreview second =
                new StoryPhotoPreview(THUMBNAIL_URL, DISPLAY_URL);

        assertThat(first).isEqualTo(second);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    @Test
    void shouldHaveSafeToString() {

        StoryPhotoPreview preview =
                new StoryPhotoPreview(THUMBNAIL_URL, DISPLAY_URL);

        assertThat(preview.toString())
                .isEqualTo(
                        "StoryPhotoPreview[hasThumbnailUrl=true, "
                                + "hasDisplayUrl=true]"
                )
                .doesNotContain(THUMBNAIL_URL)
                .doesNotContain(DISPLAY_URL);
    }
}
