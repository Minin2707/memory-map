package memory_map.backend.media.domain;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MediaFileTest {

    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00Z");

    @Test
    void shouldCreatePhotoWithDisplayAndThumbnailRepresentations() {
        MediaFile mediaFile = mediaFile();

        assertThat(mediaFile.id()).isEqualTo(MEDIA_ID);
        assertThat(mediaFile.memoryId()).isEqualTo(MEMORY_ID);
        assertThat(mediaFile.type()).isEqualTo(MediaType.PHOTO);
        assertThat(mediaFile.displayStorageKey()).isEqualTo("display-key");
        assertThat(mediaFile.displayFileSize()).isEqualTo(1_024L);
        assertThat(mediaFile.thumbnailStorageKey()).isEqualTo("thumbnail-key");
        assertThat(mediaFile.thumbnailFileSize()).isEqualTo(128L);
        assertThat(mediaFile.mimeType()).isEqualTo("image/jpeg");
        assertThat(mediaFile.createdAt()).isEqualTo(CREATED_AT);
    }

    @Test
    void shouldRejectNullRequiredFields() {
        assertThatThrownBy(() -> new MediaFile(
                null,
                MEMORY_ID,
                MediaType.PHOTO,
                "display-key",
                1_024L,
                "thumbnail-key",
                128L,
                "image/jpeg",
                CREATED_AT
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("id must not be null");

        assertThatThrownBy(() -> new MediaFile(
                MEDIA_ID,
                null,
                MediaType.PHOTO,
                "display-key",
                1_024L,
                "thumbnail-key",
                128L,
                "image/jpeg",
                CREATED_AT
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("memoryId must not be null");

        assertThatThrownBy(() -> new MediaFile(
                MEDIA_ID,
                MEMORY_ID,
                null,
                "display-key",
                1_024L,
                "thumbnail-key",
                128L,
                "image/jpeg",
                CREATED_AT
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("type must not be null");

        assertThatThrownBy(() -> new MediaFile(
                MEDIA_ID,
                MEMORY_ID,
                MediaType.PHOTO,
                null,
                1_024L,
                "thumbnail-key",
                128L,
                "image/jpeg",
                CREATED_AT
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("displayStorageKey must not be null");

        assertThatThrownBy(() -> new MediaFile(
                MEDIA_ID,
                MEMORY_ID,
                MediaType.PHOTO,
                "display-key",
                1_024L,
                null,
                128L,
                "image/jpeg",
                CREATED_AT
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("thumbnailStorageKey must not be null");

        assertThatThrownBy(() -> new MediaFile(
                MEDIA_ID,
                MEMORY_ID,
                MediaType.PHOTO,
                "display-key",
                1_024L,
                "thumbnail-key",
                128L,
                null,
                CREATED_AT
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("mimeType must not be null");

        assertThatThrownBy(() -> new MediaFile(
                MEDIA_ID,
                MEMORY_ID,
                MediaType.PHOTO,
                "display-key",
                1_024L,
                "thumbnail-key",
                128L,
                "image/jpeg",
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("createdAt must not be null");
    }

    @Test
    void shouldRejectBlankStorageKeysAndMimeType() {
        assertThatThrownBy(() -> new MediaFile(
                MEDIA_ID,
                MEMORY_ID,
                MediaType.PHOTO,
                " ",
                1_024L,
                "thumbnail-key",
                128L,
                "image/jpeg",
                CREATED_AT
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("displayStorageKey must not be blank");

        assertThatThrownBy(() -> new MediaFile(
                MEDIA_ID,
                MEMORY_ID,
                MediaType.PHOTO,
                "display-key",
                1_024L,
                " ",
                128L,
                "image/jpeg",
                CREATED_AT
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("thumbnailStorageKey must not be blank");

        assertThatThrownBy(() -> new MediaFile(
                MEDIA_ID,
                MEMORY_ID,
                MediaType.PHOTO,
                "display-key",
                1_024L,
                "thumbnail-key",
                128L,
                " ",
                CREATED_AT
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("mimeType must not be blank");
    }

    @Test
    void shouldRejectEqualRepresentationStorageKeys() {
        assertThatThrownBy(() -> new MediaFile(
                MEDIA_ID,
                MEMORY_ID,
                MediaType.PHOTO,
                "same-key",
                1_024L,
                "same-key",
                128L,
                "image/jpeg",
                CREATED_AT
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("displayStorageKey and thumbnailStorageKey must differ");
    }

    @Test
    void shouldRejectNonPositiveRepresentationFileSizes() {
        assertThatThrownBy(() -> new MediaFile(
                MEDIA_ID,
                MEMORY_ID,
                MediaType.PHOTO,
                "display-key",
                0L,
                "thumbnail-key",
                128L,
                "image/jpeg",
                CREATED_AT
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("displayFileSize must be positive");

        assertThatThrownBy(() -> new MediaFile(
                MEDIA_ID,
                MEMORY_ID,
                MediaType.PHOTO,
                "display-key",
                1_024L,
                "thumbnail-key",
                0L,
                "image/jpeg",
                CREATED_AT
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("thumbnailFileSize must be positive");
    }

    @Test
    void shouldUseValueEqualityAndHashCode() {
        MediaFile first = mediaFile();
        MediaFile same = mediaFile();
        MediaFile other = new MediaFile(
                MEDIA_ID,
                MEMORY_ID,
                MediaType.PHOTO,
                "other-display-key",
                1_024L,
                "other-thumbnail-key",
                128L,
                "image/jpeg",
                CREATED_AT
        );

        assertThat(first)
                .isEqualTo(same)
                .hasSameHashCodeAs(same)
                .isNotEqualTo(other);
    }

    @Test
    void shouldHaveSafeToString() {
        String value = mediaFile().toString();

        assertThat(value)
                .contains("MediaFile")
                .contains("PHOTO")
                .doesNotContain(MEDIA_ID.toString())
                .doesNotContain(MEMORY_ID.toString())
                .doesNotContain("display-key")
                .doesNotContain("thumbnail-key")
                .doesNotContain("image/jpeg");
    }

    private static MediaFile mediaFile() {
        return new MediaFile(
                MEDIA_ID,
                MEMORY_ID,
                MediaType.PHOTO,
                "display-key",
                1_024L,
                "thumbnail-key",
                128L,
                "image/jpeg",
                CREATED_AT
        );
    }
}
