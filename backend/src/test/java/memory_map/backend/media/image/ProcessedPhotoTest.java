package memory_map.backend.media.image;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ProcessedPhotoTest {

    @Test
    void shouldCreateProcessedPhotoWithDisplayAndThumbnail() {
        ProcessedImage display = new ProcessedImage(new byte[] {1, 2, 3});
        ProcessedImage thumbnail = new ProcessedImage(new byte[] {4});

        ProcessedPhoto photo = new ProcessedPhoto(
                display,
                thumbnail,
                "image/jpeg"
        );

        assertThat(photo.display()).isEqualTo(display);
        assertThat(photo.thumbnail()).isEqualTo(thumbnail);
        assertThat(photo.mimeType()).isEqualTo("image/jpeg");
        assertThat(photo.displayFileSize()).isEqualTo(3L);
        assertThat(photo.thumbnailFileSize()).isEqualTo(1L);
    }

    @Test
    void shouldRejectInvalidValues() {
        ProcessedImage image = new ProcessedImage(new byte[] {1});

        assertThatThrownBy(() -> new ProcessedPhoto(
                null,
                image,
                "image/jpeg"
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("display must not be null");

        assertThatThrownBy(() -> new ProcessedPhoto(
                image,
                null,
                "image/jpeg"
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("thumbnail must not be null");

        assertThatThrownBy(() -> new ProcessedPhoto(
                image,
                image,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("mimeType must not be null");

        assertThatThrownBy(() -> new ProcessedPhoto(
                image,
                image,
                " "
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("mimeType must not be blank");
    }

    @Test
    void shouldHaveSafeToString() {
        ProcessedPhoto photo = new ProcessedPhoto(
                new ProcessedImage(new byte[] {1, 2, 3}),
                new ProcessedImage(new byte[] {4}),
                "image/jpeg"
        );

        assertThat(photo.toString())
                .isEqualTo("ProcessedPhoto[hasDisplay=true, hasThumbnail=true, hasMimeType=true]")
                .doesNotContain("image/jpeg")
                .doesNotContain("[1, 2, 3]");
    }
}
