package memory_map.backend.user.repository;

import memory_map.backend.user.domain.User;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Component;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.UUID;

@Component
public class UserRowMapper implements RowMapper<User> {

    @Override
    public User mapRow(ResultSet rs, int rowNum) throws SQLException {

        UUID id = rs.getObject("id", UUID.class);
        String googleSubject = rs.getString("google_subject");
        String displayName = rs.getString("display_name");
        boolean displayNameCustomized = rs.getBoolean(
                "display_name_customized"
        );
        String avatarUrl = rs.getString("avatar_url");
        String customAvatarStorageKey =
                rs.getString("custom_avatar_storage_key");
        OffsetDateTime customAvatarUpdatedAt = rs.getObject(
                "custom_avatar_updated_at",
                OffsetDateTime.class
        );
        Instant createdAt = rs.getObject("created_at", OffsetDateTime.class).toInstant();
        Instant updatedAt = rs.getObject("updated_at", OffsetDateTime.class).toInstant();
        OffsetDateTime deletedAt = rs.getObject("deleted_at", OffsetDateTime.class);

        return new User(
                id,
                googleSubject,
                displayName,
                displayNameCustomized,
                avatarUrl,
                customAvatarStorageKey,
                customAvatarUpdatedAt == null
                        ? null
                        : customAvatarUpdatedAt.toInstant(),
                createdAt,
                updatedAt,
                deletedAt == null ? null : deletedAt.toInstant()
        );
    }
}
