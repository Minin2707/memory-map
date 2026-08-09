package memory_map.backend.memory.api;

import memory_map.backend.memory.domain.Memory;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Objects;
import java.util.UUID;

public record MemoryResponse(

        UUID id,

        UUID storyId,

        UUID createdBy,

        String title,

        String description,

        String placeName,

        double latitude,

        double longitude,

        LocalDate eventDate,

        Instant createdAt,

        Instant updatedAt

) {
    public static MemoryResponse from(Memory memory) {
        Objects.requireNonNull(memory, "memory must not be null");

        return new MemoryResponse(
                memory.id(),
                memory.storyId(),
                memory.createdBy(),
                memory.title(),
                memory.description(),
                memory.placeName(),
                memory.latitude(),
                memory.longitude(),
                memory.eventDate(),
                memory.createdAt(),
                memory.updatedAt()
        );
    }
}
