package memory_map.backend.music.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.music.domain.MusicTrack;

import java.util.List;

public interface ListAvailableMusicTracksUseCase {

    List<MusicTrack> listAvailableMusicTracks(
            AuthenticatedUser authenticatedUser
    );
}
