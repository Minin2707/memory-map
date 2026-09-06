package memory_map.backend.media.repository;

import memory_map.backend.media.application.StorageCleanupTask;
import memory_map.backend.media.storage.StorageKey;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.UUID;

public class StorageCleanupTaskRowMapper
        implements RowMapper<StorageCleanupTask> {

    @Override
    public StorageCleanupTask mapRow(ResultSet rs, int rowNum)
            throws SQLException {

        UUID id = rs.getObject("id", UUID.class);
        StorageKey storageKey = new StorageKey(rs.getString("storage_key"));
        OffsetDateTime createdAt =
                rs.getObject("created_at", OffsetDateTime.class);
        OffsetDateTime nextAttemptAt =
                rs.getObject("next_attempt_at", OffsetDateTime.class);
        int attemptCount = rs.getInt("attempt_count");

        return new StorageCleanupTask(
                id,
                storageKey,
                createdAt.toInstant(),
                nextAttemptAt.toInstant(),
                attemptCount
        );
    }
}
