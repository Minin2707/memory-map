package memory_map.backend.music.application;

import memory_map.backend.media.storage.StorageService;
import memory_map.backend.music.repository.MusicTrackRepository;
import memory_map.backend.story.application.StoryAccessPolicy;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.story.repository.UserStoryRepository;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MusicApplicationConfiguration {

    @Bean
    public StoryAccessPolicy storyAccessPolicy() {
        return new StoryAccessPolicy();
    }

    @Bean
    public ListAvailableMusicTracksUseCase listAvailableMusicTracksUseCase(
            MusicTrackRepository musicTrackRepository
    ) {
        return new DefaultListAvailableMusicTracksService(
                musicTrackRepository
        );
    }

    @Bean
    public ResolveStorySoundtrackUseCase resolveStorySoundtrackUseCase(
            UserStoryRepository userStoryRepository,
            MusicTrackRepository musicTrackRepository,
            StoryAccessPolicy storyAccessPolicy
    ) {
        return new DefaultResolveStorySoundtrackService(
                userStoryRepository,
                musicTrackRepository,
                storyAccessPolicy
        );
    }

    @Bean
    public SetStorySoundtrackUseCase setStorySoundtrackUseCase(
            UserStoryRepository userStoryRepository,
            StoryRepository storyRepository,
            MusicTrackRepository musicTrackRepository,
            StoryAccessPolicy storyAccessPolicy
    ) {
        return new TransactionalSetStorySoundtrackService(
                userStoryRepository,
                storyRepository,
                musicTrackRepository,
                storyAccessPolicy
        );
    }

    @Bean
    public RemoveStorySoundtrackUseCase removeStorySoundtrackUseCase(
            UserStoryRepository userStoryRepository,
            StoryRepository storyRepository,
            StoryAccessPolicy storyAccessPolicy
    ) {
        return new TransactionalRemoveStorySoundtrackService(
                userStoryRepository,
                storyRepository,
                storyAccessPolicy
        );
    }

    @Bean
    public GetStorySoundtrackAudioUseCase getStorySoundtrackAudioUseCase(
            UserStoryRepository userStoryRepository,
            MusicTrackRepository musicTrackRepository,
            StoryAccessPolicy storyAccessPolicy,
            StorageService storageService
    ) {
        return new DefaultGetStorySoundtrackAudioService(
                userStoryRepository,
                musicTrackRepository,
                storyAccessPolicy,
                storageService
        );
    }
}
