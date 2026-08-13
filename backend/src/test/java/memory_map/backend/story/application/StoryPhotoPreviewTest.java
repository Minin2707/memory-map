package memory_map.backend.story.application;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StoryPhotoPreviewTest {

    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");

    @Test
    void shouldCreatePreviewWhenMediaIdIsValid() {

        StoryPhotoPreview preview = new StoryPhotoPreview(MEDIA_ID);

        assertThat(preview.mediaId()).isEqualTo(MEDIA_ID);
    }

    @Test
    void shouldRejectNullMediaId() {

        assertThatThrownBy(() -> new StoryPhotoPreview(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("mediaId must not be null");
    }

    @Test
    void shouldPreserveValueSemantics() {

        StoryPhotoPreview first = new StoryPhotoPreview(MEDIA_ID);
        StoryPhotoPreview second = new StoryPhotoPreview(MEDIA_ID);

        assertThat(first).isEqualTo(second);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    @Test
    void shouldHaveSafeToString() {

        StoryPhotoPreview preview = new StoryPhotoPreview(MEDIA_ID);

        assertThat(preview.toString())
                .isEqualTo("StoryPhotoPreview[hasMediaId=true]")
                .doesNotContain(MEDIA_ID.toString());
    }
}
