package memory_map.backend.memory.application;

import memory_map.backend.memory.domain.Memory;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MemoryReadModelTest {

    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    @Test
    void shouldExposeMemoryAndPreviewPhoto() {

        Memory memory = memory();
        MemoryPreviewPhoto previewPhoto = new MemoryPreviewPhoto(MEDIA_ID);

        MemoryReadModel readModel =
                new MemoryReadModel(memory, previewPhoto);

        assertThat(readModel.memory()).isSameAs(memory);
        assertThat(readModel.previewPhoto()).isSameAs(previewPhoto);
    }

    @Test
    void shouldAllowMissingPreviewPhoto() {

        Memory memory = memory();

        MemoryReadModel readModel = MemoryReadModel.withoutPreview(memory);

        assertThat(readModel.memory()).isSameAs(memory);
        assertThat(readModel.previewPhoto()).isNull();
    }

    @Test
    void shouldRejectNullMemory() {

        assertThatThrownBy(() -> new MemoryReadModel(
                null,
                new MemoryPreviewPhoto(MEDIA_ID)
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("memory must not be null");
    }

    @Test
    void shouldHaveSafeToString() {

        String value = new MemoryReadModel(
                memory(),
                new MemoryPreviewPhoto(MEDIA_ID)
        ).toString();

        assertThat(value)
                .isEqualTo("MemoryReadModel[hasPreviewPhoto=true]")
                .doesNotContain(MEMORY_ID.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain(MEDIA_ID.toString())
                .doesNotContain("First trip")
                .doesNotContain("A spring walk")
                .doesNotContain("Tbilisi")
                .doesNotContain("41.715137")
                .doesNotContain("44.827096");
    }

    private static Memory memory() {
        return new Memory(
                MEMORY_ID,
                STORY_ID,
                USER_ID,
                "First trip",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2025, 5, 20),
                CURRENT_TIME,
                CURRENT_TIME
        );
    }
}
