package memory_map.backend.music.domain;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MusicTrackTest {

    private static final UUID TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant UPDATED_AT =
            Instant.parse("2026-01-01T10:00:01Z");

    @Test
    void shouldCreateMusicTrackWhenRequiredFieldsAreValid() {
        MusicTrack musicTrack = musicTrack();

        assertThat(musicTrack.id()).isEqualTo(TRACK_ID);
        assertThat(musicTrack.title()).isEqualTo("Calm Piano");
        assertThat(musicTrack.artist()).isEqualTo("Memory Story");
        assertThat(musicTrack.durationSeconds()).isEqualTo(180);
        assertThat(musicTrack.status()).isEqualTo(MusicTrackStatus.ACTIVE);
        assertThat(musicTrack.sortOrder()).isEqualTo(0);
        assertThat(musicTrack.storageKey()).isEqualTo("music/calm-piano.mp3");
        assertThat(musicTrack.mimeType()).isEqualTo("audio/mpeg");
        assertThat(musicTrack.fileSize()).isEqualTo(4_096L);
        assertThat(musicTrack.createdAt()).isEqualTo(CREATED_AT);
        assertThat(musicTrack.updatedAt()).isEqualTo(UPDATED_AT);
    }

    @Test
    void shouldUseValueEqualityAndHashCode() {
        MusicTrack first = musicTrack();
        MusicTrack same = musicTrack();
        MusicTrack other = new MusicTrack(
                TRACK_ID,
                "Other",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                0,
                "music/other.mp3",
                "audio/mpeg",
                4_096L,
                CREATED_AT,
                UPDATED_AT
        );

        assertThat(first)
                .isEqualTo(same)
                .hasSameHashCodeAs(same)
                .isNotEqualTo(other);
    }

    @Test
    void shouldAllowUpdatedAtEqualToCreatedAt() {
        MusicTrack musicTrack = new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                0,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                CREATED_AT,
                CREATED_AT
        );

        assertThat(musicTrack.updatedAt()).isEqualTo(CREATED_AT);
    }

    @Test
    void shouldRejectNullRequiredFields() {
        assertThatThrownBy(() -> new MusicTrack(
                null,
                "Calm Piano",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                0,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                CREATED_AT,
                UPDATED_AT
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("id must not be null");

        assertThatThrownBy(() -> new MusicTrack(
                TRACK_ID,
                null,
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                0,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                CREATED_AT,
                UPDATED_AT
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("title must not be null");

        assertThatThrownBy(() -> new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                null,
                180,
                MusicTrackStatus.ACTIVE,
                0,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                CREATED_AT,
                UPDATED_AT
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("artist must not be null");

        assertThatThrownBy(() -> new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                180,
                null,
                0,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                CREATED_AT,
                UPDATED_AT
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("status must not be null");

        assertThatThrownBy(() -> new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                0,
                null,
                "audio/mpeg",
                4_096L,
                CREATED_AT,
                UPDATED_AT
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("storageKey must not be null");

        assertThatThrownBy(() -> new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                0,
                "music/calm-piano.mp3",
                null,
                4_096L,
                CREATED_AT,
                UPDATED_AT
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("mimeType must not be null");

        assertThatThrownBy(() -> new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                0,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                null,
                UPDATED_AT
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("createdAt must not be null");

        assertThatThrownBy(() -> new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                0,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                CREATED_AT,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("updatedAt must not be null");
    }

    @Test
    void shouldRejectBlankStrings() {
        assertThatThrownBy(() -> musicTrackWithTitle(""))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("title must not be blank");

        assertThatThrownBy(() -> musicTrackWithTitle("   "))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("title must not be blank");

        assertThatThrownBy(() -> musicTrackWithArtist(""))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("artist must not be blank");

        assertThatThrownBy(() -> musicTrackWithArtist("   "))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("artist must not be blank");

        assertThatThrownBy(() -> musicTrackWithStorageKey(""))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("storageKey must not be blank");

        assertThatThrownBy(() -> musicTrackWithStorageKey("   "))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("storageKey must not be blank");

        assertThatThrownBy(() -> musicTrackWithMimeType(""))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("mimeType must not be blank");

        assertThatThrownBy(() -> musicTrackWithMimeType("   "))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("mimeType must not be blank");
    }

    @Test
    void shouldRejectInvalidNumbers() {
        assertThatThrownBy(() -> musicTrackWithDurationSeconds(0))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("durationSeconds must be positive");

        assertThatThrownBy(() -> musicTrackWithDurationSeconds(-1))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("durationSeconds must be positive");

        assertThatThrownBy(() -> musicTrackWithSortOrder(-1))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("sortOrder must not be negative");

        assertThatThrownBy(() -> musicTrackWithFileSize(0))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("fileSize must be positive");

        assertThatThrownBy(() -> musicTrackWithFileSize(-1))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("fileSize must be positive");
    }

    @Test
    void shouldRejectUpdatedAtBeforeCreatedAt() {
        assertThatThrownBy(() -> new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                0,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                CREATED_AT,
                CREATED_AT.minusSeconds(1)
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("updatedAt must not be before createdAt");
    }

    @Test
    void shouldHaveSafeToString() {
        String value = musicTrack().toString();

        assertThat(value)
                .contains("MusicTrack")
                .contains(TRACK_ID.toString())
                .contains("Calm Piano")
                .contains("Memory Story")
                .contains("ACTIVE")
                .doesNotContain("music/calm-piano.mp3")
                .doesNotContain("audio/mpeg")
                .doesNotContain("4096");
    }

    private static MusicTrack musicTrack() {
        return new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                0,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                CREATED_AT,
                UPDATED_AT
        );
    }

    private static MusicTrack musicTrackWithTitle(String title) {
        return new MusicTrack(
                TRACK_ID,
                title,
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                0,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                CREATED_AT,
                UPDATED_AT
        );
    }

    private static MusicTrack musicTrackWithArtist(String artist) {
        return new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                artist,
                180,
                MusicTrackStatus.ACTIVE,
                0,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                CREATED_AT,
                UPDATED_AT
        );
    }

    private static MusicTrack musicTrackWithDurationSeconds(
            int durationSeconds
    ) {
        return new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                durationSeconds,
                MusicTrackStatus.ACTIVE,
                0,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                CREATED_AT,
                UPDATED_AT
        );
    }

    private static MusicTrack musicTrackWithSortOrder(int sortOrder) {
        return new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                sortOrder,
                "music/calm-piano.mp3",
                "audio/mpeg",
                4_096L,
                CREATED_AT,
                UPDATED_AT
        );
    }

    private static MusicTrack musicTrackWithStorageKey(String storageKey) {
        return new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                0,
                storageKey,
                "audio/mpeg",
                4_096L,
                CREATED_AT,
                UPDATED_AT
        );
    }

    private static MusicTrack musicTrackWithMimeType(String mimeType) {
        return new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                0,
                "music/calm-piano.mp3",
                mimeType,
                4_096L,
                CREATED_AT,
                UPDATED_AT
        );
    }

    private static MusicTrack musicTrackWithFileSize(long fileSize) {
        return new MusicTrack(
                TRACK_ID,
                "Calm Piano",
                "Memory Story",
                180,
                MusicTrackStatus.ACTIVE,
                0,
                "music/calm-piano.mp3",
                "audio/mpeg",
                fileSize,
                CREATED_AT,
                UPDATED_AT
        );
    }
}
