package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;

import java.util.Objects;
import java.util.UUID;

public class DefaultDownloadStoryParticipantAvatarService
        implements DownloadStoryParticipantAvatarUseCase {

    private final UserRepository userRepository;
    private final StoryParticipantRepository storyParticipantRepository;
    private final StorageService storageService;
    private final StoryAccessPolicy accessPolicy;

    public DefaultDownloadStoryParticipantAvatarService(
            UserRepository userRepository,
            StoryParticipantRepository storyParticipantRepository,
            StorageService storageService,
            StoryAccessPolicy accessPolicy
    ) {
        this.userRepository = Objects.requireNonNull(
                userRepository,
                "userRepository must not be null"
        );
        this.storyParticipantRepository = Objects.requireNonNull(
                storyParticipantRepository,
                "storyParticipantRepository must not be null"
        );
        this.storageService = Objects.requireNonNull(
                storageService,
                "storageService must not be null"
        );
        this.accessPolicy = Objects.requireNonNull(
                accessPolicy,
                "accessPolicy must not be null"
        );
    }

    @Override
    public DownloadedStoryParticipantAvatar downloadAvatar(
            AuthenticatedUser authenticatedUser,
            UUID storyId,
            UUID participantUserId
    ) {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(
                participantUserId,
                "participantUserId must not be null"
        );

        StoryParticipant requester = storyParticipantRepository.find(
                storyId,
                authenticatedUser.userId()
        ).orElseThrow(StoryNotFoundException::new);

        if (!accessPolicy.canReadStory(requester.role())) {
            throw new StoryNotFoundException();
        }

        storyParticipantRepository.find(storyId, participantUserId)
                .orElseThrow(StoryNotFoundException::new);

        User participantUser = userRepository.findById(participantUserId)
                .filter(user -> !user.isDeleted())
                .filter(User::hasCustomAvatar)
                .orElseThrow(StoryNotFoundException::new);

        StoredObject storedObject = storageService.read(new StorageKey(
                participantUser.customAvatarStorageKey()
        ));

        return new DownloadedStoryParticipantAvatar(
                storedObject.content(),
                storedObject.contentLength(),
                storedObject.contentType()
        );
    }
}
