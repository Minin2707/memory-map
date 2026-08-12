package memory_map.backend.media.image;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ImageProcessingExceptionTest {

    @Test
    void shouldHaveSafeImageProcessingExceptionMessage() {
        ImageProcessingException exception = new ImageProcessingException();

        assertThat(exception)
                .hasMessage("Image could not be processed");
    }

    @Test
    void shouldHaveSafeInvalidImageMessageAndReason() {
        InvalidImageException exception = new InvalidImageException(
                InvalidImageReason.UNSUPPORTED_TYPE
        );

        assertThat(exception)
                .hasMessage("Image is invalid");
        assertThat(exception.reason())
                .isEqualTo(InvalidImageReason.UNSUPPORTED_TYPE);
        assertThat(exception.toString())
                .isEqualTo("InvalidImageException[reason=UNSUPPORTED_TYPE]");
    }

    @Test
    void shouldRejectNullInvalidImageReason() {
        assertThatThrownBy(() -> new InvalidImageException(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("reason must not be null");
    }
}
