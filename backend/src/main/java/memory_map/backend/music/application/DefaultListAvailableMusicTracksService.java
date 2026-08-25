package memory_map.backend.music.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.repository.MusicTrackRepository;

import java.util.List;
import java.util.Objects;

public class DefaultListAvailableMusicTracksService
        implements ListAvailableMusicTracksUseCase {

    private final MusicTrackRepository musicTrackRepository;

    public DefaultListAvailableMusicTracksService(
            MusicTrackRepository musicTrackRepository
    ) {
        this.musicTrackRepository = Objects.requireNonNull(
                musicTrackRepository,
                "musicTrackRepository must not be null"
        );
    }

    @Override
    public List<MusicTrack> listAvailableMusicTracks(
            AuthenticatedUser authenticatedUser
    ) {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );

        return musicTrackRepository.findActive();
    }
}
