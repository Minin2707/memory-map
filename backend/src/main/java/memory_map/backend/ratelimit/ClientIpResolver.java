package memory_map.backend.ratelimit;

import jakarta.servlet.http.HttpServletRequest;

import java.util.Optional;

public interface ClientIpResolver {

    Optional<String> resolveClientIp(HttpServletRequest request);
}
