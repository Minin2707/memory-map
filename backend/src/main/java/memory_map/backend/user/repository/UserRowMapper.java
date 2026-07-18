package memory_map.backend.user.repository;

import memory_map.backend.user.domain.User;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Component;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.UUID;

@Component
public class UserRowMapper implements RowMapper<User> {

    @Override
    public User mapRow(ResultSet rs, int rowNum) throws SQLException {

        UUID id = rs.getObject("id", UUID.class);
        String googleSubject = rs.getString("google_subject");
        String displayName = rs.getString("display_name");
        String avatarUrl = rs.getString("avatar_url");
        Instant createdAt = rs.getTimestamp("created_at").toInstant();
        Instant updatedAt = rs.getTimestamp("updated_at").toInstant();

        return new User(
                id,
                googleSubject,
                displayName,
                avatarUrl,
                createdAt,
                updatedAt
        );
    }
}
