package memory_map.backend.media.storage;

import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.io.InputStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StoredObjectTest {

    @Test
    void shouldCreateStoredObject() {
        InputStream content = new ByteArrayInputStream(new byte[] {1, 2, 3});

        StoredObject object = new StoredObject(
                content,
                3L,
                "image/jpeg"
        );

        assertThat(object.content()).isSameAs(content);
        assertThat(object.contentLength()).isEqualTo(3L);
        assertThat(object.contentType()).isEqualTo("image/jpeg");
    }

    @Test
    void shouldRejectInvalidValues() {
        assertThatThrownBy(() -> new StoredObject(
                null,
                3L,
                "image/jpeg"
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("content must not be null");

        assertThatThrownBy(() -> new StoredObject(
                new ByteArrayInputStream(new byte[] {1}),
                0L,
                "image/jpeg"
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("contentLength must be positive");

        assertThatThrownBy(() -> new StoredObject(
                new ByteArrayInputStream(new byte[] {1}),
                1L,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("contentType must not be null");

        assertThatThrownBy(() -> new StoredObject(
                new ByteArrayInputStream(new byte[] {1}),
                1L,
                " "
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("contentType must not be blank");
    }

    @Test
    void shouldHaveSafeToString() {
        StoredObject object = new StoredObject(
                new ByteArrayInputStream(new byte[] {1, 2, 3}),
                3L,
                "image/jpeg"
        );

        assertThat(object.toString())
                .contains("StoredObject")
                .contains("contentLength=3")
                .doesNotContain("image/jpeg")
                .doesNotContain("[1, 2, 3]");
    }
}
