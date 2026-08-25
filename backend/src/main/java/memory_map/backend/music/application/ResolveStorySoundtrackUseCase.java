package memory_map.backend.music.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.util.UUID;

public interface ResolveStorySoundtrackUseCase {

    StorySoundtrack resolveStorySoundtrack(
            AuthenticatedUser authenticatedUser,
            UUID storyId
    );
}
