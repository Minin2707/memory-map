package memory_map.backend.media.application;

import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DownloadedMediaTest {

    @Test
    void shouldExposeStreamMetadataAndKeepToStringSafe() {
        ByteArrayInputStream content = new ByteArrayInputStream(
                new byte[] {1, 2, 3}
        );

        DownloadedMedia result = new DownloadedMedia(
                content,
                3L,
                "image/jpeg"
        );

        assertThat(result.content()).isSameAs(content);
        assertThat(result.contentLength()).isEqualTo(3L);
        assertThat(result.contentType()).isEqualTo("image/jpeg");
        assertThat(result.toString())
                .contains("contentLength=3")
                .doesNotContain("StorageKey")
                .doesNotContain("[1, 2, 3]")
                .doesNotContain("media/");
    }

    @Test
    void shouldRejectInvalidValues() {
        ByteArrayInputStream content = new ByteArrayInputStream(new byte[] {1});

        assertThatThrownBy(() -> new DownloadedMedia(
                null,
                1L,
                "image/jpeg"
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("content must not be null");
        assertThatThrownBy(() -> new DownloadedMedia(content, 0L, "image/jpeg"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("contentLength must be positive");
        assertThatThrownBy(() -> new DownloadedMedia(content, 1L, null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("contentType must not be null");
        assertThatThrownBy(() -> new DownloadedMedia(content, 1L, " "))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("contentType must not be blank");
    }
}
