package memory_map.backend.memory.application;

import memory_map.backend.memory.domain.Memory;

import java.util.List;
import java.util.Objects;

public record StoryMemoriesView(

        List<Memory> memories

) {
    public StoryMemoriesView {
        Objects.requireNonNull(memories, "memories must not be null");

        memories = List.copyOf(memories);
    }

    @Override
    public String toString() {
        return "StoryMemoriesView[memoryCount=" + memories.size() + "]";
    }
}
