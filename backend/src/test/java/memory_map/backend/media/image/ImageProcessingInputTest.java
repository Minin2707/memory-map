package memory_map.backend.media.image;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ImageProcessingInputTest {

    @Test
    void shouldCreateInputWithDeclaredContentType() {
        ImageProcessingInput input = new ImageProcessingInput(
                new byte[] {1, 2, 3},
                "image/png"
        );

        assertThat(input.content()).containsExactly(1, 2, 3);
        assertThat(input.contentLength()).isEqualTo(3L);
        assertThat(input.declaredContentType()).isEqualTo("image/png");
    }

    @Test
    void shouldAllowMissingDeclaredContentType() {
        ImageProcessingInput input = new ImageProcessingInput(
                new byte[] {1},
                null
        );

        assertThat(input.declaredContentType()).isNull();
    }

    @Test
    void shouldDefensivelyCopyContent() {
        byte[] content = new byte[] {1, 2, 3};
        ImageProcessingInput input = new ImageProcessingInput(
                content,
                "image/png"
        );

        content[0] = 9;
        byte[] returned = input.content();
        returned[1] = 9;

        assertThat(input.content()).containsExactly(1, 2, 3);
    }

    @Test
    void shouldRejectInvalidValues() {
        assertThatThrownBy(() -> new ImageProcessingInput(
                null,
                "image/png"
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("content must not be null");

        assertThatThrownBy(() -> new ImageProcessingInput(
                new byte[] {},
                "image/png"
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("content must not be empty");

        assertThatThrownBy(() -> new ImageProcessingInput(
                new byte[] {1},
                " "
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("declaredContentType must not be blank");
    }

    @Test
    void shouldUseValueEqualityAndHashCode() {
        ImageProcessingInput first = new ImageProcessingInput(
                new byte[] {1, 2, 3},
                "image/png"
        );
        ImageProcessingInput second = new ImageProcessingInput(
                new byte[] {1, 2, 3},
                "image/png"
        );
        ImageProcessingInput other = new ImageProcessingInput(
                new byte[] {3, 2, 1},
                "image/png"
        );

        assertThat(first)
                .isEqualTo(second)
                .hasSameHashCodeAs(second)
                .isNotEqualTo(other);
    }

    @Test
    void shouldHaveSafeToString() {
        ImageProcessingInput input = new ImageProcessingInput(
                new byte[] {1, 2, 3},
                "image/png"
        );

        assertThat(input.toString())
                .contains("ImageProcessingInput")
                .contains("contentLength=3")
                .doesNotContain("image/png")
                .doesNotContain("[1, 2, 3]");
    }
}
