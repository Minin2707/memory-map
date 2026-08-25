package memory_map.backend.story.api;

import jakarta.validation.Valid;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.media.storage.StorageByteRange;
import memory_map.backend.music.application.GetStorySoundtrackAudioUseCase;
import memory_map.backend.music.application.RemoveStorySoundtrackCommand;
import memory_map.backend.music.application.RemoveStorySoundtrackUseCase;
import memory_map.backend.music.application.ResolveStorySoundtrackUseCase;
import memory_map.backend.music.application.SetStorySoundtrackUseCase;
import memory_map.backend.music.application.StorySoundtrackAudio;
import memory_map.backend.music.application.StorySoundtrackAudioRange;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;

import java.io.InputStream;
import java.time.Clock;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/stories/{storyId}/soundtrack")
public class StorySoundtrackController {

    private final ResolveStorySoundtrackUseCase
            resolveStorySoundtrackUseCase;
    private final SetStorySoundtrackUseCase setStorySoundtrackUseCase;
    private final RemoveStorySoundtrackUseCase removeStorySoundtrackUseCase;
    private final GetStorySoundtrackAudioUseCase
            getStorySoundtrackAudioUseCase;
    private final CurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;
    private final Clock clock;
    private static final String ACCEPT_RANGES = "Accept-Ranges";

    public StorySoundtrackController(
            ResolveStorySoundtrackUseCase resolveStorySoundtrackUseCase,
            SetStorySoundtrackUseCase setStorySoundtrackUseCase,
            RemoveStorySoundtrackUseCase removeStorySoundtrackUseCase,
            GetStorySoundtrackAudioUseCase getStorySoundtrackAudioUseCase,
            CurrentAuthenticatedUserProvider
                    currentAuthenticatedUserProvider,
            Clock clock
    ) {
        this.resolveStorySoundtrackUseCase = Objects.requireNonNull(
                resolveStorySoundtrackUseCase,
                "resolveStorySoundtrackUseCase must not be null"
        );
        this.setStorySoundtrackUseCase = Objects.requireNonNull(
                setStorySoundtrackUseCase,
                "setStorySoundtrackUseCase must not be null"
        );
        this.removeStorySoundtrackUseCase = Objects.requireNonNull(
                removeStorySoundtrackUseCase,
                "removeStorySoundtrackUseCase must not be null"
        );
        this.getStorySoundtrackAudioUseCase = Objects.requireNonNull(
                getStorySoundtrackAudioUseCase,
                "getStorySoundtrackAudioUseCase must not be null"
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

    @GetMapping("/audio")
    public ResponseEntity<StreamingResponseBody> getStorySoundtrackAudio(
            @PathVariable UUID storyId,
            @RequestHeader(
                    value = HttpHeaders.RANGE,
                    required = false
            ) String rangeHeader
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        StorySoundtrackAudioRange requestedRange =
                StorySoundtrackRangeParser.parse(rangeHeader);
        StorySoundtrackAudio audio =
                getStorySoundtrackAudioUseCase.getStorySoundtrackAudio(
                        authenticatedUser,
                        storyId,
                        requestedRange
                );
        StreamingResponseBody body = outputStream -> {
            try (InputStream content = audio.content()) {
                content.transferTo(outputStream);
            }
        };

        ResponseEntity.BodyBuilder response = audio.range() == null
                ? ResponseEntity.ok()
                : ResponseEntity.status(HttpStatus.PARTIAL_CONTENT);

        response
                .contentType(org.springframework.http.MediaType
                        .parseMediaType(audio.contentType()))
                .contentLength(audio.contentLength())
                .header(ACCEPT_RANGES, "bytes")
                .header(HttpHeaders.CACHE_CONTROL, "private, no-store");

        if (audio.range() != null) {
            response.header(
                    HttpHeaders.CONTENT_RANGE,
                    contentRange(audio.range(), audio.totalLength())
            );
        }

        return response.body(body);
    }

    @GetMapping
    public StorySoundtrackResponse getStorySoundtrack(
            @PathVariable UUID storyId
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();

        return StorySoundtrackResponse.from(
                resolveStorySoundtrackUseCase.resolveStorySoundtrack(
                        authenticatedUser,
                        storyId
                )
        );
    }

    @PutMapping
    public StorySoundtrackResponse setStorySoundtrack(
            @PathVariable UUID storyId,
            @Valid @RequestBody SetStorySoundtrackRequest request
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        Instant currentTime = clock.instant();

        return StorySoundtrackResponse.from(
                setStorySoundtrackUseCase.setStorySoundtrack(
                        request.toCommand(
                                authenticatedUser,
                                storyId,
                                currentTime
                        )
                )
        );
    }

    @DeleteMapping
    public StorySoundtrackResponse removeStorySoundtrack(
            @PathVariable UUID storyId
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        Instant currentTime = clock.instant();

        return StorySoundtrackResponse.from(
                removeStorySoundtrackUseCase.removeStorySoundtrack(
                        new RemoveStorySoundtrackCommand(
                                authenticatedUser,
                                storyId,
                                currentTime
                        )
                )
        );
    }

    private static String contentRange(
            StorageByteRange range,
            long totalLength
    ) {
        long endInclusive = range.offset() + range.length() - 1L;

        return "bytes %d-%d/%d".formatted(
                range.offset(),
                endInclusive,
                totalLength
        );
    }
}
