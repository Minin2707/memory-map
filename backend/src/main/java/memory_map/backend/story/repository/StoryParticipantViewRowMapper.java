package memory_map.backend.story.repository;

import memory_map.backend.story.application.StoryParticipantView;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.UUID;

public class StoryParticipantViewRowMapper
        implements RowMapper<StoryParticipantView> {

    @Override
    public StoryParticipantView mapRow(ResultSet rs, int rowNum)
            throws SQLException {

        return new StoryParticipantView(
                rs.getObject("user_id", UUID.class),
                rs.getString("display_name"),
                rs.getString("avatar_url"),
                StoryRole.valueOf(rs.getString("role")),
                rs.getObject("joined_at", OffsetDateTime.class).toInstant()
        );
    }
}
