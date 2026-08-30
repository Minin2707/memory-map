package memory_map.backend.story.domain;

import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StoryCoverMetadataTest {

    private static final Instant UPDATED_AT =
            Instant.parse("2026-01-01T10:00:00Z");

    @Test
    void shouldCreateMetadataWhenFieldsAreValid() {

        StoryCoverMetadata metadata = validMetadata();

        assertThat(metadata.displayStorageKey())
                .isEqualTo("stories/story-1/cover/object-1/display");
        assertThat(metadata.displayFileSize()).isEqualTo(2_048L);
        assertThat(metadata.thumbnailStorageKey())
                .isEqualTo("stories/story-1/cover/object-1/thumbnail");
        assertThat(metadata.thumbnailFileSize()).isEqualTo(512L);
        assertThat(metadata.mimeType()).isEqualTo("image/jpeg");
        assertThat(metadata.updatedAt()).isEqualTo(UPDATED_AT);
    }

    @Test
    void shouldRejectBlankDisplayStorageKey() {

        assertThatThrownBy(() -> new StoryCoverMetadata(
                " ",
                2_048L,
                "stories/story-1/cover/object-1/thumbnail",
                512L,
                "image/jpeg",
                UPDATED_AT
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("displayStorageKey must not be blank");
    }

    @Test
    void shouldRejectBlankThumbnailStorageKey() {

        assertThatThrownBy(() -> new StoryCoverMetadata(
                "stories/story-1/cover/object-1/display",
                2_048L,
                "",
                512L,
                "image/jpeg",
                UPDATED_AT
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("thumbnailStorageKey must not be blank");
    }

    @Test
    void shouldRejectEqualStorageKeys() {

        assertThatThrownBy(() -> new StoryCoverMetadata(
                "stories/story-1/cover/object-1/display",
                2_048L,
                "stories/story-1/cover/object-1/display",
                512L,
                "image/jpeg",
                UPDATED_AT
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage(
                        "displayStorageKey and thumbnailStorageKey must differ"
                );
    }

    @Test
    void shouldRejectNonPositiveDisplayFileSize() {

        assertThatThrownBy(() -> new StoryCoverMetadata(
                "stories/story-1/cover/object-1/display",
                0L,
                "stories/story-1/cover/object-1/thumbnail",
                512L,
                "image/jpeg",
                UPDATED_AT
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("displayFileSize must be positive");
    }

    @Test
    void shouldRejectNonPositiveThumbnailFileSize() {

        assertThatThrownBy(() -> new StoryCoverMetadata(
                "stories/story-1/cover/object-1/display",
                2_048L,
                "stories/story-1/cover/object-1/thumbnail",
                -1L,
                "image/jpeg",
                UPDATED_AT
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("thumbnailFileSize must be positive");
    }

    @Test
    void shouldRejectBlankMimeType() {

        assertThatThrownBy(() -> new StoryCoverMetadata(
                "stories/story-1/cover/object-1/display",
                2_048L,
                "stories/story-1/cover/object-1/thumbnail",
                512L,
                " ",
                UPDATED_AT
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("mimeType must not be blank");
    }

    @Test
    void shouldRejectNullUpdatedAt() {

        assertThatThrownBy(() -> new StoryCoverMetadata(
                "stories/story-1/cover/object-1/display",
                2_048L,
                "stories/story-1/cover/object-1/thumbnail",
                512L,
                "image/jpeg",
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("updatedAt must not be null");
    }

    @Test
    void shouldNotExposeStorageKeysInToString() {

        assertThat(validMetadata().toString())
                .isEqualTo(
                        "StoryCoverMetadata[hasDisplay=true, "
                                + "hasThumbnail=true, hasMimeType=true]"
                )
                .doesNotContain("stories/story-1/cover/object-1/display")
                .doesNotContain("stories/story-1/cover/object-1/thumbnail");
    }

    private static StoryCoverMetadata validMetadata() {
        return new StoryCoverMetadata(
                "stories/story-1/cover/object-1/display",
                2_048L,
                "stories/story-1/cover/object-1/thumbnail",
                512L,
                "image/jpeg",
                UPDATED_AT
        );
    }
}
