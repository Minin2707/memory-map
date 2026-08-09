package memory_map.backend.memory.application;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class MemoryNotFoundExceptionTest {

    @Test
    void shouldHaveSafeMessage() {

        MemoryNotFoundException exception =
                new MemoryNotFoundException();

        assertThat(exception)
                .hasMessage("Memory was not found")
                .hasNoCause();
        assertThat(exception.toString())
                .doesNotContain("00000000-0000-0000-0000-000000000001")
                .doesNotContain("story")
                .doesNotContain("user")
                .doesNotContain("role")
                .doesNotContain("coordinate")
                .doesNotContain("JDBC")
                .doesNotContain("SQL");
    }
}
