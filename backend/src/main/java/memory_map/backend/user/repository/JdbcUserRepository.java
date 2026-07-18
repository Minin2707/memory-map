package memory_map.backend.user.repository;

import memory_map.backend.user.domain.User;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public class JdbcUserRepository implements UserRepository {

    private static final String INSERT_SQL = """
            INSERT INTO users (
                google_subject,
                display_name,
                avatar_url
            )
            VALUES (
                :googleSubject,
                :displayName,
                :avatarUrl
            )
            RETURNING *
            """;

    private static final String FIND_BY_ID_SQL = """
            SELECT *
            FROM users
            WHERE id = :id
            """;

    private static final String FIND_BY_GOOGLE_SUBJECT_SQL = """
            SELECT *
            FROM users
            WHERE google_subject = :googleSubject
            """;

    private final JdbcClient jdbcClient;
    private final UserRowMapper rowMapper;

    public JdbcUserRepository(
            JdbcClient jdbcClient,
            UserRowMapper rowMapper
    ) {
        this.jdbcClient = jdbcClient;
        this.rowMapper = rowMapper;
    }

    @Override
    public User save(User user) {

        return jdbcClient.sql(INSERT_SQL)
                .param("googleSubject", user.googleSubject())
                .param("displayName", user.displayName())
                .param("avatarUrl", user.avatarUrl())
                .query(rowMapper)
                .single();
    }

    @Override
    public Optional<User> findById(UUID id) {

        return jdbcClient.sql(FIND_BY_ID_SQL)
                .param("id", id)
                .query(rowMapper)
                .optional();
    }

    @Override
    public Optional<User> findByGoogleSubject(String googleSubject) {

        return jdbcClient.sql(FIND_BY_GOOGLE_SUBJECT_SQL)
                .param("googleSubject", googleSubject)
                .query(rowMapper)
                .optional();
    }

}
