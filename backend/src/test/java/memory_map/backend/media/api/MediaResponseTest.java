package memory_map.backend.media.api;

import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.domain.MediaType;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MediaResponseTest {

    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-10T10:00:00Z");

    @Test
    void shouldMapSafeMediaFileFields() {
        MediaResponse response = MediaResponse.from(mediaFile());

        assertThat(response.id()).isEqualTo(MEDIA_ID);
        assertThat(response.memoryId()).isEqualTo(MEMORY_ID);
        assertThat(response.mediaType()).isEqualTo(MediaType.PHOTO);
        assertThat(response.displayFileSize()).isEqualTo(1_024L);
        assertThat(response.thumbnailFileSize()).isEqualTo(128L);
        assertThat(response.mimeType()).isEqualTo("image/jpeg");
        assertThat(response.createdAt()).isEqualTo(CREATED_AT);
        assertThat(response.thumbnailUrl())
                .isEqualTo("/api/v1/media/%s/thumbnail".formatted(MEDIA_ID));
        assertThat(response.displayUrl())
                .isEqualTo("/api/v1/media/%s/display".formatted(MEDIA_ID));
    }

    @Test
    void shouldNotExposeStorageKeysThroughRecordComponents() {
        assertThat(MediaResponse.class.getRecordComponents())
                .extracting(component -> component.getName())
                .containsExactly(
                        "id",
                        "memoryId",
                        "mediaType",
                        "displayFileSize",
                        "thumbnailFileSize",
                        "mimeType",
                        "createdAt",
                        "thumbnailUrl",
                        "displayUrl"
                );
    }

    @Test
    void shouldRejectNullMediaFile() {
        assertThatThrownBy(() -> MediaResponse.from(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("mediaFile must not be null");
    }

    private static MediaFile mediaFile() {
        return new MediaFile(
                MEDIA_ID,
                MEMORY_ID,
                MediaType.PHOTO,
                "media/" + MEDIA_ID + "/display",
                1_024L,
                "media/" + MEDIA_ID + "/thumbnail",
                128L,
                "image/jpeg",
                CREATED_AT
        );
    }
}
