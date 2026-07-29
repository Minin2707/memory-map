package memory_map.backend.media.repository;

import memory_map.backend.media.domain.MediaFile;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface MediaFileRepository {

    Optional<MediaFile> findById(UUID id);

    List<MediaFile> findByMemoryId(UUID memoryId);

    void save(MediaFile mediaFile);

    void delete(UUID id);

}
