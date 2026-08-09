package memory_map.backend.memory.api;

import jakarta.validation.Valid;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.memory.application.CreateMemoryCommand;
import memory_map.backend.memory.application.CreateMemoryUseCase;
import memory_map.backend.memory.application.DeleteMemoryCommand;
import memory_map.backend.memory.application.DeleteMemoryUseCase;
import memory_map.backend.memory.application.GetMemoryUseCase;
import memory_map.backend.memory.application.GetStoryMemoriesUseCase;
import memory_map.backend.memory.application.UpdateMemoryUseCase;
import memory_map.backend.memory.domain.Memory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
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
@RequestMapping("/api/v1")
public class MemoryController {

    private final CreateMemoryUseCase createMemoryUseCase;
    private final GetStoryMemoriesUseCase getStoryMemoriesUseCase;
    private final GetMemoryUseCase getMemoryUseCase;
    private final UpdateMemoryUseCase updateMemoryUseCase;
    private final DeleteMemoryUseCase deleteMemoryUseCase;
    private final CurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;
    private final Clock clock;

    public MemoryController(
            CreateMemoryUseCase createMemoryUseCase,
            GetStoryMemoriesUseCase getStoryMemoriesUseCase,
            GetMemoryUseCase getMemoryUseCase,
            UpdateMemoryUseCase updateMemoryUseCase,
            DeleteMemoryUseCase deleteMemoryUseCase,
            CurrentAuthenticatedUserProvider
                    currentAuthenticatedUserProvider,
            Clock clock
    ) {
        this.createMemoryUseCase = Objects.requireNonNull(
                createMemoryUseCase,
                "createMemoryUseCase must not be null"
        );
        this.getStoryMemoriesUseCase = Objects.requireNonNull(
                getStoryMemoriesUseCase,
                "getStoryMemoriesUseCase must not be null"
        );
        this.getMemoryUseCase = Objects.requireNonNull(
                getMemoryUseCase,
                "getMemoryUseCase must not be null"
        );
        this.updateMemoryUseCase = Objects.requireNonNull(
                updateMemoryUseCase,
                "updateMemoryUseCase must not be null"
        );
        this.deleteMemoryUseCase = Objects.requireNonNull(
                deleteMemoryUseCase,
                "deleteMemoryUseCase must not be null"
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

    @PostMapping("/stories/{storyId}/memories")
    public ResponseEntity<MemoryResponse> createMemory(
            @PathVariable UUID storyId,
            @Valid @RequestBody CreateMemoryRequest request
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        UUID memoryId = UUID.randomUUID();
        Instant currentTime = clock.instant();

        Memory memory = createMemoryUseCase.createMemory(
                new CreateMemoryCommand(
                        authenticatedUser,
                        storyId,
                        memoryId,
                        request.title(),
                        request.description(),
                        request.placeName(),
                        request.latitude(),
                        request.longitude(),
                        request.eventDate(),
                        currentTime
                )
        );

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(MemoryResponse.from(memory));
    }

    @GetMapping("/stories/{storyId}/memories")
    public List<MemoryResponse> getStoryMemories(
            @PathVariable UUID storyId
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();

        return getStoryMemoriesUseCase.getMemories(
                authenticatedUser,
                storyId
        )
                .stream()
                .map(MemoryResponse::from)
                .toList();
    }

    @GetMapping("/memories/{memoryId}")
    public MemoryResponse getMemory(
            @PathVariable UUID memoryId
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();

        return MemoryResponse.from(
                getMemoryUseCase.getMemory(authenticatedUser, memoryId)
        );
    }

    @PatchMapping("/memories/{memoryId}")
    public MemoryResponse updateMemory(
            @PathVariable UUID memoryId,
            @RequestBody UpdateMemoryRequest request
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        Instant currentTime = clock.instant();

        return MemoryResponse.from(
                updateMemoryUseCase.updateMemory(
                        request.toCommand(
                                authenticatedUser,
                                memoryId,
                                currentTime
                        )
                )
        );
    }

    @DeleteMapping("/memories/{memoryId}")
    public ResponseEntity<Void> deleteMemory(
            @PathVariable UUID memoryId
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();

        deleteMemoryUseCase.deleteMemory(
                new DeleteMemoryCommand(authenticatedUser, memoryId)
        );

        return ResponseEntity.noContent().build();
    }
}
