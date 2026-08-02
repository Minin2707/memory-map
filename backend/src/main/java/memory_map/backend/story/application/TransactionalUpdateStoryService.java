package memory_map.backend.story.application;

import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.story.repository.UserStoryRepository;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.springframework.transaction.annotation.Transactional;

import java.util.Objects;

public class TransactionalUpdateStoryService
        implements UpdateStoryUseCase {

    private final UserStoryRepository userStoryRepository;
    private final StoryRepository storyRepository;

    public TransactionalUpdateStoryService(
            UserStoryRepository userStoryRepository,
            StoryRepository storyRepository
    ) {
        this.userStoryRepository = Objects.requireNonNull(
                userStoryRepository,
                "userStoryRepository must not be null"
        );
        this.storyRepository = Objects.requireNonNull(
                storyRepository,
                "storyRepository must not be null"
        );
    }

    @Override
    @Transactional
    public UserStory updateStory(UpdateStoryCommand command) {
        Objects.requireNonNull(command, "command must not be null");

        UserStory current = userStoryRepository.findByStoryIdAndUserId(
                command.storyId(),
                command.authenticatedUser().userId()
        ).orElseThrow(StoryNotFoundException::new);

        if (!canUpdate(current.role())) {
            throw new StoryNotFoundException();
        }

        Story existing = current.story();
        Story updated = new Story(
                existing.id(),
                existing.ownerId(),
                updatedTitle(command, existing),
                updatedDescription(command, existing),
                existing.createdAt(),
                command.currentTime()
        );
        Story saved = storyRepository.update(updated);

        return new UserStory(saved, current.role());
    }

    private static boolean canUpdate(StoryRole role) {
        return role == StoryRole.OWNER
                || role == StoryRole.CO_OWNER;
    }

    private static String updatedTitle(
            UpdateStoryCommand command,
            Story existing
    ) {
        if (command.title().isProvided()) {
            return command.title().value();
        }

        return existing.title();
    }

    private static String updatedDescription(
            UpdateStoryCommand command,
            Story existing
    ) {
        if (command.description().isProvided()) {
            return command.description().value();
        }

        return existing.description();
    }
}
