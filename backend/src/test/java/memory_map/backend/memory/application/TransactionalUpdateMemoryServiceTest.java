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

class TransactionalUpdateMemoryServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID AUTHOR_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000011");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final Instant JOINED_AT =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-02T10:00:00.123456Z");
    private static final Instant UPDATED_AT =
            Instant.parse("2026-01-03T10:00:00.123456Z");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00.123456Z");
    private static final LocalDate EVENT_DATE =
            LocalDate.of(2024, 5, 20);

    @Test
    void shouldUpdateMemoryForOwner() {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        );

        Memory result = context.service().updateMemory(command(
                PatchField.provided("Updated memory"),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        ));

        assertThat(result).isEqualTo(updatedMemory(
                "Updated memory",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                EVENT_DATE,
                CURRENT_TIME
        ));
        assertThat(context.memoryRepository().receivedMemoryId())
                .isEqualTo(MEMORY_ID);
        assertThat(context.storyParticipantRepository().receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.storyParticipantRepository().receivedUserId())
                .isEqualTo(USER_ID);
        assertThat(context.calls()).containsExactly(
                "find Memory for update",
                "find StoryParticipant",
                "update Memory"
        );
    }

    @Test
    void shouldUpdateMemoryForCoOwner() {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.CO_OWNER)
        );

        Memory result = context.service().updateMemory(command(
                notProvided(),
                PatchField.provided("Updated description"),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        ));

        assertThat(result.description()).isEqualTo("Updated description");
        assertThat(context.memoryRepository().updateCallCount())
                .isEqualTo(1);
    }

    @Test
    void shouldUpdateOwnMemoryForEditor() {

        TestContext context = testContext(
                existingMemory(USER_ID),
                participant(StoryRole.EDITOR)
        );

        Memory result = context.service().updateMemory(command(
                notProvided(),
                notProvided(),
                PatchField.provided("Kutaisi"),
                notProvided(),
                notProvided(),
                notProvided()
        ));

        assertThat(result.createdBy()).isEqualTo(USER_ID);
        assertThat(result.placeName()).isEqualTo("Kutaisi");
        assertThat(context.memoryRepository().updateCallCount())
                .isEqualTo(1);
    }

    @Test
    void shouldDenyViewerForOwnMemory() {

        TestContext context = testContext(
                existingMemory(USER_ID),
                participant(StoryRole.VIEWER)
        );

        assertMemoryUnavailable(() -> context.service().updateMemory(command(
                PatchField.provided("Updated memory"),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        )));

        assertThat(context.memoryRepository().updateCallCount()).isZero();
        assertThat(context.calls()).containsExactly(
                "find Memory for update",
                "find StoryParticipant"
        );
    }

    @ParameterizedTest
    @EnumSource(value = StoryRole.class, names = {"EDITOR", "VIEWER"})
    void shouldDenyNonAuthorEditorAndViewer(StoryRole role) {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(role)
        );

        assertMemoryUnavailable(() -> context.service().updateMemory(command(
                PatchField.provided("Updated memory"),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        )));

        assertThat(context.memoryRepository().updateCallCount()).isZero();
        assertThat(context.calls()).containsExactly(
                "find Memory for update",
                "find StoryParticipant"
        );
    }

    @Test
    void shouldThrowMemoryUnavailableWhenMemoryIsMissing() {

        TestContext context = testContext(
                Optional.empty(),
                participant(StoryRole.OWNER)
        );

        assertMemoryUnavailable(() -> context.service().updateMemory(command(
                PatchField.provided("Updated memory"),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        )));

        assertThat(context.storyParticipantRepository().findCallCount())
                .isZero();
        assertThat(context.memoryRepository().updateCallCount()).isZero();
        assertThat(context.calls()).containsExactly("find Memory for update");
    }

    @Test
    void shouldThrowMemoryUnavailableWhenMembershipIsMissing() {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                Optional.empty()
        );

        assertMemoryUnavailable(() -> context.service().updateMemory(command(
                PatchField.provided("Updated memory"),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        )));

        assertThat(context.memoryRepository().updateCallCount()).isZero();
        assertThat(context.calls()).containsExactly(
                "find Memory for update",
                "find StoryParticipant"
        );
    }

    @Test
    void shouldDenyAuthorWithoutMembership() {

        TestContext context = testContext(
                existingMemory(USER_ID),
                Optional.empty()
        );

        assertMemoryUnavailable(() -> context.service().updateMemory(command(
                PatchField.provided("Updated memory"),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        )));

        assertThat(context.memoryRepository().updateCallCount()).isZero();
    }

    @Test
    void shouldApplyTitleOnlyPatch() {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        );

        context.service().updateMemory(command(
                PatchField.provided("Updated memory"),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        ));

        assertThat(context.memoryRepository().updatedMemory())
                .isEqualTo(updatedMemory(
                        "Updated memory",
                        "A spring walk",
                        "Tbilisi",
                        41.715137,
                        44.827096,
                        EVENT_DATE,
                        CURRENT_TIME
                ));
    }

    @Test
    void shouldClearDescription() {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        );

        Memory result = context.service().updateMemory(command(
                notProvided(),
                PatchField.provided(null),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        ));

        assertThat(result.description()).isNull();
    }

    @Test
    void shouldClearPlaceName() {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        );

        Memory result = context.service().updateMemory(command(
                notProvided(),
                notProvided(),
                PatchField.provided(null),
                notProvided(),
                notProvided(),
                notProvided()
        ));

        assertThat(result.placeName()).isNull();
    }

    @Test
    void shouldUpdateLocationWithoutSwappingCoordinates() {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        );

        Memory result = context.service().updateMemory(command(
                notProvided(),
                notProvided(),
                notProvided(),
                PatchField.provided(42.267910),
                PatchField.provided(42.694595),
                notProvided()
        ));

        assertThat(result.latitude()).isEqualTo(42.267910);
        assertThat(result.longitude()).isEqualTo(42.694595);
    }

    @Test
    void shouldUpdateEventDate() {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        );
        LocalDate updatedEventDate = LocalDate.of(2027, 2, 14);

        Memory result = context.service().updateMemory(command(
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                PatchField.provided(updatedEventDate)
        ));

        assertThat(result.eventDate()).isEqualTo(updatedEventDate);
    }

    @Test
    void shouldApplyAllMutableFieldsAndPreserveImmutableFields() {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        );

        Memory result = context.service().updateMemory(command(
                PatchField.provided("Updated memory"),
                PatchField.provided("Updated description"),
                PatchField.provided("Kutaisi"),
                PatchField.provided(42.267910),
                PatchField.provided(42.694595),
                PatchField.provided(LocalDate.of(2025, 1, 2))
        ));

        assertThat(result.id()).isEqualTo(MEMORY_ID);
        assertThat(result.storyId()).isEqualTo(STORY_ID);
        assertThat(result.createdBy()).isEqualTo(AUTHOR_ID);
        assertThat(result.createdAt()).isEqualTo(CREATED_AT);
        assertThat(result.title()).isEqualTo("Updated memory");
        assertThat(result.description()).isEqualTo("Updated description");
        assertThat(result.placeName()).isEqualTo("Kutaisi");
        assertThat(result.latitude()).isEqualTo(42.267910);
        assertThat(result.longitude()).isEqualTo(42.694595);
        assertThat(result.eventDate()).isEqualTo(LocalDate.of(2025, 1, 2));
        assertThat(result.updatedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldReturnExistingMemoryAndSkipUpdateForSameTitleNoOp() {

        Memory existing = existingMemory(AUTHOR_ID);
        TestContext context = testContext(
                existing,
                participant(StoryRole.OWNER)
        );

        Memory result = context.service().updateMemory(command(
                PatchField.provided(existing.title()),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        ));

        assertThat(result).isSameAs(existing);
        assertThat(result.updatedAt()).isEqualTo(UPDATED_AT);
        assertThat(context.memoryRepository().updateCallCount()).isZero();
        assertThat(context.calls()).containsExactly(
                "find Memory for update",
                "find StoryParticipant"
        );
    }

    @Test
    void shouldSkipUpdateWhenNullableClearIsAlreadyNull() {

        Memory existing = existingMemory(
                AUTHOR_ID,
                "First trip",
                null,
                null,
                41.715137,
                44.827096,
                EVENT_DATE
        );
        TestContext context = testContext(
                existing,
                participant(StoryRole.OWNER)
        );

        Memory result = context.service().updateMemory(command(
                notProvided(),
                PatchField.provided(null),
                PatchField.provided(null),
                notProvided(),
                notProvided(),
                notProvided()
        ));

        assertThat(result).isSameAs(existing);
        assertThat(context.memoryRepository().updateCallCount()).isZero();
    }

    @Test
    void shouldSkipUpdateWhenMultipleProvidedFieldsMatchExistingValues() {

        Memory existing = existingMemory(AUTHOR_ID);
        TestContext context = testContext(
                existing,
                participant(StoryRole.OWNER)
        );

        Memory result = context.service().updateMemory(command(
                PatchField.provided(existing.title()),
                PatchField.provided(existing.description()),
                PatchField.provided(existing.placeName()),
                PatchField.provided(existing.latitude()),
                PatchField.provided(existing.longitude()),
                PatchField.provided(existing.eventDate())
        ));

        assertThat(result).isSameAs(existing);
        assertThat(context.memoryRepository().updateCallCount()).isZero();
    }

    @Test
    void shouldUpdateWhenOneProvidedFieldDiffersAmongSameValues() {

        Memory existing = existingMemory(AUTHOR_ID);
        TestContext context = testContext(
                existing,
                participant(StoryRole.OWNER)
        );

        Memory result = context.service().updateMemory(command(
                PatchField.provided(existing.title()),
                PatchField.provided("Updated description"),
                PatchField.provided(existing.placeName()),
                PatchField.provided(existing.latitude()),
                PatchField.provided(existing.longitude()),
                PatchField.provided(existing.eventDate())
        ));

        assertThat(result.description()).isEqualTo("Updated description");
        assertThat(context.memoryRepository().updateCallCount())
                .isEqualTo(1);
    }

    @Test
    void shouldThrowInvariantFailureWhenUpdateAffectsNoRowsAfterLock() {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        );
        context.memoryRepository().returnUpdateResult(false);

        assertThatThrownBy(() -> context.service().updateMemory(command(
                PatchField.provided("Updated memory"),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        )))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Memory update affected no rows after locked lookup")
                .isNotInstanceOf(MemoryUpdateUnavailableException.class);
    }

    @Test
    void shouldPropagateLockedLookupFailure() {

        RuntimeException failure = new RuntimeException("lock failed");
        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        );
        context.memoryRepository().failOnFindByIdForUpdate(failure);

        assertThatThrownBy(() -> context.service().updateMemory(command(
                PatchField.provided("Updated memory"),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        )))
                .isSameAs(failure);
        assertThat(context.storyParticipantRepository().findCallCount())
                .isZero();
    }

    @Test
    void shouldPropagateMembershipLookupFailure() {

        RuntimeException failure = new RuntimeException("membership failed");
        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        );
        context.storyParticipantRepository().failOnFind(failure);

        assertThatThrownBy(() -> context.service().updateMemory(command(
                PatchField.provided("Updated memory"),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        )))
                .isSameAs(failure);
        assertThat(context.memoryRepository().updateCallCount()).isZero();
    }

    @Test
    void shouldPropagateUpdateFailure() {

        RuntimeException failure = new RuntimeException("update failed");
        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        );
        context.memoryRepository().failOnUpdate(failure);

        assertThatThrownBy(() -> context.service().updateMemory(command(
                PatchField.provided("Updated memory"),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        )))
                .isSameAs(failure)
                .isNotInstanceOf(MemoryUpdateUnavailableException.class);
    }

    @Test
    void shouldRejectNullMemoryRepositoryDependency() {

        StoryParticipantRepository storyParticipantRepository = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        ).storyParticipantRepository();

        assertThatThrownBy(() -> new TransactionalUpdateMemoryService(
                null,
                storyParticipantRepository
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("memoryRepository must not be null");
    }

    @Test
    void shouldRejectNullStoryParticipantRepositoryDependency() {

        MemoryRepository memoryRepository = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        ).memoryRepository();

        assertThatThrownBy(() -> new TransactionalUpdateMemoryService(
                memoryRepository,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyParticipantRepository must not be null");
    }

    @Test
    void shouldRejectNullCommandBeforeInteractions() {

        TestContext context = testContext(
                existingMemory(AUTHOR_ID),
                participant(StoryRole.OWNER)
        );

        assertThatThrownBy(() -> context.service().updateMemory(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("command must not be null");

        assertThat(context.memoryRepository().findForUpdateCallCount())
                .isZero();
        assertThat(context.storyParticipantRepository().findCallCount())
                .isZero();
        assertThat(context.memoryRepository().updateCallCount()).isZero();
    }

    private static TestContext testContext(
            Memory memory,
            Optional<StoryParticipant> participant
    ) {
        return testContext(Optional.of(memory), participant);
    }

    private static TestContext testContext(
            Optional<Memory> memory,
            Optional<StoryParticipant> participant
    ) {
        List<String> calls = new ArrayList<>();
        FakeMemoryRepository memoryRepository =
                new FakeMemoryRepository(memory, calls);
        FakeStoryParticipantRepository storyParticipantRepository =
                new FakeStoryParticipantRepository(participant, calls);

        return new TestContext(
                new TransactionalUpdateMemoryService(
                        memoryRepository,
                        storyParticipantRepository
                ),
                memoryRepository,
                storyParticipantRepository,
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

    private static UpdateMemoryCommand command(
            PatchField<String> title,
            PatchField<String> description,
            PatchField<String> placeName,
            PatchField<Double> latitude,
            PatchField<Double> longitude,
            PatchField<LocalDate> eventDate
    ) {
        return new UpdateMemoryCommand(
                new AuthenticatedUser(USER_ID),
                MEMORY_ID,
                title,
                description,
                placeName,
                latitude,
                longitude,
                eventDate,
                CURRENT_TIME
        );
    }

    private static Memory existingMemory(UUID createdBy) {
        return existingMemory(
                createdBy,
                "First trip",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                EVENT_DATE
        );
    }

    private static Memory existingMemory(
            UUID createdBy,
            String title,
            String description,
            String placeName,
            double latitude,
            double longitude,
            LocalDate eventDate
    ) {
        return new Memory(
                MEMORY_ID,
                STORY_ID,
                createdBy,
                title,
                description,
                placeName,
                latitude,
                longitude,
                eventDate,
                CREATED_AT,
                UPDATED_AT
        );
    }

    private static Memory updatedMemory(
            String title,
            String description,
            String placeName,
            double latitude,
            double longitude,
            LocalDate eventDate,
            Instant updatedAt
    ) {
        return new Memory(
                MEMORY_ID,
                STORY_ID,
                AUTHOR_ID,
                title,
                description,
                placeName,
                latitude,
                longitude,
                eventDate,
                CREATED_AT,
                updatedAt
        );
    }

    private static void assertMemoryUnavailable(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(MemoryUpdateUnavailableException.class)
                .hasMessage("Memory could not be updated");
    }

    private static <T> PatchField<T> notProvided() {
        return PatchField.notProvided();
    }

    private record TestContext(

            TransactionalUpdateMemoryService service,

            FakeMemoryRepository memoryRepository,

            FakeStoryParticipantRepository storyParticipantRepository,

            List<String> calls

    ) {
    }

    private static final class FakeMemoryRepository
            implements MemoryRepository {

        private final Optional<Memory> memory;
        private final List<String> calls;
        private UUID receivedMemoryId;
        private Memory updatedMemory;
        private boolean updateResult = true;
        private int findForUpdateCallCount;
        private int updateCallCount;
        private RuntimeException findForUpdateFailure;
        private RuntimeException updateFailure;

        private FakeMemoryRepository(
                Optional<Memory> memory,
                List<String> calls
        ) {
            this.memory = memory;
            this.calls = calls;
        }

        @Override
        public Optional<Memory> findById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<Memory> findByIdForUpdate(UUID id) {
            calls.add("find Memory for update");
            findForUpdateCallCount++;
            receivedMemoryId = id;

            if (findForUpdateFailure != null) {
                throw findForUpdateFailure;
            }

            return memory;
        }

        @Override
        public List<Memory> findByStoryId(UUID storyId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void save(Memory memory) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean update(Memory memory) {
            calls.add("update Memory");
            updateCallCount++;
            updatedMemory = memory;

            if (updateFailure != null) {
                throw updateFailure;
            }

            return updateResult;
        }

        @Override
        public boolean delete(UUID id) {
            throw new UnsupportedOperationException();
        }

        private UUID receivedMemoryId() {
            return receivedMemoryId;
        }

        private Memory updatedMemory() {
            return updatedMemory;
        }

        private int findForUpdateCallCount() {
            return findForUpdateCallCount;
        }

        private int updateCallCount() {
            return updateCallCount;
        }

        private void returnUpdateResult(boolean updateResult) {
            this.updateResult = updateResult;
        }

        private void failOnFindByIdForUpdate(RuntimeException failure) {
            findForUpdateFailure = failure;
        }

        private void failOnUpdate(RuntimeException failure) {
            updateFailure = failure;
        }
    }

    private static final class FakeStoryParticipantRepository
            implements StoryParticipantRepository {

        private final Optional<StoryParticipant> participant;
        private final List<String> calls;
        private UUID receivedStoryId;
        private UUID receivedUserId;
        private int findCallCount;
        private RuntimeException failure;

        private FakeStoryParticipantRepository(
                Optional<StoryParticipant> participant,
                List<String> calls
        ) {
            this.participant = participant;
            this.calls = calls;
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

        private void failOnFind(RuntimeException failure) {
            this.failure = failure;
        }
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();
    }
}
