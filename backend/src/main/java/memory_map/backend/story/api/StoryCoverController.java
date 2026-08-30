package memory_map.backend.story.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.story.application.DownloadStoryCoverUseCase;
import memory_map.backend.story.application.DownloadedStoryCover;
import memory_map.backend.story.application.StoryCoverRepresentation;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;

import java.io.InputStream;
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
    private final CurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;

    public StoryCoverController(
            DownloadStoryCoverUseCase downloadStoryCoverUseCase,
            CurrentAuthenticatedUserProvider currentAuthenticatedUserProvider
    ) {
        this.downloadStoryCoverUseCase = Objects.requireNonNull(
                downloadStoryCoverUseCase,
                "downloadStoryCoverUseCase must not be null"
        );
        this.currentAuthenticatedUserProvider = Objects.requireNonNull(
                currentAuthenticatedUserProvider,
                "currentAuthenticatedUserProvider must not be null"
        );
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
}
