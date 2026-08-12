package memory_map.backend.media.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.media.application.DeleteMediaCommand;
import memory_map.backend.media.application.DeleteMediaUseCase;
import memory_map.backend.media.application.DownloadMediaUseCase;
import memory_map.backend.media.application.DownloadedMedia;
import memory_map.backend.media.application.ListMemoryMediaUseCase;
import memory_map.backend.media.application.MediaRepresentation;
import memory_map.backend.media.application.UploadPhotoCommand;
import memory_map.backend.media.application.UploadPhotoUseCase;
import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.image.ImageProcessingInput;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;

import java.io.IOException;
import java.io.InputStream;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
@ConditionalOnProperty(
        prefix = "app.storage.minio",
        name = "enabled",
        havingValue = "true"
)
public class MediaController {

    private final UploadPhotoUseCase uploadPhotoUseCase;
    private final ListMemoryMediaUseCase listMemoryMediaUseCase;
    private final DownloadMediaUseCase downloadMediaUseCase;
    private final DeleteMediaUseCase deleteMediaUseCase;
    private final CurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;
    private final Clock clock;

    public MediaController(
            UploadPhotoUseCase uploadPhotoUseCase,
            ListMemoryMediaUseCase listMemoryMediaUseCase,
            DownloadMediaUseCase downloadMediaUseCase,
            DeleteMediaUseCase deleteMediaUseCase,
            CurrentAuthenticatedUserProvider
                    currentAuthenticatedUserProvider,
            Clock clock
    ) {
        this.uploadPhotoUseCase = Objects.requireNonNull(
                uploadPhotoUseCase,
                "uploadPhotoUseCase must not be null"
        );
        this.listMemoryMediaUseCase = Objects.requireNonNull(
                listMemoryMediaUseCase,
                "listMemoryMediaUseCase must not be null"
        );
        this.downloadMediaUseCase = Objects.requireNonNull(
                downloadMediaUseCase,
                "downloadMediaUseCase must not be null"
        );
        this.deleteMediaUseCase = Objects.requireNonNull(
                deleteMediaUseCase,
                "deleteMediaUseCase must not be null"
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

    @PostMapping(
            path = "/memories/{memoryId}/media",
            consumes = org.springframework.http.MediaType
                    .MULTIPART_FORM_DATA_VALUE
    )
    public ResponseEntity<MediaResponse> uploadPhoto(
            @PathVariable UUID memoryId,
            @RequestPart("file") MultipartFile file
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        UUID mediaId = UUID.randomUUID();
        Instant currentTime = clock.instant();

        MediaFile mediaFile = uploadPhotoUseCase.uploadPhoto(
                new UploadPhotoCommand(
                        authenticatedUser,
                        memoryId,
                        mediaId,
                        imageInput(file),
                        currentTime
                )
        );

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(MediaResponse.from(mediaFile));
    }

    @PostMapping(
            path = "/memories/{memoryId}/media",
            consumes = org.springframework.http.MediaType
                    .APPLICATION_JSON_VALUE
    )
    public ResponseEntity<MediaResponse> rejectJsonPhotoUpload() {
        throw new InvalidPhotoRequestException();
    }

    @GetMapping("/memories/{memoryId}/media")
    public List<MediaResponse> listMedia(@PathVariable UUID memoryId) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();

        return listMemoryMediaUseCase.listMedia(
                authenticatedUser,
                memoryId
        ).stream().map(MediaResponse::from).toList();
    }

    @GetMapping("/media/{mediaId}/thumbnail")
    public ResponseEntity<StreamingResponseBody> downloadThumbnail(
            @PathVariable UUID mediaId
    ) {
        return download(mediaId, MediaRepresentation.THUMBNAIL);
    }

    @GetMapping("/media/{mediaId}/display")
    public ResponseEntity<StreamingResponseBody> downloadDisplay(
            @PathVariable UUID mediaId
    ) {
        return download(mediaId, MediaRepresentation.DISPLAY);
    }

    @DeleteMapping("/media/{mediaId}")
    public ResponseEntity<Void> deleteMedia(@PathVariable UUID mediaId) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();

        deleteMediaUseCase.deleteMedia(new DeleteMediaCommand(
                authenticatedUser,
                mediaId
        ));

        return ResponseEntity.noContent().build();
    }

    private static ImageProcessingInput imageInput(MultipartFile file) {
        try {
            return new ImageProcessingInput(
                    file.getBytes(),
                    file.getContentType()
            );
        } catch (IOException | IllegalArgumentException exception) {
            throw new InvalidPhotoRequestException(exception);
        }
    }

    private ResponseEntity<StreamingResponseBody> download(
            UUID mediaId,
            MediaRepresentation representation
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        DownloadedMedia downloadedMedia = downloadMediaUseCase.downloadMedia(
                authenticatedUser,
                mediaId,
                representation
        );
        StreamingResponseBody body = outputStream -> {
            try (InputStream content = downloadedMedia.content()) {
                content.transferTo(outputStream);
            }
        };

        return ResponseEntity.ok()
                .contentType(org.springframework.http.MediaType.parseMediaType(
                        downloadedMedia.contentType()
                ))
                .contentLength(downloadedMedia.contentLength())
                .body(body);
    }
}
