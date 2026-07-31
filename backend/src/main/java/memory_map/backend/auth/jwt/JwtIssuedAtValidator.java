package memory_map.backend.auth.jwt;

import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;

import java.util.Objects;

final class JwtIssuedAtValidator implements OAuth2TokenValidator<Jwt> {

    private static final String ISSUED_AT_CLAIM = "iat";

    private static final OAuth2Error MISSING_ISSUED_AT_ERROR =
            new OAuth2Error(
                    "invalid_token",
                    "The required iat claim is missing",
                    null
            );

    @Override
    public OAuth2TokenValidatorResult validate(Jwt jwt) {
        Objects.requireNonNull(jwt, "jwt must not be null");

        if (jwt.getClaims().containsKey(ISSUED_AT_CLAIM)) {
            return OAuth2TokenValidatorResult.success();
        }

        return OAuth2TokenValidatorResult.failure(
                MISSING_ISSUED_AT_ERROR
        );
    }
}
