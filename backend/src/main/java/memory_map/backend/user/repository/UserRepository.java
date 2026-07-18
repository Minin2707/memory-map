package memory_map.backend.user.repository;

import memory_map.backend.user.domain.User;

import java.util.Optional;
import java.util.UUID;

public interface UserRepository {

    User save(User user);

    Optional<User> findById(UUID id);

    Optional<User> findByGoogleSubject(String googleSubject);

}
