package memory_map.backend.invite.application;

import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class Sha256InviteTokenHasherTest {

    private static final String ABC_SHA_256_HEX =
            "ba7816bf8f01cfea414140de5dae2223"
                    + "b00361a396177a9cb410ff61f20015ad";

    @Test
    void shouldHashRawTokenWithSha256() {

        String hash = new Sha256InviteTokenHasher().hash("abc");

        assertThat(hash).isEqualTo(ABC_SHA_256_HEX);
    }

    @Test
    void shouldReturnStableLowercaseHexHash() {

        Sha256InviteTokenHasher hasher = new Sha256InviteTokenHasher();

        String first = hasher.hash("invite-token-value");
        String second = hasher.hash("invite-token-value");

        assertThat(first).isEqualTo(second);
        assertThat(first).matches("[0-9a-f]{64}");
    }

    @Test
    void shouldReturnSixtyFourCharacterHash() {

        String hash = new Sha256InviteTokenHasher()
                .hash("invite-token-value");

        assertThat(hash).hasSize(64);
    }

    @Test
    void shouldReturnDifferentHashesForDifferentTokens() {

        Sha256InviteTokenHasher hasher = new Sha256InviteTokenHasher();

        String first = hasher.hash("first-token");
        String second = hasher.hash("second-token");

        assertThat(first).isNotEqualTo(second);
    }

    @Test
    void shouldNotTrimOrNormalizeRawToken() {

        Sha256InviteTokenHasher hasher = new Sha256InviteTokenHasher();

        String withoutSpaces = hasher.hash("token");
        String withSpaces = hasher.hash(" token ");

        assertThat(withSpaces).isNotEqualTo(withoutSpaces);
    }

    @Test
    void shouldBeThreadSafe() throws Exception {

        Sha256InviteTokenHasher hasher = new Sha256InviteTokenHasher();
        String expected = hasher.hash("invite-token-value");
        ExecutorService executor = Executors.newFixedThreadPool(4);
        List<Callable<String>> tasks = new ArrayList<>();

        for (int index = 0; index < 16; index++) {
            tasks.add(() -> hasher.hash("invite-token-value"));
        }

        try {
            List<Future<String>> hashes = executor.invokeAll(
                    tasks,
                    10,
                    TimeUnit.SECONDS
            );

            for (Future<String> hash : hashes) {
                assertThat(hash.get()).isEqualTo(expected);
            }
        } finally {
            executor.shutdownNow();
        }
    }

    @Test
    void shouldRejectNullRawToken() {

        assertThatThrownBy(() -> new Sha256InviteTokenHasher().hash(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("rawToken must not be null");
    }

    @Test
    void shouldRejectEmptyRawToken() {

        assertThatThrownBy(() -> new Sha256InviteTokenHasher().hash(""))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("rawToken must not be blank");
    }

    @Test
    void shouldRejectBlankRawToken() {

        assertThatThrownBy(() -> new Sha256InviteTokenHasher().hash("   "))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("rawToken must not be blank");
    }
}
