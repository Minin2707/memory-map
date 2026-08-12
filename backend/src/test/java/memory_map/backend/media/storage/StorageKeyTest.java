package memory_map.backend.media.storage;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StorageKeyTest {

    @Test
    void shouldCreateStorageKey() {
        StorageKey storageKey = new StorageKey("media/id/display");

        assertThat(storageKey.value()).isEqualTo("media/id/display");
    }

    @Test
    void shouldRejectNullValue() {
        assertThatThrownBy(() -> new StorageKey(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("value must not be null");
    }

    @Test
    void shouldRejectBlankValue() {
        assertThatThrownBy(() -> new StorageKey(" "))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("value must not be blank");
    }

    @Test
    void shouldHaveSafeToString() {
        StorageKey storageKey = new StorageKey("media/id/display");

        assertThat(storageKey.toString())
                .isEqualTo("StorageKey[redacted]")
                .doesNotContain(storageKey.value());
    }
}
