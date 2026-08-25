package memory_map.backend.music.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.util.UUID;

public interface GetStorySoundtrackAudioUseCase {

    StorySoundtrackAudio getStorySoundtrackAudio(
            AuthenticatedUser authenticatedUser,
            UUID storyId,
            StorySoundtrackAudioRange range
    );
}
