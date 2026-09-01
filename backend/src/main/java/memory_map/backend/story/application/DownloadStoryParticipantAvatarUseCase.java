package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.util.UUID;

public interface DownloadStoryParticipantAvatarUseCase {

    DownloadedStoryParticipantAvatar downloadAvatar(
            AuthenticatedUser authenticatedUser,
            UUID storyId,
            UUID participantUserId
    );

}
