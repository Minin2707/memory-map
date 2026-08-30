package memory_map.backend.ratelimit;

import jakarta.servlet.http.HttpServletRequest;

import java.util.Optional;
import java.util.Objects;

public class RateLimitPolicy {

    private final RateLimitProperties properties;

    public RateLimitPolicy(RateLimitProperties properties) {
        this.properties = Objects.requireNonNull(
                properties,
                "properties must not be null"
        );
    }

    public Optional<RateLimitRule> ruleFor(HttpServletRequest request) {
        Objects.requireNonNull(request, "request must not be null");

        String method = request.getMethod();
        String path = normalizedPath(request);

        if (method.equals("POST") && path.equals("/api/v1/auth/google")) {
            return Optional.of(rule(
                    RateLimitCategory.AUTH_LOGIN,
                    RateLimitIdentity.CLIENT_IP
            ));
        }

        if (method.equals("POST") && path.equals("/api/v1/auth/refresh")) {
            return Optional.of(rule(
                    RateLimitCategory.AUTH_REFRESH,
                    RateLimitIdentity.CLIENT_IP
            ));
        }

        if (method.equals("POST") && path.equals("/api/v1/auth/logout")) {
            return Optional.of(rule(
                    RateLimitCategory.AUTH_LOGOUT,
                    RateLimitIdentity.CLIENT_IP
            ));
        }

        if (method.equals("POST") &&
                matches(path, "/api/v1/invites/", "/accept")) {
            return Optional.of(rule(
                    RateLimitCategory.INVITE_ACCEPT,
                    RateLimitIdentity.AUTHENTICATED_USER
            ));
        }

        if (method.equals("POST") &&
                matches(path, "/api/v1/memories/", "/media")) {
            return Optional.of(rule(
                    RateLimitCategory.MEDIA_UPLOAD,
                    RateLimitIdentity.AUTHENTICATED_USER
            ));
        }

        if (method.equals("PUT") && path.equals("/api/v1/me/avatar")) {
            return Optional.of(rule(
                    RateLimitCategory.MEDIA_UPLOAD,
                    RateLimitIdentity.AUTHENTICATED_USER
            ));
        }

        if (method.equals("GET") &&
                (matches(path, "/api/v1/media/", "/thumbnail") ||
                        matches(path, "/api/v1/media/", "/display") ||
                        path.equals("/api/v1/me/avatar") ||
                        matches(path, "/api/v1/me/avatar/", "") ||
                        matchesStoryCoverRead(path))) {
            return Optional.of(rule(
                    RateLimitCategory.PRIVATE_MEDIA_READ,
                    RateLimitIdentity.AUTHENTICATED_USER
            ));
        }

        if (method.equals("GET") &&
                matches(path, "/api/v1/stories/", "/soundtrack/audio")) {
            return Optional.of(rule(
                    RateLimitCategory.SOUNDTRACK_STREAM,
                    RateLimitIdentity.AUTHENTICATED_USER
            ));
        }

        if (isNormalMutation(method, path)) {
            return Optional.of(rule(
                    RateLimitCategory.NORMAL_MUTATION,
                    RateLimitIdentity.AUTHENTICATED_USER
            ));
        }

        return Optional.empty();
    }

    private RateLimitRule rule(
            RateLimitCategory category,
            RateLimitIdentity identity
    ) {
        return properties.rule(category, identity);
    }

    private static String normalizedPath(HttpServletRequest request) {
        String path = request.getServletPath();
        if (path != null && !path.isBlank()) {
            return path;
        }

        String requestUri = request.getRequestURI();
        String contextPath = request.getContextPath();
        if (contextPath != null && !contextPath.isBlank() &&
                requestUri.startsWith(contextPath)) {
            return requestUri.substring(contextPath.length());
        }

        return requestUri;
    }

    private static boolean matches(
            String path,
            String prefix,
            String suffix
    ) {
        if (!path.startsWith(prefix) || !path.endsWith(suffix)) {
            return false;
        }

        String middle = path.substring(
                prefix.length(),
                path.length() - suffix.length()
        );

        return !middle.isBlank() && !middle.contains("/");
    }

    private static boolean matchesStoryCoverRead(String path) {
        return path.matches(
                "^/api/v1/stories/[^/]+/cover/(display|thumbnail)/[^/]+$"
        );
    }

    private static boolean isNormalMutation(String method, String path) {
        if (!path.startsWith("/api/v1/")) {
            return false;
        }

        if (method.equals("DELETE") && path.equals("/api/v1/me")) {
            return true;
        }

        if (method.equals("DELETE") && path.equals("/api/v1/me/avatar")) {
            return true;
        }

        if (method.equals("PATCH") &&
                path.equals("/api/v1/me/display-name")) {
            return true;
        }

        if (method.equals("POST") && path.equals("/api/v1/stories")) {
            return true;
        }

        if (method.equals("PATCH") &&
                matches(path, "/api/v1/stories/", "")) {
            return true;
        }

        if (method.equals("POST") &&
                matches(path, "/api/v1/stories/", "/invites")) {
            return true;
        }

        if (method.equals("POST") &&
                matches(path, "/api/v1/stories/", "/memories")) {
            return true;
        }

        if ((method.equals("PATCH") || method.equals("DELETE")) &&
                matches(path, "/api/v1/memories/", "")) {
            return true;
        }

        if (method.equals("DELETE") &&
                (matches(path, "/api/v1/stories/", "/participants/me") ||
                        path.matches(
                                "^/api/v1/stories/[^/]+/participants/[^/]+$"
                        ))) {
            return true;
        }

        if ((method.equals("PUT") || method.equals("DELETE")) &&
                matches(path, "/api/v1/stories/", "/soundtrack")) {
            return true;
        }

        return method.equals("DELETE") &&
                matches(path, "/api/v1/media/", "");
    }
}
