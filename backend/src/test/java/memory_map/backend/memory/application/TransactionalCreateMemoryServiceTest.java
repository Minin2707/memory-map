package memory_map.backend.memory.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.within;

class TransactionalCreateMemoryServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final Instant JOINED_AT =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00.123456Z");
    private static final LocalDate EVENT_DATE =
            LocalDate.of(2025, 5, 20);

    @Test
    void shouldCreateMemoryForOwner() {

        TestContext context = testContext(participant(StoryRole.OWNER));

        Memory result = context.service().createMemory(command());

        assertThat(result).isSameAs(context.memoryRepository().savedMemory());
        assertThat(result).isEqualTo(expectedMemory(
                "First trip",
                "A spring walk",
                "Tbilisi",
                EVENT_DATE
        ));
        assertThat(context.storyParticipantRepository().receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.storyParticipantRepository().receivedUserId())
                .isEqualTo(USER_ID);
        assertThat(context.memoryRepository().saveCallCount()).isEqualTo(1);
        assertThat(context.calls()).containsExactly(
                "find StoryParticipant",
                "save Memory"
        );
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"CO_OWNER", "EDITOR"})
    void shouldCreateMemoryForOtherWriteRoles(StoryRole role) {

        TestContext context = testContext(participant(role));

        Memory result = context.service().createMemory(command());

        assertThat(result).isEqualTo(expectedMemory(
                "First trip",
                "A spring walk",
                "Tbilisi",
                EVENT_DATE
        ));
        assertThat(context.memoryRepository().saveCallCount()).isEqualTo(1);
    }

    @Test
    void shouldDenyViewer() {

        TestContext context = testContext(participant(StoryRole.VIEWER));

        assertMemoryUnavailable(() -> context.service().createMemory(command()));

        assertThat(context.memoryRepository().saveCallCount()).isZero();
        assertThat(context.calls()).containsExactly("find StoryParticipant");
    }

    @Test
    void shouldThrowMemoryUnavailableWhenStoryIsMissingOrInaccessible() {

        TestContext context = testContext(Optional.empty());

        assertMemoryUnavailable(() -> context.service().createMemory(command()));

        assertThat(context.storyParticipantRepository().receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.storyParticipantRepository().receivedUserId())
                .isEqualTo(USER_ID);
        assertThat(context.memoryRepository().saveCallCount()).isZero();
        assertThat(context.calls()).containsExactly("find StoryParticipant");
    }

    @Test
    void shouldUseCommandValuesWithoutTransformation() {

        TestContext context = testContext(participant(StoryRole.OWNER));
        CreateMemoryCommand command = command(
                "  First trip  ",
                "  A spring walk  ",
                "  Tbilisi  ",
                EVENT_DATE.plusYears(1)
        );

        context.service().createMemory(command);

        Memory saved = context.memoryRepository().savedMemory();

        assertThat(saved.id()).isEqualTo(MEMORY_ID);
        assertThat(saved.storyId()).isEqualTo(STORY_ID);
        assertThat(saved.createdBy()).isEqualTo(USER_ID);
        assertThat(saved.title()).isEqualTo("  First trip  ");
        assertThat(saved.description()).isEqualTo("  A spring walk  ");
        assertThat(saved.placeName()).isEqualTo("  Tbilisi  ");
        assertThat(saved.latitude()).isCloseTo(41.715137, within(0.000001));
        assertThat(saved.longitude()).isCloseTo(44.827096, within(0.000001));
        assertThat(saved.eventDate()).isEqualTo(EVENT_DATE.plusYears(1));
        assertThat(saved.createdAt()).isEqualTo(CURRENT_TIME);
        assertThat(saved.updatedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldPreserveNullOptionalFields() {

        TestContext context = testContext(participant(StoryRole.OWNER));

        Memory result = context.service().createMemory(command(
                "Quiet evening",
                null,
                null,
                EVENT_DATE
        ));

        assertThat(result.description()).isNull();
        assertThat(result.placeName()).isNull();
        assertThat(context.memoryRepository().savedMemory().description())
                .isNull();
        assertThat(context.memoryRepository().savedMemory().placeName())
                .isNull();
    }

    @Test
    void shouldPreserveEmptyOptionalFields() {

        TestContext context = testContext(participant(StoryRole.OWNER));

        Memory result = context.service().createMemory(command(
                "Quiet evening",
                "",
                "",
                EVENT_DATE
        ));

        assertThat(result.description()).isEmpty();
        assertThat(result.placeName()).isEmpty();
    }

    @Test
    void shouldAcceptFutureEventDate() {

        TestContext context = testContext(participant(StoryRole.OWNER));
        LocalDate futureDate = LocalDate.of(2027, 2, 14);

        Memory result = context.service().createMemory(command(
                "Future plan",
                "A planned memory",
                "Lisbon",
                futureDate
        ));

        assertThat(result.eventDate()).isEqualTo(futureDate);
        assertThat(context.memoryRepository().saveCallCount()).isEqualTo(1);
    }

    @Test
    void shouldRejectNullStoryParticipantRepositoryDependency() {

        TestContext context = testContext(participant(StoryRole.OWNER));

        assertThatThrownBy(() -> new TransactionalCreateMemoryService(
                null,
                context.memoryRepository()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyParticipantRepository must not be null");
    }

    @Test
    void shouldRejectNullMemoryRepositoryDependency() {

        TestContext context = testContext(participant(StoryRole.OWNER));

        assertThatThrownBy(() -> new TransactionalCreateMemoryService(
                context.storyParticipantRepository(),
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("memoryRepository must not be null");
    }

    @Test
    void shouldRejectNullCommand() {

        TestContext context = testContext(participant(StoryRole.OWNER));

        assertThatThrownBy(() -> context.service().createMemory(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("command must not be null");

        assertThat(context.storyParticipantRepository().findCallCount())
                .isZero();
        assertThat(context.memoryRepository().saveCallCount()).isZero();
    }

    @Test
    void shouldPropagateMembershipLookupFailure() {

        TestContext context = testContext(participant(StoryRole.OWNER));
        RuntimeException failure = new RuntimeException("lookup failed");
        context.storyParticipantRepository().failOnLookup(failure);

        assertThatThrownBy(() -> context.service().createMemory(command()))
                .isSameAs(failure);

        assertThat(context.memoryRepository().saveCallCount()).isZero();
        assertThat(context.calls()).containsExactly("find StoryParticipant");
    }

    @Test
    void shouldPropagateMemorySaveFailure() {

        TestContext context = testContext(participant(StoryRole.OWNER));
        RuntimeException failure = new RuntimeException("save failed");
        context.memoryRepository().failOnSave(failure);

        assertThatThrownBy(() -> context.service().createMemory(command()))
                .isSameAs(failure)
                .isNotInstanceOf(MemoryCreationUnavailableException.class);

        assertThat(context.calls()).containsExactly(
                "find StoryParticipant",
                "save Memory"
        );
    }

    private static TestContext testContext(
            Optional<StoryParticipant> participant
    ) {
        List<String> calls = new ArrayList<>();
        FakeStoryParticipantRepository storyParticipantRepository =
                new FakeStoryParticipantRepository(calls, participant);
        FakeMemoryRepository memoryRepository =
                new FakeMemoryRepository(calls);

        return new TestContext(
                new TransactionalCreateMemoryService(
                        storyParticipantRepository,
                        memoryRepository
                ),
                storyParticipantRepository,
                memoryRepository,
                calls
        );
    }

    private static Optional<StoryParticipant> participant(StoryRole role) {
        return Optional.of(new StoryParticipant(
                STORY_ID,
                USER_ID,
                role,
                JOINED_AT
        ));
    }

    private static CreateMemoryCommand command() {
        return command(
                "First trip",
                "A spring walk",
                "Tbilisi",
                EVENT_DATE
        );
    }

    private static CreateMemoryCommand command(
            String title,
            String description,
            String placeName,
            LocalDate eventDate
    ) {
        return new CreateMemoryCommand(
                new AuthenticatedUser(USER_ID),
                STORY_ID,
                MEMORY_ID,
                title,
                description,
                placeName,
                41.715137,
                44.827096,
                eventDate,
                CURRENT_TIME
        );
    }

    private static Memory expectedMemory(
            String title,
            String description,
            String placeName,
            LocalDate eventDate
    ) {
        return new Memory(
                MEMORY_ID,
                STORY_ID,
                USER_ID,
                title,
                description,
                placeName,
                41.715137,
                44.827096,
                eventDate,
                CURRENT_TIME,
                CURRENT_TIME
        );
    }

    private static void assertMemoryUnavailable(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(MemoryCreationUnavailableException.class)
                .hasMessage("Memory could not be created");
    }

    private record TestContext(

            TransactionalCreateMemoryService service,

            FakeStoryParticipantRepository storyParticipantRepository,

            FakeMemoryRepository memoryRepository,

            List<String> calls

    ) {
    }

    private static final class FakeStoryParticipantRepository
            implements StoryParticipantRepository {

        private final List<String> calls;
        private final Optional<StoryParticipant> participant;
        private UUID receivedStoryId;
        private UUID receivedUserId;
        private int findCallCount;
        private RuntimeException failure;

        private FakeStoryParticipantRepository(
                List<String> calls,
                Optional<StoryParticipant> participant
        ) {
            this.calls = calls;
            this.participant = participant;
        }

        @Override
        public Optional<StoryParticipant> find(UUID storyId, UUID userId) {
            calls.add("find StoryParticipant");
            findCallCount++;
            receivedStoryId = storyId;
            receivedUserId = userId;

            if (failure != null) {
                throw failure;
            }

            return participant;
        }

        @Override
        public List<StoryParticipant> findByStoryId(UUID storyId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<StoryParticipant> findByUserId(UUID userId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public long countOwners(UUID storyId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean exists(UUID storyId, UUID userId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void save(StoryParticipant participant) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void update(StoryParticipant participant) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void delete(UUID storyId, UUID userId) {
            throw new UnsupportedOperationException();
        }

        private UUID receivedStoryId() {
            return receivedStoryId;
        }

        private UUID receivedUserId() {
            return receivedUserId;
        }

        private int findCallCount() {
            return findCallCount;
        }

        private void failOnLookup(RuntimeException failure) {
            this.failure = failure;
        }
    }

    private static final class FakeMemoryRepository
            implements MemoryRepository {

        private final List<String> calls;
        private Memory savedMemory;
        private int saveCallCount;
        private RuntimeException failure;

        private FakeMemoryRepository(List<String> calls) {
            this.calls = calls;
        }

        @Override
        public Optional<Memory> findById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<Memory> findByIdForUpdate(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<Memory> findByStoryId(UUID storyId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void save(Memory memory) {
            calls.add("save Memory");
            saveCallCount++;

            if (failure != null) {
                throw failure;
            }

            savedMemory = memory;
        }

        @Override
        public boolean update(Memory memory) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean delete(UUID id) {
            throw new UnsupportedOperationException();
        }

        private Memory savedMemory() {
            return savedMemory;
        }

        private int saveCallCount() {
            return saveCallCount;
        }

        private void failOnSave(RuntimeException failure) {
            this.failure = failure;
        }
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();
    }
}
