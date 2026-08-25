package memory_map.backend.music.application;

import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.domain.MusicTrackStatus;
import memory_map.backend.music.repository.MusicTrackRepository;
import memory_map.backend.story.application.StoryAccessPolicy;
import memory_map.backend.story.application.StoryNotFoundException;
import memory_map.backend.story.application.UserStory;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.story.repository.UserStoryRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Objects;

public class TransactionalSetStorySoundtrackService
        implements SetStorySoundtrackUseCase {

    private final UserStoryRepository userStoryRepository;
    private final StoryRepository storyRepository;
    private final MusicTrackRepository musicTrackRepository;
    private final StoryAccessPolicy storyAccessPolicy;

    public TransactionalSetStorySoundtrackService(
            UserStoryRepository userStoryRepository,
            StoryRepository storyRepository,
            MusicTrackRepository musicTrackRepository,
            StoryAccessPolicy storyAccessPolicy
    ) {
        this.userStoryRepository = Objects.requireNonNull(
                userStoryRepository,
                "userStoryRepository must not be null"
        );
        this.storyRepository = Objects.requireNonNull(
                storyRepository,
                "storyRepository must not be null"
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
    @Transactional
    public StorySoundtrack setStorySoundtrack(
            SetStorySoundtrackCommand command
    ) {
        Objects.requireNonNull(command, "command must not be null");

        UserStory current = userStoryRepository.findByStoryIdAndUserId(
                command.storyId(),
                command.authenticatedUser().userId()
        ).orElseThrow(StoryNotFoundException::new);

        if (!storyAccessPolicy.canChangeStorySoundtrack(current.role())) {
            throw new StoryNotFoundException();
        }

        MusicTrack selected = musicTrackRepository.findById(
                command.musicTrackId()
        ).orElseThrow(StorySoundtrackUnavailableException::new);

        if (selected.status() != MusicTrackStatus.ACTIVE) {
            throw new StorySoundtrackUnavailableException();
        }

        Story existing = current.story();

        if (command.musicTrackId().equals(existing.soundtrackId())) {
            return StorySoundtrack.selected(selected);
        }

        Story updated = new Story(
                existing.id(),
                existing.ownerId(),
                existing.title(),
                existing.description(),
                selected.id(),
                existing.createdAt(),
                command.currentTime()
        );
        storyRepository.update(updated);

        return StorySoundtrack.selected(selected);
    }
}
