package memory_map.backend.music.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.music.application.ListAvailableMusicTracksUseCase;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Objects;

@RestController
@RequestMapping("/api/v1/music")
public class MusicController {

    private final ListAvailableMusicTracksUseCase
            listAvailableMusicTracksUseCase;
    private final CurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;

    public MusicController(
            ListAvailableMusicTracksUseCase listAvailableMusicTracksUseCase,
            CurrentAuthenticatedUserProvider
                    currentAuthenticatedUserProvider
    ) {
        this.listAvailableMusicTracksUseCase = Objects.requireNonNull(
                listAvailableMusicTracksUseCase,
                "listAvailableMusicTracksUseCase must not be null"
        );
        this.currentAuthenticatedUserProvider = Objects.requireNonNull(
                currentAuthenticatedUserProvider,
                "currentAuthenticatedUserProvider must not be null"
        );
    }

    @GetMapping("/tracks")
    public List<MusicTrackResponse> getMusicTracks() {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();

        return listAvailableMusicTracksUseCase
                .listAvailableMusicTracks(authenticatedUser)
                .stream()
                .map(MusicTrackResponse::from)
                .toList();
    }
}
