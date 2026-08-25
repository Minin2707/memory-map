package memory_map.backend.music.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.media.storage.StorageKey;
import memory_map.backend.media.storage.StorageService;
import memory_map.backend.media.storage.StoredObject;
import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.domain.MusicTrackStatus;
import memory_map.backend.music.repository.MusicTrackRepository;
import memory_map.backend.story.application.StoryAccessPolicy;
import memory_map.backend.story.application.StoryNotFoundException;
import memory_map.backend.story.application.UserStory;
import memory_map.backend.story.repository.UserStoryRepository;

import java.util.Objects;
import java.util.UUID;

public class DefaultGetStorySoundtrackAudioService
        implements GetStorySoundtrackAudioUseCase {

    private final UserStoryRepository userStoryRepository;
    private final MusicTrackRepository musicTrackRepository;
    private final StoryAccessPolicy storyAccessPolicy;
    private final StorageService storageService;

    public DefaultGetStorySoundtrackAudioService(
            UserStoryRepository userStoryRepository,
            MusicTrackRepository musicTrackRepository,
            StoryAccessPolicy storyAccessPolicy,
            StorageService storageService
    ) {
        this.userStoryRepository = Objects.requireNonNull(
                userStoryRepository,
                "userStoryRepository must not be null"
        );
        this.musicTrackRepository = Objects.requireNonNull(
                musicTrackRepository,
                "musicTrackRepository must not be null"
        );
        this.storyAccessPolicy = Objects.requireNonNull(
                storyAccessPolicy,
                "storyAccessPolicy must not be null"
        );
        this.storageService = Objects.requireNonNull(
                storageService,
                "storageService must not be null"
        );
    }

    @Override
    public StorySoundtrackAudio getStorySoundtrackAudio(
            AuthenticatedUser authenticatedUser,
            UUID storyId,
            StorySoundtrackAudioRange range
    ) {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(storyId, "storyId must not be null");

        UserStory userStory = userStoryRepository.findByStoryIdAndUserId(
                storyId,
                authenticatedUser.userId()
        ).orElseThrow(StoryNotFoundException::new);

        if (!storyAccessPolicy.canReadStory(userStory.role())) {
            throw new StoryNotFoundException();
        }

        UUID soundtrackId = userStory.story().soundtrackId();

        if (soundtrackId == null) {
            throw new StorySoundtrackAudioUnavailableException();
        }

        MusicTrack musicTrack = musicTrackRepository.findById(soundtrackId)
                .orElseThrow(() -> new IllegalStateException(
                        "Selected Story soundtrack could not be resolved"
                ));

        if (musicTrack.status() != MusicTrackStatus.ACTIVE) {
            throw new StorySoundtrackAudioUnavailableException();
        }

        StorageByteRange storageRange = normalizeRange(
                range,
                musicTrack.fileSize()
        );

        StoredObject storedObject = readStorageObject(
                musicTrack,
                storageRange
        );

        return new StorySoundtrackAudio(
                storedObject.content(),
                musicTrack.mimeType(),
                contentLength(musicTrack, storageRange),
                musicTrack.fileSize(),
                storageRange
        );
    }

    private StoredObject readStorageObject(
            MusicTrack musicTrack,
            StorageByteRange range
    ) {
        StorageKey storageKey = new StorageKey(musicTrack.storageKey());

        if (range == null) {
            return storageService.read(storageKey);
        }

        return storageService.readRange(storageKey, range);
    }

    private static long contentLength(
            MusicTrack musicTrack,
            StorageByteRange range
    ) {
        if (range == null) {
            return musicTrack.fileSize();
        }

        return range.length();
    }

    private static StorageByteRange normalizeRange(
            StorySoundtrackAudioRange range,
            long totalLength
    ) {
        if (range == null) {
            return null;
        }

        return range.normalize(totalLength);
    }
}
