package memory_map.backend.memory.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryReadRepository;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultGetMemoryServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final AuthenticatedUser AUTHENTICATED_USER =
            new AuthenticatedUser(USER_ID);

    @Test
    void shouldReturnAccessibleMemory() {

        Memory memory = memory();
        TestContext context = testContext(Optional.of(memory));

        Memory result = context.service().getMemory(
                AUTHENTICATED_USER,
                MEMORY_ID
        );

        assertThat(result).isSameAs(memory);
    }

    @Test
    void shouldPassMemoryIdAndAuthenticatedUserId() {

        TestContext context = testContext(Optional.of(memory()));

        context.service().getMemory(AUTHENTICATED_USER, MEMORY_ID);

        assertThat(context.repository().receivedMemoryId())
                .isEqualTo(MEMORY_ID);
        assertThat(context.repository().receivedRequesterUserId())
                .isEqualTo(USER_ID);
        assertThat(context.repository().memoryGetCallCount()).isEqualTo(1);
        assertThat(context.repository().storyListCallCount()).isZero();
    }

    @Test
    void shouldThrowMemoryNotFoundWhenMemoryIsUnavailable() {

        TestContext context = testContext(Optional.empty());

        assertThatThrownBy(() -> context.service().getMemory(
                AUTHENTICATED_USER,
                MEMORY_ID
        ))
                .isInstanceOf(MemoryNotFoundException.class)
                .hasMessage("Memory was not found");
    }

    @Test
    void shouldRejectNullRepositoryDependency() {

        assertThatThrownBy(() -> new DefaultGetMemoryService(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("repository must not be null");
    }

    @Test
    void shouldRejectNullAuthenticatedUser() {

        assertThatThrownBy(() -> testContext(Optional.of(memory()))
                .service().getMemory(null, MEMORY_ID))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
    }

    @Test
    void shouldRejectNullMemoryId() {

        assertThatThrownBy(() -> testContext(Optional.of(memory()))
                .service().getMemory(AUTHENTICATED_USER, null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("memoryId must not be null");
    }

    @Test
    void shouldPropagateRepositoryFailure() {

        RuntimeException failure = new RuntimeException("repository failed");
        TestContext context = testContext(Optional.empty());
        context.repository().failWith(failure);

        assertThatThrownBy(() -> context.service().getMemory(
                AUTHENTICATED_USER,
                MEMORY_ID
        ))
                .isSameAs(failure);
    }

    private static TestContext testContext(Optional<Memory> memory) {
        FakeMemoryReadRepository repository =
                new FakeMemoryReadRepository(memory);

        return new TestContext(
                new DefaultGetMemoryService(repository),
                repository
        );
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

    private record TestContext(

            DefaultGetMemoryService service,

            FakeMemoryReadRepository repository

    ) {
    }

    private static final class FakeMemoryReadRepository
            implements MemoryReadRepository {

        private final Optional<Memory> memory;
        private UUID receivedMemoryId;
        private UUID receivedRequesterUserId;
        private int memoryGetCallCount;
        private int storyListCallCount;
        private RuntimeException failure;

        private FakeMemoryReadRepository(Optional<Memory> memory) {
            this.memory = memory;
        }

        @Override
        public Optional<StoryMemoriesView> findByStoryIdAndRequesterUserId(
                UUID storyId,
                UUID requesterUserId
        ) {
            storyListCallCount++;
            return Optional.empty();
        }

        @Override
        public Optional<Memory> findByIdAndRequesterUserId(
                UUID memoryId,
                UUID requesterUserId
        ) {
            receivedMemoryId = memoryId;
            receivedRequesterUserId = requesterUserId;
            memoryGetCallCount++;

            if (failure != null) {
                throw failure;
            }

            return memory;
        }

        private UUID receivedMemoryId() {
            return receivedMemoryId;
        }

        private UUID receivedRequesterUserId() {
            return receivedRequesterUserId;
        }

        private int memoryGetCallCount() {
            return memoryGetCallCount;
        }

        private int storyListCallCount() {
            return storyListCallCount;
        }

        private void failWith(RuntimeException failure) {
            this.failure = failure;
        }
    }
}
