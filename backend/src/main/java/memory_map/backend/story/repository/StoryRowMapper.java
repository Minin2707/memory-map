package memory_map.backend.story.repository;

import memory_map.backend.story.domain.Story;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Component;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.UUID;

@Component
public class StoryRowMapper implements RowMapper<Story> {

    @Override
    public Story mapRow(ResultSet rs, int rowNum) throws SQLException {
        return new Story(
                rs.getObject("id", UUID.class),
                rs.getObject("owner_id", UUID.class),
                rs.getString("title"),
                rs.getString("description"),
                rs.getObject("created_at", OffsetDateTime.class).toInstant(),
                rs.getObject("updated_at", OffsetDateTime.class).toInstant()
        );
    }

}
