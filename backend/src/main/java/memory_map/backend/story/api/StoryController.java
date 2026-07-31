package memory_map.backend.story.api;

import jakarta.validation.Valid;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.story.application.CreateStoryCommand;
import memory_map.backend.story.application.CreateStoryUseCase;
import memory_map.backend.story.application.GetStoriesUseCase;
import memory_map.backend.story.application.GetStoryUseCase;
import memory_map.backend.story.domain.Story;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/stories")
public class StoryController {

    private final CreateStoryUseCase createStoryUseCase;
    private final GetStoriesUseCase getStoriesUseCase;
    private final GetStoryUseCase getStoryUseCase;
    private final CurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;
    private final Clock clock;

    public StoryController(
            CreateStoryUseCase createStoryUseCase,
            GetStoriesUseCase getStoriesUseCase,
            GetStoryUseCase getStoryUseCase,
            CurrentAuthenticatedUserProvider
                    currentAuthenticatedUserProvider,
            Clock clock
    ) {
        this.createStoryUseCase = Objects.requireNonNull(
                createStoryUseCase,
                "createStoryUseCase must not be null"
        );
        this.getStoriesUseCase = Objects.requireNonNull(
                getStoriesUseCase,
                "getStoriesUseCase must not be null"
        );
        this.getStoryUseCase = Objects.requireNonNull(
                getStoryUseCase,
                "getStoryUseCase must not be null"
        );
        this.currentAuthenticatedUserProvider = Objects.requireNonNull(
                currentAuthenticatedUserProvider,
                "currentAuthenticatedUserProvider must not be null"
        );
        this.clock = Objects.requireNonNull(
                clock,
                "clock must not be null"
        );
    }

    @PostMapping
    public ResponseEntity<StoryResponse> create(
            @Valid @RequestBody CreateStoryRequest request
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        UUID storyId = UUID.randomUUID();
        Instant currentTime = clock.instant();

        Story story = createStoryUseCase.create(
                new CreateStoryCommand(
                        authenticatedUser,
                        storyId,
                        request.title(),
                        request.description(),
                        currentTime
                )
        );

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(StoryResponse.from(story));
    }

    @GetMapping
    public List<UserStoryResponse> getStories() {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();

        return getStoriesUseCase.getStories(authenticatedUser)
                .stream()
                .map(UserStoryResponse::from)
                .toList();
    }

    @GetMapping("/{storyId}")
    public UserStoryResponse getStory(
            @PathVariable UUID storyId
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();

        return UserStoryResponse.from(
                getStoryUseCase.getStory(authenticatedUser, storyId)
        );
    }
}
