package memory_map.backend.story.api;

import jakarta.validation.Valid;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.story.application.CreateStoryCommand;
import memory_map.backend.story.application.CreateStoryUseCase;
import memory_map.backend.story.domain.Story;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Clock;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/stories")
public class StoryController {

    private final CreateStoryUseCase createStoryUseCase;
    private final CurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;
    private final Clock clock;

    public StoryController(
            CreateStoryUseCase createStoryUseCase,
            CurrentAuthenticatedUserProvider
                    currentAuthenticatedUserProvider,
            Clock clock
    ) {
        this.createStoryUseCase = Objects.requireNonNull(
                createStoryUseCase,
                "createStoryUseCase must not be null"
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
}
