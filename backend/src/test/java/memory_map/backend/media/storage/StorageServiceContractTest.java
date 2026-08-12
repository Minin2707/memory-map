package memory_map.backend.media.storage;

import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.util.HashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StorageServiceContractTest {

    private static final StorageKey STORAGE_KEY =
            new StorageKey("media/id/display");

    @Test
    void shouldStoreReadAndDeleteThroughContract() throws Exception {
        FakeStorageService service = new FakeStorageService();
        StorageObjectWrite object = new StorageObjectWrite(
                STORAGE_KEY,
                new byte[] {1, 2, 3},
                "image/jpeg"
        );

        service.store(object);
        StoredObject stored = service.read(STORAGE_KEY);

        assertThat(stored.content().readAllBytes()).containsExactly(1, 2, 3);
        assertThat(stored.contentLength()).isEqualTo(3L);
        assertThat(stored.contentType()).isEqualTo("image/jpeg");

        service.delete(STORAGE_KEY);

        assertThatThrownBy(() -> service.read(STORAGE_KEY))
                .isInstanceOf(StorageObjectNotFoundException.class);
    }

    @Test
    void shouldTreatDeleteMissingObjectAsSuccessfulNoOp() {
        FakeStorageService service = new FakeStorageService();

        assertThatCode(() -> service.delete(STORAGE_KEY))
                .doesNotThrowAnyException();
        assertThatCode(() -> service.delete(STORAGE_KEY))
                .doesNotThrowAnyException();
    }

    private static final class FakeStorageService implements StorageService {

        private final Map<StorageKey, StorageObjectWrite> objects =
                new HashMap<>();

        @Override
        public void store(StorageObjectWrite object) {
            objects.put(object.storageKey(), object);
        }

        @Override
        public StoredObject read(StorageKey storageKey) {
            StorageObjectWrite object = objects.get(storageKey);

            if (object == null) {
                throw new StorageObjectNotFoundException();
            }

            return new StoredObject(
                    new ByteArrayInputStream(object.content()),
                    object.contentLength(),
                    object.contentType()
            );
        }

        @Override
        public void delete(StorageKey storageKey) {
            objects.remove(storageKey);
        }
    }
}
