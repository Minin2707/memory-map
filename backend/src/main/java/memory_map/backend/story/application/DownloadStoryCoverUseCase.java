package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.util.UUID;

public interface DownloadStoryCoverUseCase {

    DownloadedStoryCover downloadStoryCover(
            AuthenticatedUser authenticatedUser,
            UUID storyId,
            StoryCoverRepresentation representation
    );
}
