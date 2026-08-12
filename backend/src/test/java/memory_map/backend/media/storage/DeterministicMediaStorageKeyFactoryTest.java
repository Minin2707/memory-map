package memory_map.backend.media.storage;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DeterministicMediaStorageKeyFactoryTest {

    private final MediaStorageKeyFactory factory =
            new DeterministicMediaStorageKeyFactory();

    @Test
    void shouldCreateDeterministicDisplayAndThumbnailKeys() {
        UUID mediaId =
                UUID.fromString("00000000-0000-0000-0000-000000000001");

        MediaStorageKeys keys = factory.keysFor(mediaId);

        assertThat(keys.display().value())
                .isEqualTo("media/" + mediaId + "/display");
        assertThat(keys.thumbnail().value())
                .isEqualTo("media/" + mediaId + "/thumbnail");
        assertThat(keys.display()).isNotEqualTo(keys.thumbnail());
    }

    @Test
    void shouldReturnSameKeysForSameMediaId() {
        UUID mediaId =
                UUID.fromString("00000000-0000-0000-0000-000000000001");

        assertThat(factory.keysFor(mediaId))
                .isEqualTo(factory.keysFor(mediaId));
    }

    @Test
    void shouldReturnDifferentKeysForDifferentMediaIds() {
        MediaStorageKeys first = factory.keysFor(
                UUID.fromString("00000000-0000-0000-0000-000000000001")
        );
        MediaStorageKeys second = factory.keysFor(
                UUID.fromString("00000000-0000-0000-0000-000000000002")
        );

        assertThat(first).isNotEqualTo(second);
    }

    @Test
    void shouldRejectNullMediaId() {
        assertThatThrownBy(() -> factory.keysFor(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("mediaId must not be null");
    }

    @Test
    void shouldRejectEqualMediaStorageKeys() {
        StorageKey storageKey = new StorageKey("media/id/display");

        assertThatThrownBy(() -> new MediaStorageKeys(storageKey, storageKey))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("display and thumbnail storage keys must differ");
    }

    @Test
    void shouldHaveSafeToString() {
        UUID mediaId =
                UUID.fromString("00000000-0000-0000-0000-000000000001");
        MediaStorageKeys keys = factory.keysFor(mediaId);

        assertThat(keys.toString())
                .isEqualTo("MediaStorageKeys[hasDisplay=true, hasThumbnail=true]")
                .doesNotContain(mediaId.toString())
                .doesNotContain(keys.display().value())
                .doesNotContain(keys.thumbnail().value());
    }
}
