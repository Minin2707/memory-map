package memory_map.backend.auth.repository;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;

class RefreshTokenMigrationTest {

    @Test
    void shouldPreserveExistingRowsWithFamilyIdBackfill()
            throws IOException {

        String migration = Files.readString(Path.of(
                "src/main/resources/db/migration/" +
                        "V11__add_refresh_token_family_and_consumed_state.sql"
        ));

        assertThat(migration)
                .contains("ADD COLUMN family_id UUID")
                .contains("ADD COLUMN consumed_at TIMESTAMPTZ")
                .contains("SET family_id = id")
                .contains("ALTER COLUMN family_id SET NOT NULL")
                .contains("idx_refresh_tokens_family_active")
                .contains("WHERE consumed_at IS NULL")
                .contains("AND revoked_at IS NULL");
    }
}
