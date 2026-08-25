package memory_map.backend.media.storage;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StorageByteRangeTest {

    @Test
    void shouldCreateValidRange() {
        StorageByteRange range = new StorageByteRange(10L, 25L);

        assertThat(range.offset()).isEqualTo(10L);
        assertThat(range.length()).isEqualTo(25L);
    }

    @Test
    void shouldAllowZeroOffset() {
        StorageByteRange range = new StorageByteRange(0L, 1L);

        assertThat(range.offset()).isZero();
        assertThat(range.length()).isEqualTo(1L);
    }

    @Test
    void shouldRejectNegativeOffset() {
        assertThatThrownBy(() -> new StorageByteRange(-1L, 1L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("offset must not be negative");
    }

    @Test
    void shouldRejectNonPositiveLength() {
        assertThatThrownBy(() -> new StorageByteRange(0L, 0L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("length must be positive");

        assertThatThrownBy(() -> new StorageByteRange(0L, -1L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("length must be positive");
    }

    @Test
    void shouldSupportRecordEquality() {
        StorageByteRange first = new StorageByteRange(5L, 10L);
        StorageByteRange same = new StorageByteRange(5L, 10L);
        StorageByteRange different = new StorageByteRange(6L, 10L);

        assertThat(first).isEqualTo(same);
        assertThat(first).hasSameHashCodeAs(same);
        assertThat(first).isNotEqualTo(different);
    }
}
