package memory_map.backend.memory.application;

import memory_map.backend.memory.domain.Memory;

import java.util.Objects;

public record MemoryReadModel(

        Memory memory,

        MemoryPreviewPhoto previewPhoto

) {
    public MemoryReadModel {
        Objects.requireNonNull(memory, "memory must not be null");
    }

    public static MemoryReadModel withoutPreview(Memory memory) {
        return new MemoryReadModel(memory, null);
    }

    @Override
    public String toString() {
        return "MemoryReadModel[hasPreviewPhoto=%s]"
                .formatted(previewPhoto != null);
    }
}
