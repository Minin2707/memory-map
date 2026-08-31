package memory_map.backend.story.application;

import java.util.UUID;

public interface StoryCoverStorageKeyFactory {

    StoryCoverStorageKeys keysFor(UUID storyId, UUID coverObjectId);
}
