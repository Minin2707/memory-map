package memory_map.backend.invite.application;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.Objects;
import java.util.regex.Pattern;

public class DefaultInviteLinkFactory implements InviteLinkFactory {

    private static final Pattern BASE64_URL_TOKEN =
            Pattern.compile("[A-Za-z0-9_-]+");

    private final InviteProperties properties;

    public DefaultInviteLinkFactory(InviteProperties properties) {
        this.properties = Objects.requireNonNull(
                properties,
                "properties must not be null"
        );
    }

    @Override
    public URI create(String rawToken) {
        Objects.requireNonNull(rawToken, "rawToken must not be null");

        if (rawToken.isBlank()) {
            throw new IllegalArgumentException(
                    "rawToken must not be blank"
            );
        }

        if (!BASE64_URL_TOKEN.matcher(rawToken).matches()) {
            throw new IllegalArgumentException(
                    "rawToken must be Base64URL path-safe"
            );
        }

        URI baseUrl = properties.baseUrl();
        try {
            return new URI(
                    baseUrl.getScheme(),
                    baseUrl.getRawAuthority(),
                    "/invite/" + rawToken,
                    null,
                    null
            );
        } catch (URISyntaxException exception) {
            throw new IllegalStateException(
                    "Invite link creation failed",
                    exception
            );
        }
    }
}
