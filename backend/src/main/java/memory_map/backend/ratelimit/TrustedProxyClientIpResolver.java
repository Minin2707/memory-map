package memory_map.backend.ratelimit;

import jakarta.servlet.http.HttpServletRequest;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.Optional;

public class TrustedProxyClientIpResolver implements ClientIpResolver {

    private static final String X_FORWARDED_FOR = "X-Forwarded-For";

    private final List<IpRange> trustedProxies;

    public TrustedProxyClientIpResolver(List<String> trustedProxies) {
        Objects.requireNonNull(
                trustedProxies,
                "trustedProxies must not be null"
        );
        this.trustedProxies = trustedProxies.stream()
                .map(IpRange::parse)
                .toList();
    }

    @Override
    public Optional<String> resolveClientIp(HttpServletRequest request) {
        Objects.requireNonNull(request, "request must not be null");

        Optional<InetAddress> maybeRemoteAddress =
                parseIpLiteral(request.getRemoteAddr());
        if (maybeRemoteAddress.isEmpty()) {
            return Optional.empty();
        }

        InetAddress remoteAddress = maybeRemoteAddress.get();
        if (!isTrustedProxy(remoteAddress)) {
            return Optional.of(canonicalAddress(remoteAddress));
        }

        String forwardedFor = request.getHeader(X_FORWARDED_FOR);
        if (forwardedFor == null || forwardedFor.isBlank()) {
            return Optional.of(canonicalAddress(remoteAddress));
        }

        Optional<List<InetAddress>> maybeForwardedChain =
                parseForwardedFor(forwardedFor);
        if (maybeForwardedChain.isEmpty()) {
            return Optional.of(canonicalAddress(remoteAddress));
        }

        List<InetAddress> chain = new ArrayList<>(maybeForwardedChain.get());
        chain.add(remoteAddress);

        for (int index = chain.size() - 1; index >= 0; index--) {
            InetAddress address = chain.get(index);
            if (!isTrustedProxy(address)) {
                return Optional.of(canonicalAddress(address));
            }
        }

        return Optional.of(canonicalAddress(chain.get(0)));
    }

    private boolean isTrustedProxy(InetAddress address) {
        for (IpRange trustedProxy : trustedProxies) {
            if (trustedProxy.contains(address)) {
                return true;
            }
        }
        return false;
    }

    private static Optional<List<InetAddress>> parseForwardedFor(
            String forwardedFor
    ) {
        String[] values = forwardedFor.split(",", -1);
        List<InetAddress> addresses = new ArrayList<>();
        for (String value : values) {
            Optional<InetAddress> maybeAddress = parseIpLiteral(value.trim());
            if (maybeAddress.isEmpty()) {
                return Optional.empty();
            }
            addresses.add(maybeAddress.get());
        }
        return addresses.isEmpty() ? Optional.empty() : Optional.of(addresses);
    }

    private static Optional<InetAddress> parseIpLiteral(String value) {
        if (value == null || value.isBlank()) {
            return Optional.empty();
        }

        String normalized = value.trim();
        if (normalized.startsWith("[") && normalized.endsWith("]")) {
            normalized = normalized.substring(1, normalized.length() - 1);
        }

        if (normalized.indexOf(':') >= 0) {
            return parseIpv6Literal(normalized);
        }

        return parseIpv4Literal(normalized);
    }

    private static Optional<InetAddress> parseIpv4Literal(String value) {
        String[] parts = value.split("\\.", -1);
        if (parts.length != 4) {
            return Optional.empty();
        }

        byte[] bytes = new byte[4];
        for (int index = 0; index < parts.length; index++) {
            String part = parts[index];
            if (part.isEmpty() || part.length() > 3) {
                return Optional.empty();
            }
            for (int charIndex = 0; charIndex < part.length(); charIndex++) {
                if (!Character.isDigit(part.charAt(charIndex))) {
                    return Optional.empty();
                }
            }
            int byteValue = Integer.parseInt(part);
            if (byteValue > 255) {
                return Optional.empty();
            }
            bytes[index] = (byte) byteValue;
        }

        try {
            return Optional.of(InetAddress.getByAddress(bytes));
        } catch (UnknownHostException exception) {
            return Optional.empty();
        }
    }

    private static Optional<InetAddress> parseIpv6Literal(String value) {
        for (int index = 0; index < value.length(); index++) {
            char character = value.charAt(index);
            if (!isIpv6LiteralCharacter(character)) {
                return Optional.empty();
            }
        }

        try {
            InetAddress address = InetAddress.getByName(value);
            return address.getAddress().length == 16
                    ? Optional.of(address)
                    : Optional.empty();
        } catch (UnknownHostException exception) {
            return Optional.empty();
        }
    }

    private static boolean isIpv6LiteralCharacter(char character) {
        return Character.digit(character, 16) >= 0 ||
                character == ':' ||
                character == '.';
    }

    private static String canonicalAddress(InetAddress address) {
        return address.getHostAddress();
    }

    private record IpRange(byte[] networkAddress, int prefixLength) {

        private static IpRange parse(String value) {
            if (value == null || value.isBlank()) {
                throw new IllegalArgumentException(
                        "trusted proxy range must not be blank"
                );
            }

            String[] parts = value.trim().split("/", -1);
            if (parts.length > 2) {
                throw new IllegalArgumentException(
                        "trusted proxy range must be an IP literal or CIDR"
                );
            }

            InetAddress address = parseIpLiteral(parts[0])
                    .orElseThrow(() -> new IllegalArgumentException(
                            "trusted proxy range must start with an IP literal"
                    ));
            int maxPrefixLength = address.getAddress().length * 8;
            int prefixLength = parts.length == 1
                    ? maxPrefixLength
                    : parsePrefixLength(parts[1], maxPrefixLength);

            return new IpRange(address.getAddress(), prefixLength);
        }

        private static int parsePrefixLength(
                String value,
                int maxPrefixLength
        ) {
            if (value.isBlank()) {
                throw new IllegalArgumentException(
                        "trusted proxy CIDR prefix must not be blank"
                );
            }

            int prefixLength;
            try {
                prefixLength = Integer.parseInt(value);
            } catch (NumberFormatException exception) {
                throw new IllegalArgumentException(
                        "trusted proxy CIDR prefix must be numeric",
                        exception
                );
            }

            if (prefixLength < 0 || prefixLength > maxPrefixLength) {
                throw new IllegalArgumentException(
                        "trusted proxy CIDR prefix is out of range"
                );
            }
            return prefixLength;
        }

        private boolean contains(InetAddress address) {
            byte[] candidate = address.getAddress();
            if (candidate.length != networkAddress.length) {
                return false;
            }

            int fullBytes = prefixLength / 8;
            int remainingBits = prefixLength % 8;

            for (int index = 0; index < fullBytes; index++) {
                if (candidate[index] != networkAddress[index]) {
                    return false;
                }
            }

            if (remainingBits == 0) {
                return true;
            }

            int mask = 0xFF & (0xFF << (8 - remainingBits));
            return ((candidate[fullBytes] & 0xFF) & mask) ==
                    ((networkAddress[fullBytes] & 0xFF) & mask);
        }
    }
}
