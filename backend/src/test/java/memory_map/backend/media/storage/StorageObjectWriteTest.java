package memory_map.backend.media.storage;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StorageObjectWriteTest {

    private static final StorageKey STORAGE_KEY =
            new StorageKey("media/id/display");

    @Test
    void shouldCreateStorageObjectWrite() {
        StorageObjectWrite object = new StorageObjectWrite(
                STORAGE_KEY,
                new byte[] {1, 2, 3},
                "image/jpeg"
        );

        assertThat(object.storageKey()).isEqualTo(STORAGE_KEY);
        assertThat(object.content()).containsExactly(1, 2, 3);
        assertThat(object.contentLength()).isEqualTo(3L);
        assertThat(object.contentType()).isEqualTo("image/jpeg");
    }

    @Test
    void shouldDefensivelyCopyContent() {
        byte[] content = new byte[] {1, 2, 3};
        StorageObjectWrite object = new StorageObjectWrite(
                STORAGE_KEY,
                content,
                "image/jpeg"
        );

        content[0] = 9;
        byte[] returned = object.content();
        returned[1] = 9;

        assertThat(object.content()).containsExactly(1, 2, 3);
    }

    @Test
    void shouldRejectInvalidValues() {
        assertThatThrownBy(() -> new StorageObjectWrite(
                null,
                new byte[] {1},
                "image/jpeg"
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storageKey must not be null");

        assertThatThrownBy(() -> new StorageObjectWrite(
                STORAGE_KEY,
                null,
                "image/jpeg"
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("content must not be null");

        assertThatThrownBy(() -> new StorageObjectWrite(
                STORAGE_KEY,
                new byte[] {},
                "image/jpeg"
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("content must not be empty");

        assertThatThrownBy(() -> new StorageObjectWrite(
                STORAGE_KEY,
                new byte[] {1},
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("contentType must not be null");

        assertThatThrownBy(() -> new StorageObjectWrite(
                STORAGE_KEY,
                new byte[] {1},
                " "
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("contentType must not be blank");
    }

    @Test
    void shouldUseValueEqualityAndHashCode() {
        StorageObjectWrite first = new StorageObjectWrite(
                STORAGE_KEY,
                new byte[] {1, 2, 3},
                "image/jpeg"
        );
        StorageObjectWrite second = new StorageObjectWrite(
                STORAGE_KEY,
                new byte[] {1, 2, 3},
                "image/jpeg"
        );
        StorageObjectWrite other = new StorageObjectWrite(
                STORAGE_KEY,
                new byte[] {3, 2, 1},
                "image/jpeg"
        );

        assertThat(first)
                .isEqualTo(second)
                .hasSameHashCodeAs(second)
                .isNotEqualTo(other);
    }

    @Test
    void shouldHaveSafeToString() {
        StorageObjectWrite object = new StorageObjectWrite(
                STORAGE_KEY,
                new byte[] {1, 2, 3},
                "image/jpeg"
        );

        assertThat(object.toString())
                .contains("StorageObjectWrite")
                .contains("contentLength=3")
                .doesNotContain(STORAGE_KEY.value())
                .doesNotContain("image/jpeg")
                .doesNotContain("[1, 2, 3]");
    }
}
