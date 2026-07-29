package memory_map.backend.storyparticipant.repository;

import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;

public class StoryParticipantRowMapper implements RowMapper<StoryParticipant> {

    @Override
    public StoryParticipant mapRow(ResultSet rs, int rowNum) throws SQLException {

        return new StoryParticipant(
                rs.getObject("story_id", java.util.UUID.class),
                rs.getObject("user_id", java.util.UUID.class),
                StoryRole.valueOf(rs.getString("role")),
                rs.getTimestamp("joined_at").toInstant()
        );
    }

}