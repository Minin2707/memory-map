package memory_map.backend.auth.refresh;

import java.util.Objects;

public final class RawRefreshToken {

    private final String value;

    public RawRefreshToken(String value) {
        this.value = Objects.requireNonNull(
                value,
                "value must not be null"
        );

        if (value.isBlank()) {
            throw new IllegalArgumentException(
                    "value must not be blank"
            );
        }
    }

    public String value() {
        return value;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }

        if (!(other instanceof RawRefreshToken that)) {
            return false;
        }

        return value.equals(that.value);
    }

    @Override
    public int hashCode() {
        return value.hashCode();
    }

    @Override
    public String toString() {
        return "RawRefreshToken[REDACTED]";
    }
}
