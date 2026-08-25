package memory_map.backend.music.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.repository.MusicTrackRepository;
import memory_map.backend.story.application.StoryAccessPolicy;
import memory_map.backend.story.application.StoryNotFoundException;
import memory_map.backend.story.application.UserStory;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.UserStoryRepository;

import java.util.Objects;
import java.util.UUID;

public class DefaultResolveStorySoundtrackService
        implements ResolveStorySoundtrackUseCase {

    private final UserStoryRepository userStoryRepository;
    private final MusicTrackRepository musicTrackRepository;
    private final StoryAccessPolicy storyAccessPolicy;

    public DefaultResolveStorySoundtrackService(
            UserStoryRepository userStoryRepository,
            MusicTrackRepository musicTrackRepository,
            StoryAccessPolicy storyAccessPolicy
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
    }

    @Override
    public StorySoundtrack resolveStorySoundtrack(
            AuthenticatedUser authenticatedUser,
            UUID storyId
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

        Story story = userStory.story();
        UUID soundtrackId = story.soundtrackId();

        if (soundtrackId == null) {
            return StorySoundtrack.noMusic();
        }

        MusicTrack selected = musicTrackRepository.findById(soundtrackId)
                .orElseThrow(() -> new IllegalStateException(
                        "Selected Story soundtrack could not be resolved"
                ));

        return StorySoundtrack.selected(selected);
    }
}
