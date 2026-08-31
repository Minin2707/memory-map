package memory_map.backend.story.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.media.image.ImageProcessingInput;
import memory_map.backend.story.application.DownloadStoryCoverUseCase;
import memory_map.backend.story.application.DownloadedStoryCover;
import memory_map.backend.story.application.RemoveStoryCoverCommand;
import memory_map.backend.story.application.RemoveStoryCoverUseCase;
import memory_map.backend.story.application.StoryCoverRepresentation;
import memory_map.backend.story.application.UploadStoryCoverCommand;
import memory_map.backend.story.application.UploadStoryCoverUseCase;
import memory_map.backend.story.application.UserStory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;

import java.io.IOException;
import java.io.InputStream;
import java.time.Clock;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/stories/{storyId}/cover")
@ConditionalOnProperty(
        prefix = "app.storage.minio",
        name = "enabled",
        havingValue = "true"
)
public class StoryCoverController {

    private static final String PRIVATE_STORY_COVER_CACHE_CONTROL =
            "private, no-store";

    private final DownloadStoryCoverUseCase downloadStoryCoverUseCase;
    private final UploadStoryCoverUseCase uploadStoryCoverUseCase;
    private final RemoveStoryCoverUseCase removeStoryCoverUseCase;
    private final CurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;
    private final Clock clock;

    public StoryCoverController(
            DownloadStoryCoverUseCase downloadStoryCoverUseCase,
            UploadStoryCoverUseCase uploadStoryCoverUseCase,
            RemoveStoryCoverUseCase removeStoryCoverUseCase,
            CurrentAuthenticatedUserProvider currentAuthenticatedUserProvider,
            Clock clock
    ) {
        this.downloadStoryCoverUseCase = Objects.requireNonNull(
                downloadStoryCoverUseCase,
                "downloadStoryCoverUseCase must not be null"
        );
        this.uploadStoryCoverUseCase = Objects.requireNonNull(
                uploadStoryCoverUseCase,
                "uploadStoryCoverUseCase must not be null"
        );
        this.removeStoryCoverUseCase = Objects.requireNonNull(
                removeStoryCoverUseCase,
                "removeStoryCoverUseCase must not be null"
        );
        this.currentAuthenticatedUserProvider = Objects.requireNonNull(
                currentAuthenticatedUserProvider,
                "currentAuthenticatedUserProvider must not be null"
        );
        this.clock = Objects.requireNonNull(clock, "clock must not be null");
    }

    @GetMapping("/display/{version}")
    public ResponseEntity<StreamingResponseBody> downloadDisplay(
            @PathVariable UUID storyId,
            @PathVariable long version
    ) {
        return download(storyId, StoryCoverRepresentation.DISPLAY);
    }

    @GetMapping("/thumbnail/{version}")
    public ResponseEntity<StreamingResponseBody> downloadThumbnail(
            @PathVariable UUID storyId,
            @PathVariable long version
    ) {
        return download(storyId, StoryCoverRepresentation.THUMBNAIL);
    }

    @PutMapping(consumes = org.springframework.http.MediaType
            .MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<UserStoryResponse> uploadCover(
            @PathVariable UUID storyId,
            @RequestPart("file") MultipartFile file
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        Instant currentTime = clock.instant();
        UserStory userStory = uploadStoryCoverUseCase.uploadStoryCover(
                new UploadStoryCoverCommand(
                        authenticatedUser,
                        storyId,
                        UUID.randomUUID(),
                        imageInput(file),
                        currentTime
                )
        );

        return ResponseEntity.ok(UserStoryResponse.from(userStory));
    }

    @DeleteMapping
    public ResponseEntity<UserStoryResponse> removeCover(
            @PathVariable UUID storyId
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        UserStory userStory = removeStoryCoverUseCase.removeStoryCover(
                new RemoveStoryCoverCommand(authenticatedUser, storyId)
        );

        return ResponseEntity.ok(UserStoryResponse.from(userStory));
    }

    private ResponseEntity<StreamingResponseBody> download(
            UUID storyId,
            StoryCoverRepresentation representation
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        DownloadedStoryCover cover =
                downloadStoryCoverUseCase.downloadStoryCover(
                        authenticatedUser,
                        storyId,
                        representation
                );
        StreamingResponseBody body = outputStream -> {
            try (InputStream content = cover.content()) {
                content.transferTo(outputStream);
            }
        };

        return ResponseEntity.ok()
                .contentType(org.springframework.http.MediaType.parseMediaType(
                        cover.contentType()
                ))
                .contentLength(cover.contentLength())
                .header(
                        HttpHeaders.CACHE_CONTROL,
                        PRIVATE_STORY_COVER_CACHE_CONTROL
                )
                .body(body);
    }

    private static ImageProcessingInput imageInput(MultipartFile file) {
        try {
            return new ImageProcessingInput(
                    file.getBytes(),
                    file.getContentType()
            );
        } catch (IOException | IllegalArgumentException exception) {
            throw new InvalidStoryCoverRequestException(exception);
        }
    }
}
