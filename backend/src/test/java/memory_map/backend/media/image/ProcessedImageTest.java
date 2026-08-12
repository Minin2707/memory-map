package memory_map.backend.media.image;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ProcessedImageTest {

    @Test
    void shouldCreateProcessedImage() {
        ProcessedImage image = new ProcessedImage(new byte[] {1, 2, 3});

        assertThat(image.content()).containsExactly(1, 2, 3);
        assertThat(image.fileSize()).isEqualTo(3L);
    }

    @Test
    void shouldDefensivelyCopyContent() {
        byte[] content = new byte[] {1, 2, 3};
        ProcessedImage image = new ProcessedImage(content);

        content[0] = 9;
        byte[] returned = image.content();
        returned[1] = 9;

        assertThat(image.content()).containsExactly(1, 2, 3);
    }

    @Test
    void shouldRejectInvalidValues() {
        assertThatThrownBy(() -> new ProcessedImage(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("content must not be null");

        assertThatThrownBy(() -> new ProcessedImage(new byte[] {}))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("content must not be empty");
    }

    @Test
    void shouldUseValueEqualityAndHashCode() {
        ProcessedImage first = new ProcessedImage(new byte[] {1, 2, 3});
        ProcessedImage second = new ProcessedImage(new byte[] {1, 2, 3});
        ProcessedImage other = new ProcessedImage(new byte[] {3, 2, 1});

        assertThat(first)
                .isEqualTo(second)
                .hasSameHashCodeAs(second)
                .isNotEqualTo(other);
    }

    @Test
    void shouldHaveSafeToString() {
        ProcessedImage image = new ProcessedImage(new byte[] {1, 2, 3});

        assertThat(image.toString())
                .contains("ProcessedImage")
                .contains("fileSize=3")
                .doesNotContain("[1, 2, 3]");
    }
}
