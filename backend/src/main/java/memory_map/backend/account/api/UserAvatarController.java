package memory_map.backend.account.api;

import memory_map.backend.account.application.CurrentUserAvatarUseCase;
import memory_map.backend.account.application.DownloadCurrentUserAvatarCommand;
import memory_map.backend.account.application.DownloadedUserAvatar;
import memory_map.backend.account.application.RemoveCurrentUserAvatarCommand;
import memory_map.backend.account.application.UploadCurrentUserAvatarCommand;
import memory_map.backend.auth.api.AuthUserResponse;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.media.image.ImageProcessingInput;
import memory_map.backend.user.domain.User;
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
@RequestMapping("/api/v1/me/avatar")
@ConditionalOnProperty(
        prefix = "app.storage.minio",
        name = "enabled",
        havingValue = "true"
)
public class UserAvatarController {

    private static final String PRIVATE_AVATAR_CACHE_CONTROL =
            "private, no-store";

    private final CurrentUserAvatarUseCase avatarUseCase;
    private final CurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;
    private final Clock clock;

    public UserAvatarController(
            CurrentUserAvatarUseCase avatarUseCase,
            CurrentAuthenticatedUserProvider currentAuthenticatedUserProvider,
            Clock clock
    ) {
        this.avatarUseCase = Objects.requireNonNull(
                avatarUseCase,
                "avatarUseCase must not be null"
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

    @PutMapping(
            consumes = org.springframework.http.MediaType
                    .MULTIPART_FORM_DATA_VALUE
    )
    public ResponseEntity<AuthUserResponse> uploadAvatar(
            @RequestPart("file") MultipartFile file
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        Instant currentTime = clock.instant();
        User user = avatarUseCase.uploadAvatar(
                new UploadCurrentUserAvatarCommand(
                        authenticatedUser,
                        UUID.randomUUID(),
                        imageInput(file),
                        currentTime
                )
        );

        return ResponseEntity.ok(AuthUserResponse.from(user));
    }

    @GetMapping
    public ResponseEntity<StreamingResponseBody> downloadAvatar() {
        return download();
    }

    @GetMapping("/{version}")
    public ResponseEntity<StreamingResponseBody> downloadVersionedAvatar(
            @PathVariable String version
    ) {
        return download();
    }

    @DeleteMapping
    public ResponseEntity<AuthUserResponse> removeAvatar() {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        User user = avatarUseCase.removeAvatar(
                new RemoveCurrentUserAvatarCommand(
                        authenticatedUser,
                        clock.instant()
                )
        );

        return ResponseEntity.ok(AuthUserResponse.from(user));
    }

    private ResponseEntity<StreamingResponseBody> download() {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        DownloadedUserAvatar avatar = avatarUseCase.downloadAvatar(
                new DownloadCurrentUserAvatarCommand(authenticatedUser)
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
                .header(HttpHeaders.CACHE_CONTROL, PRIVATE_AVATAR_CACHE_CONTROL)
                .body(body);
    }

    private static ImageProcessingInput imageInput(MultipartFile file) {
        try {
            return new ImageProcessingInput(
                    file.getBytes(),
                    file.getContentType()
            );
        } catch (IOException | IllegalArgumentException exception) {
            throw new InvalidAvatarRequestException(exception);
        }
    }
}
