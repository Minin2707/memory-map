package memory_map.backend.story.repository;

import memory_map.backend.story.application.UserStory;
import memory_map.backend.story.domain.Story;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.UUID;

public class UserStoryRowMapper implements RowMapper<UserStory> {

    @Override
    public UserStory mapRow(ResultSet rs, int rowNum) throws SQLException {
        Story story = new Story(
                rs.getObject("id", UUID.class),
                rs.getObject("owner_id", UUID.class),
                rs.getString("title"),
                rs.getString("description"),
                rs.getObject("created_at", OffsetDateTime.class).toInstant(),
                rs.getObject("updated_at", OffsetDateTime.class).toInstant()
        );

        return new UserStory(
                story,
                StoryRole.valueOf(rs.getString("role"))
        );
    }
}
