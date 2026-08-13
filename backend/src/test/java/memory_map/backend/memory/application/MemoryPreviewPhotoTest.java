package memory_map.backend.memory.application;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MemoryPreviewPhotoTest {

    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");

    @Test
    void shouldExposeMediaId() {

        MemoryPreviewPhoto previewPhoto = new MemoryPreviewPhoto(MEDIA_ID);

        assertThat(previewPhoto.mediaId()).isEqualTo(MEDIA_ID);
    }

    @Test
    void shouldRejectNullMediaId() {

        assertThatThrownBy(() -> new MemoryPreviewPhoto(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("mediaId must not be null");
    }

    @Test
    void shouldHaveSafeToString() {

        String value = new MemoryPreviewPhoto(MEDIA_ID).toString();

        assertThat(value)
                .isEqualTo("MemoryPreviewPhoto[hasMediaId=true]")
                .doesNotContain(MEDIA_ID.toString());
    }
}
