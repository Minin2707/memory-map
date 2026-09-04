package memory_map.backend.invite.repository;

import memory_map.backend.invite.domain.Invite;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.UUID;

public class InviteRowMapper implements RowMapper<Invite> {

    @Override
    public Invite mapRow(ResultSet rs, int rowNum) throws SQLException {

        UUID id = rs.getObject("id", UUID.class);
        UUID storyId = rs.getObject("story_id", UUID.class);
        StoryRole role = StoryRole.valueOf(rs.getString("role"));
        String tokenHash = rs.getString("token_hash");
        UUID createdBy = rs.getObject("created_by", UUID.class);
        OffsetDateTime createdAt = rs.getObject("created_at", OffsetDateTime.class);
        OffsetDateTime expiresAt = rs.getObject("expires_at", OffsetDateTime.class);
        OffsetDateTime usedAt = rs.getObject("used_at", OffsetDateTime.class);
        Instant usedAtInstant = usedAt == null ? null : usedAt.toInstant();

        return new Invite(
                id,
                storyId,
                role,
                tokenHash,
                createdBy,
                createdAt.toInstant(),
                expiresAt.toInstant(),
                usedAtInstant
        );
    }

}
