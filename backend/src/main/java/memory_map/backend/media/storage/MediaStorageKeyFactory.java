package memory_map.backend.media.storage;

import java.util.UUID;

public interface MediaStorageKeyFactory {

    MediaStorageKeys keysFor(UUID mediaId);
}
