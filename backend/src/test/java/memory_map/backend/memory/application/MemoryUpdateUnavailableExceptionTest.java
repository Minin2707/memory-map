package memory_map.backend.memory.application;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class MemoryUpdateUnavailableExceptionTest {

    @Test
    void shouldHaveSafeMessage() {

        MemoryUpdateUnavailableException exception =
                new MemoryUpdateUnavailableException();

        assertThat(exception)
                .hasMessage("Memory could not be updated")
                .hasNoCause();
        assertThat(exception.toString())
                .doesNotContain("00000000-0000-0000-0000-000000000001")
                .doesNotContain("OWNER")
                .doesNotContain("CO_OWNER")
                .doesNotContain("EDITOR")
                .doesNotContain("VIEWER")
                .doesNotContain("author")
                .doesNotContain("role")
                .doesNotContain("coordinate")
                .doesNotContain("41.715137")
                .doesNotContain("44.827096")
                .doesNotContain("SQL")
                .doesNotContain("JDBC");
    }
}
