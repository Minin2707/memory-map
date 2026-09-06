function normalizedAccessToken() {
  const rawValue = __ENV.MM_API_ACCESS_TOKEN;

  if (rawValue === undefined) {
    throw new Error('MM_API_ACCESS_TOKEN is required');
  }

  const trimmed = String(rawValue).trim();
  if (trimmed.length === 0) {
    throw new Error('MM_API_ACCESS_TOKEN is empty');
  }

  const bearerMatch = trimmed.match(/^Bearer\s+(.+)$/i);
  if (bearerMatch === null) {
    return trimmed;
  }

  const token = bearerMatch[1].trim();
  if (token.length === 0) {
    throw new Error('MM_API_ACCESS_TOKEN is empty');
  }

  return token;
}

export function requireAccessToken() {
  return normalizedAccessToken();
}

export function authHeaders(additionalHeaders = {}) {
  const headers = {};

  for (const [name, value] of Object.entries(additionalHeaders)) {
    if (name.toLowerCase() === 'authorization') {
      throw new Error('Authorization header is managed by authHeaders');
    }

    headers[name] = value;
  }

  headers.Authorization = `Bearer ${normalizedAccessToken()}`;
  return headers;
}
