package memory_map.backend.story.api;

import jakarta.validation.constraints.NotBlank;

import java.util.Objects;

public record CreateStoryRequest(

        @NotBlank
        String title,

        String description

) {
    public CreateStoryRequest {
        Objects.requireNonNull(title, "title must not be null");
    }
}
