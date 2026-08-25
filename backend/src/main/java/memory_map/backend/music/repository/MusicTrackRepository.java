package memory_map.backend.music.repository;

import memory_map.backend.music.domain.MusicTrack;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface MusicTrackRepository {

    Optional<MusicTrack> findById(UUID id);

    List<MusicTrack> findActive();

}
