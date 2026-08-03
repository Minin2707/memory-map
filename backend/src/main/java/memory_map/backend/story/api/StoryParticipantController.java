package memory_map.backend.story.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.story.application.GetStoryParticipantsUseCase;
import memory_map.backend.story.application.LeaveStoryCommand;
import memory_map.backend.story.application.LeaveStoryUseCase;
import memory_map.backend.story.application.RemoveStoryParticipantCommand;
import memory_map.backend.story.application.RemoveStoryParticipantUseCase;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Objects;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/stories/{storyId}/participants")
public class StoryParticipantController {

    private final GetStoryParticipantsUseCase getStoryParticipantsUseCase;
    private final LeaveStoryUseCase leaveStoryUseCase;
    private final RemoveStoryParticipantUseCase removeStoryParticipantUseCase;
    private final CurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;

    public StoryParticipantController(
            GetStoryParticipantsUseCase getStoryParticipantsUseCase,
            LeaveStoryUseCase leaveStoryUseCase,
            RemoveStoryParticipantUseCase removeStoryParticipantUseCase,
            CurrentAuthenticatedUserProvider currentAuthenticatedUserProvider
    ) {
        this.getStoryParticipantsUseCase = Objects.requireNonNull(
                getStoryParticipantsUseCase,
                "getStoryParticipantsUseCase must not be null"
        );
        this.leaveStoryUseCase = Objects.requireNonNull(
                leaveStoryUseCase,
                "leaveStoryUseCase must not be null"
        );
        this.removeStoryParticipantUseCase = Objects.requireNonNull(
                removeStoryParticipantUseCase,
                "removeStoryParticipantUseCase must not be null"
        );
        this.currentAuthenticatedUserProvider = Objects.requireNonNull(
                currentAuthenticatedUserProvider,
                "currentAuthenticatedUserProvider must not be null"
        );
    }

    @GetMapping
    public List<StoryParticipantResponse> getParticipants(
            @PathVariable UUID storyId
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();

        return getStoryParticipantsUseCase.getParticipants(
                authenticatedUser,
                storyId
        )
                .stream()
                .map(StoryParticipantResponse::from)
                .toList();
    }

    @DeleteMapping("/me")
    public ResponseEntity<Void> leaveStory(
            @PathVariable UUID storyId
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();

        leaveStoryUseCase.leaveStory(
                new LeaveStoryCommand(authenticatedUser, storyId)
        );

        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{participantUserId}")
    public ResponseEntity<Void> removeParticipant(
            @PathVariable UUID storyId,
            @PathVariable UUID participantUserId
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();

        removeStoryParticipantUseCase.removeParticipant(
                new RemoveStoryParticipantCommand(
                        authenticatedUser,
                        storyId,
                        participantUserId
                )
        );

        return ResponseEntity.noContent().build();
    }
}
