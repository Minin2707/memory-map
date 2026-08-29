package memory_map.backend.account.api;

import memory_map.backend.account.application.AccountDeletionOwnershipConflictException;
import memory_map.backend.account.application.DeleteCurrentAccountCommand;
import memory_map.backend.account.application.DeleteCurrentAccountUseCase;
import memory_map.backend.account.application.UpdateCurrentUserDisplayNameCommand;
import memory_map.backend.account.application.UpdateCurrentUserDisplayNameUseCase;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.user.domain.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(AccountController.class)
@AutoConfigureMockMvc(addFilters = false)
@Import({
        AccountApiExceptionHandler.class,
        AccountControllerTest.AccountControllerTestConfiguration.class
})
class AccountControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private FakeDeleteCurrentAccountUseCase deleteCurrentAccountUseCase;

    @Autowired
    private FakeUpdateCurrentUserDisplayNameUseCase
            updateDisplayNameUseCase;

    @Autowired
    private FakeCurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;

    @Autowired
    private Clock clock;

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");

    @BeforeEach
    void resetFakes() {
        deleteCurrentAccountUseCase.reset();
        updateDisplayNameUseCase.reset();
        currentAuthenticatedUserProvider.reset();
    }

    @Test
    void shouldUpdateCurrentUserDisplayName() throws Exception {

        mockMvc.perform(org.springframework.test.web.servlet.request
                        .MockMvcRequestBuilders
                        .patch("/api/v1/me/display-name")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "displayName": "  Анна-Мария O'Connor  ",
                                  "userId": "00000000-0000-0000-0000-000000000999",
                                  "email": "anna@example.test"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(USER_ID.toString()))
                .andExpect(jsonPath("$.displayName")
                        .value("Анна-Мария O'Connor"))
                .andExpect(jsonPath("$.avatarUrl")
                        .value("https://example.com/avatar.png"))
                .andExpect(jsonPath("$.hasCustomAvatar").value(false))
                .andExpect(jsonPath("$.email").doesNotExist())
                .andExpect(jsonPath("$.displayNameCustomized").doesNotExist());

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(updateDisplayNameUseCase.callCount()).isEqualTo(1);
        assertThat(updateDisplayNameUseCase.receivedCommand())
                .isEqualTo(new UpdateCurrentUserDisplayNameCommand(
                        new AuthenticatedUser(USER_ID),
                        "  Анна-Мария O'Connor  ",
                        CURRENT_TIME
                ));
    }

    @Test
    void shouldReturnBadRequestForInvalidDisplayName() throws Exception {

        mockMvc.perform(org.springframework.test.web.servlet.request
                        .MockMvcRequestBuilders
                        .patch("/api/v1/me/display-name")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "displayName": "   "
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(
                        MediaType.APPLICATION_PROBLEM_JSON
                ))
                .andExpect(jsonPath("$.title").value("Bad Request"))
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.detail").value("Invalid display name"))
                .andExpect(jsonPath("$.instance")
                        .value("/api/v1/me/display-name"));

        assertThat(updateDisplayNameUseCase.callCount()).isZero();
    }

    @Test
    void shouldDeleteCurrentAccount() throws Exception {

        mockMvc.perform(delete("/api/v1/me"))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(deleteCurrentAccountUseCase.callCount()).isEqualTo(1);
        assertThat(deleteCurrentAccountUseCase.receivedCommand())
                .isEqualTo(new DeleteCurrentAccountCommand(
                        new AuthenticatedUser(USER_ID),
                        CURRENT_TIME
                ));
    }

    @Test
    void shouldReturnConflictWhenOwnershipMustBeResolved() throws Exception {

        deleteCurrentAccountUseCase.failWith(
                new AccountDeletionOwnershipConflictException()
        );

        String response = mockMvc.perform(delete("/api/v1/me"))
                .andExpect(status().isConflict())
                .andExpect(content().contentTypeCompatibleWith(
                        MediaType.APPLICATION_PROBLEM_JSON
                ))
                .andExpect(jsonPath("$.title").value("Conflict"))
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.detail").value(
                        "Transfer ownership of shared stories before deleting your profile."
                ))
                .andExpect(jsonPath("$.instance").value("/api/v1/me"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain(USER_ID.toString())
                .doesNotContain("googleSubject")
                .doesNotContain("refreshToken")
                .doesNotContain("storageKey")
                .doesNotContain("SQL")
                .doesNotContain("Jdbc");
    }

    @Test
    void shouldRejectNullDeleteCurrentAccountUseCaseDependency() {

        assertThatThrownBy(() -> new AccountController(
                null,
                updateDisplayNameUseCase,
                currentAuthenticatedUserProvider,
                clock
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("deleteCurrentAccountUseCase must not be null");
    }

    @Test
    void shouldRejectNullUpdateCurrentUserDisplayNameUseCaseDependency() {

        assertThatThrownBy(() -> new AccountController(
                deleteCurrentAccountUseCase,
                null,
                currentAuthenticatedUserProvider,
                clock
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage(
                        "updateCurrentUserDisplayNameUseCase must not be null"
                );
    }

    @Test
    void shouldRejectNullCurrentAuthenticatedUserProviderDependency() {

        assertThatThrownBy(() -> new AccountController(
                deleteCurrentAccountUseCase,
                updateDisplayNameUseCase,
                null,
                clock
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage(
                        "currentAuthenticatedUserProvider must not be null"
                );
    }

    @Test
    void shouldRejectNullClockDependency() {

        assertThatThrownBy(() -> new AccountController(
                deleteCurrentAccountUseCase,
                updateDisplayNameUseCase,
                currentAuthenticatedUserProvider,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("clock must not be null");
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class AccountControllerTestConfiguration {

        @Bean
        Clock clock() {
            return Clock.fixed(CURRENT_TIME, ZoneOffset.UTC);
        }

        @Bean
        FakeDeleteCurrentAccountUseCase deleteCurrentAccountUseCase() {
            return new FakeDeleteCurrentAccountUseCase();
        }

        @Bean
        FakeUpdateCurrentUserDisplayNameUseCase
        updateCurrentUserDisplayNameUseCase() {
            return new FakeUpdateCurrentUserDisplayNameUseCase();
        }

        @Bean
        FakeCurrentAuthenticatedUserProvider
        currentAuthenticatedUserProvider() {
            return new FakeCurrentAuthenticatedUserProvider();
        }
    }

    static final class FakeDeleteCurrentAccountUseCase
            implements DeleteCurrentAccountUseCase {

        private DeleteCurrentAccountCommand receivedCommand;
        private RuntimeException exception;
        private int callCount;

        @Override
        public void deleteCurrentAccount(DeleteCurrentAccountCommand command) {
            receivedCommand = command;
            callCount++;

            if (exception != null) {
                throw exception;
            }
        }

        private DeleteCurrentAccountCommand receivedCommand() {
            return receivedCommand;
        }

        private int callCount() {
            return callCount;
        }

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void reset() {
            receivedCommand = null;
            exception = null;
            callCount = 0;
        }
    }

    static final class FakeUpdateCurrentUserDisplayNameUseCase
            implements UpdateCurrentUserDisplayNameUseCase {

        private UpdateCurrentUserDisplayNameCommand receivedCommand;
        private int callCount;

        @Override
        public User updateDisplayName(
                UpdateCurrentUserDisplayNameCommand command
        ) {
            receivedCommand = command;
            callCount++;

            return new User(
                    USER_ID,
                    "google-subject-123",
                    command.displayName().trim(),
                    true,
                    "https://example.com/avatar.png",
                    null,
                    null,
                    CURRENT_TIME.minusSeconds(60),
                    CURRENT_TIME,
                    null
            );
        }

        private UpdateCurrentUserDisplayNameCommand receivedCommand() {
            return receivedCommand;
        }

        private int callCount() {
            return callCount;
        }

        private void reset() {
            receivedCommand = null;
            callCount = 0;
        }
    }

    static final class FakeCurrentAuthenticatedUserProvider
            implements CurrentAuthenticatedUserProvider {

        private int callCount;

        @Override
        public AuthenticatedUser getCurrentUser() {
            callCount++;

            return new AuthenticatedUser(USER_ID);
        }

        private int callCount() {
            return callCount;
        }

        private void reset() {
            callCount = 0;
        }
    }
}
