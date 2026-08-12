package memory_map.backend.media.storage;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class StorageExceptionTest {

    @Test
    void shouldHaveSafeStorageExceptionMessage() {
        StorageException exception = new StorageException();

        assertThat(exception)
                .hasMessage("Storage operation failed");
    }

    @Test
    void shouldHaveSafeStorageObjectNotFoundMessage() {
        StorageObjectNotFoundException exception =
                new StorageObjectNotFoundException();

        assertThat(exception)
                .isInstanceOf(StorageException.class)
                .hasMessage("Storage object was not found");
    }
}
