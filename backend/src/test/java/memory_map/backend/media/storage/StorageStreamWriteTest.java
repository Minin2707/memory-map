package memory_map.backend.media.storage;

import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StorageStreamWriteTest {

    private static final StorageKey STORAGE_KEY =
            new StorageKey("music/tracks/id/audio.mp3");

    @Test
    void shouldCreateStreamWriteWhenValuesAreValid() {
        ByteArrayInputStream content =
                new ByteArrayInputStream(new byte[] {1});

        StorageStreamWrite write = new StorageStreamWrite(
                STORAGE_KEY,
                content,
                1L,
                "audio/mpeg"
        );

        assertThat(write.storageKey()).isEqualTo(STORAGE_KEY);
        assertThat(write.content()).isSameAs(content);
        assertThat(write.contentLength()).isEqualTo(1L);
        assertThat(write.contentType()).isEqualTo("audio/mpeg");
    }

    @Test
    void shouldRejectInvalidValues() {
        ByteArrayInputStream content =
                new ByteArrayInputStream(new byte[] {1});

        assertThatThrownBy(() -> new StorageStreamWrite(
                null,
                content,
                1L,
                "audio/mpeg"
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storageKey must not be null");

        assertThatThrownBy(() -> new StorageStreamWrite(
                STORAGE_KEY,
                null,
                1L,
                "audio/mpeg"
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("content must not be null");

        assertThatThrownBy(() -> new StorageStreamWrite(
                STORAGE_KEY,
                content,
                0L,
                "audio/mpeg"
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("contentLength must be positive");

        assertThatThrownBy(() -> new StorageStreamWrite(
                STORAGE_KEY,
                content,
                1L,
                " "
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("contentType must not be blank");
    }

    @Test
    void shouldHaveSafeToString() {
        StorageStreamWrite write = new StorageStreamWrite(
                STORAGE_KEY,
                new ByteArrayInputStream(new byte[] {1}),
                1L,
                "audio/mpeg"
        );

        assertThat(write.toString())
                .contains("StorageStreamWrite")
                .contains("contentLength=1")
                .doesNotContain(STORAGE_KEY.value())
                .doesNotContain("audio/mpeg");
    }
}
