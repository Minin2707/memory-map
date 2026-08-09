package memory_map.backend.memory.api;

import memory_map.backend.memory.domain.Memory;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MemoryResponseTest {

    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID CREATED_BY =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final LocalDate EVENT_DATE =
            LocalDate.of(2024, 5, 18);
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final Instant UPDATED_AT =
            Instant.parse("2026-01-10T10:00:00Z");

    @Test
    void shouldMapAllMemoryFields() {

        Memory memory = memory(
                "First day in Tbilisi",
                "Old city walk",
                "Tbilisi"
        );

        MemoryResponse response = MemoryResponse.from(memory);

        assertThat(response.id()).isEqualTo(MEMORY_ID);
        assertThat(response.storyId()).isEqualTo(STORY_ID);
        assertThat(response.createdBy()).isEqualTo(CREATED_BY);
        assertThat(response.title()).isEqualTo("First day in Tbilisi");
        assertThat(response.description()).isEqualTo("Old city walk");
        assertThat(response.placeName()).isEqualTo("Tbilisi");
        assertThat(response.latitude()).isEqualTo(41.6938);
        assertThat(response.longitude()).isEqualTo(44.8015);
        assertThat(response.eventDate()).isEqualTo(EVENT_DATE);
        assertThat(response.createdAt()).isEqualTo(CREATED_AT);
        assertThat(response.updatedAt()).isEqualTo(UPDATED_AT);
    }

    @Test
    void shouldPreserveNullableFields() {

        MemoryResponse response = MemoryResponse.from(memory(
                "First day in Tbilisi",
                null,
                null
        ));

        assertThat(response.description()).isNull();
        assertThat(response.placeName()).isNull();
    }

    @Test
    void shouldRejectNullMemory() {

        assertThatThrownBy(() -> MemoryResponse.from(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("memory must not be null");
    }

    private static Memory memory(
            String title,
            String description,
            String placeName
    ) {
        return new Memory(
                MEMORY_ID,
                STORY_ID,
                CREATED_BY,
                title,
                description,
                placeName,
                41.6938,
                44.8015,
                EVENT_DATE,
                CREATED_AT,
                UPDATED_AT
        );
    }
}
