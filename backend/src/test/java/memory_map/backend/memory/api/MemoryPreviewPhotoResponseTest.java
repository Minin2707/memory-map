package memory_map.backend.memory.api;

import memory_map.backend.memory.application.MemoryPreviewPhoto;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MemoryPreviewPhotoResponseTest {

    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");

    @Test
    void shouldGenerateBackendRelativeThumbnailUrl() {

        MemoryPreviewPhotoResponse response =
                MemoryPreviewPhotoResponse.from(
                        new MemoryPreviewPhoto(MEDIA_ID)
                );

        assertThat(response.mediaId()).isEqualTo(MEDIA_ID);
        assertThat(response.thumbnailUrl())
                .isEqualTo("/api/v1/media/%s/thumbnail".formatted(MEDIA_ID));
    }

    @Test
    void shouldRejectNullPreviewPhoto() {

        assertThatThrownBy(() -> MemoryPreviewPhotoResponse.from(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("previewPhoto must not be null");
    }
}
