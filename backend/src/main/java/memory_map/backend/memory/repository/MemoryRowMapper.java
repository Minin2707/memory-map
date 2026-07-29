package memory_map.backend.memory.repository;

import memory_map.backend.memory.domain.Memory;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

public class MemoryRowMapper implements RowMapper<Memory> {

    @Override
    public Memory mapRow(ResultSet rs, int rowNum) throws SQLException {

        UUID id = rs.getObject("id", UUID.class);
        UUID storyId = rs.getObject("story_id", UUID.class);
        UUID createdBy = rs.getObject("created_by", UUID.class);
        String title = rs.getString("title");
        String description = rs.getString("description");
        String placeName = rs.getString("place_name");
        double latitude = rs.getDouble("latitude");
        double longitude = rs.getDouble("longitude");
        LocalDate eventDate = rs.getObject("event_date", LocalDate.class);
        OffsetDateTime createdAt = rs.getObject("created_at", OffsetDateTime.class);
        OffsetDateTime updatedAt = rs.getObject("updated_at", OffsetDateTime.class);

        return new Memory(
                id,
                storyId,
                createdBy,
                title,
                description,
                placeName,
                latitude,
                longitude,
                eventDate,
                createdAt.toInstant(),
                updatedAt.toInstant()
        );
    }

}
