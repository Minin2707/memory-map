package memory_map.backend.story.repository;

import memory_map.backend.story.domain.Story;
import memory_map.backend.story.domain.StoryCoverMetadata;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface StoryRepository {

    Story save(Story story);

    Story update(Story story);

    Optional<Story> findById(UUID id);

    default Optional<Story> findByIdForUpdate(UUID id) {
        throw new UnsupportedOperationException(
                "Story locking read is not supported"
        );
    }

    boolean lockById(UUID id);

    default Story updateCover(UUID id, StoryCoverMetadata cover) {
        throw new UnsupportedOperationException(
                "Story cover update is not supported"
        );
    }

    default Story clearCover(UUID id) {
        throw new UnsupportedOperationException(
                "Story cover clearing is not supported"
        );
    }

    List<Story> findByOwnerId(UUID ownerId);

}
