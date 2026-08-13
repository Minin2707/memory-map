package memory_map.backend.memory.application;

import java.util.List;
import java.util.Objects;

public record StoryMemoriesView(

        List<MemoryReadModel> memories

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
