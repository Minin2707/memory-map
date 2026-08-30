package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.domain.StoryCoverMetadata;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;

import java.util.Objects;
import java.util.UUID;

public class DefaultDownloadStoryCoverService
        implements DownloadStoryCoverUseCase {

    private final StoryRepository storyRepository;
    private final StoryParticipantRepository storyParticipantRepository;
    private final StorageService storageService;
    private final StoryAccessPolicy accessPolicy;

    public DefaultDownloadStoryCoverService(
            StoryRepository storyRepository,
            StoryParticipantRepository storyParticipantRepository,
            StorageService storageService,
            StoryAccessPolicy accessPolicy
    ) {
        this.storyRepository = Objects.requireNonNull(
                storyRepository,
                "storyRepository must not be null"
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
    public DownloadedStoryCover downloadStoryCover(
            AuthenticatedUser authenticatedUser,
            UUID storyId,
            StoryCoverRepresentation representation
    ) {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(
                representation,
                "representation must not be null"
        );

        Story story = storyRepository.findById(storyId)
                .orElseThrow(StoryNotFoundException::new);
        StoryParticipant participant = storyParticipantRepository.find(
                storyId,
                authenticatedUser.userId()
        ).orElseThrow(StoryNotFoundException::new);

        if (!accessPolicy.canReadStory(participant.role())) {
            throw new StoryNotFoundException();
        }

        StoryCoverMetadata cover = story.cover();
        if (cover == null) {
            throw new StoryNotFoundException();
        }

        StoredObject storedObject = storageService.read(new StorageKey(
                storageKey(cover, representation)
        ));

        return new DownloadedStoryCover(
                storedObject.content(),
                contentLength(cover, representation),
                cover.mimeType()
        );
    }

    private static String storageKey(
            StoryCoverMetadata cover,
            StoryCoverRepresentation representation
    ) {
        return switch (representation) {
            case DISPLAY -> cover.displayStorageKey();
            case THUMBNAIL -> cover.thumbnailStorageKey();
        };
    }

    private static long contentLength(
            StoryCoverMetadata cover,
            StoryCoverRepresentation representation
    ) {
        return switch (representation) {
            case DISPLAY -> cover.displayFileSize();
            case THUMBNAIL -> cover.thumbnailFileSize();
        };
    }
}
