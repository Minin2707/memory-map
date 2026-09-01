package memory_map.backend.story.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.story.application.DownloadStoryParticipantAvatarUseCase;
import memory_map.backend.story.application.DownloadedStoryParticipantAvatar;
import memory_map.backend.story.application.GetStoryParticipantsUseCase;
import memory_map.backend.story.application.LeaveStoryCommand;
import memory_map.backend.story.application.LeaveStoryUseCase;
import memory_map.backend.story.application.RemoveStoryParticipantCommand;
import memory_map.backend.story.application.RemoveStoryParticipantUseCase;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;

import java.io.InputStream;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/stories/{storyId}/participants")
public class StoryParticipantController {

    private static final String PRIVATE_PARTICIPANT_AVATAR_CACHE_CONTROL =
            "private, no-store";

    private final GetStoryParticipantsUseCase getStoryParticipantsUseCase;
    private final DownloadStoryParticipantAvatarUseCase
            downloadStoryParticipantAvatarUseCase;
    private final LeaveStoryUseCase leaveStoryUseCase;
    private final RemoveStoryParticipantUseCase removeStoryParticipantUseCase;
    private final CurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;

    public StoryParticipantController(
            GetStoryParticipantsUseCase getStoryParticipantsUseCase,
            DownloadStoryParticipantAvatarUseCase
                    downloadStoryParticipantAvatarUseCase,
            LeaveStoryUseCase leaveStoryUseCase,
            RemoveStoryParticipantUseCase removeStoryParticipantUseCase,
            CurrentAuthenticatedUserProvider currentAuthenticatedUserProvider
    ) {
        this.getStoryParticipantsUseCase = Objects.requireNonNull(
                getStoryParticipantsUseCase,
                "getStoryParticipantsUseCase must not be null"
        );
        this.downloadStoryParticipantAvatarUseCase =
                Objects.requireNonNull(
                        downloadStoryParticipantAvatarUseCase,
                        "downloadStoryParticipantAvatarUseCase "
                                + "must not be null"
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

    @GetMapping("/{participantUserId}/avatar/{version}")
    public ResponseEntity<StreamingResponseBody> downloadParticipantAvatar(
            @PathVariable UUID storyId,
            @PathVariable UUID participantUserId,
            @PathVariable String version
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        DownloadedStoryParticipantAvatar avatar =
                downloadStoryParticipantAvatarUseCase.downloadAvatar(
                        authenticatedUser,
                        storyId,
                        participantUserId
                );
        StreamingResponseBody body = outputStream -> {
            try (InputStream content = avatar.content()) {
                content.transferTo(outputStream);
            }
        };

        return ResponseEntity.ok()
                .contentType(org.springframework.http.MediaType.parseMediaType(
                        avatar.contentType()
                ))
                .contentLength(avatar.contentLength())
                .header(
                        HttpHeaders.CACHE_CONTROL,
                        PRIVATE_PARTICIPANT_AVATAR_CACHE_CONTROL
                )
                .body(body);
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
