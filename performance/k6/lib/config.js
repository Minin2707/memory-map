const DEFAULT_BASE_URL = 'http://localhost:8080';
function trimRequiredEnv(name, defaultValue) {
  const rawValue = __ENV[name] === undefined ? defaultValue : __ENV[name];
  const value = String(rawValue).trim();
  if (value.length === 0) {
    throw new Error(`${name} must not be blank`);
  }

  return value;
}

function normalizeBaseUrl(rawBaseUrl) {
  const match = String(rawBaseUrl).match(
    /^http:\/\/(localhost|127\.0\.0\.1|\[::1\])(?::([0-9]+))?\/?$/i,
  );

  if (match === null) {
    throw new Error(
      'MM_API_BASE_URL must be http://localhost[:port], '
        + 'http://127.0.0.1[:port], or http://[::1][:port]',
    );
  }

  const port = match[2];
  if (port !== undefined) {
    const parsedPort = Number.parseInt(port, 10);
    if (
      !Number.isFinite(parsedPort) ||
      String(parsedPort) !== port ||
      parsedPort < 1 ||
      parsedPort > 65535
    ) {
      throw new Error('MM_API_BASE_URL contains an invalid port');
    }
  }

  const host = match[1].toLowerCase();
  return `http://${host}${port === undefined ? '' : `:${port}`}`;
}

export function baseUrl() {
  return normalizeBaseUrl(trimRequiredEnv('MM_API_BASE_URL', DEFAULT_BASE_URL));
}

export function iterations({
  defaultIterations = 10,
  maxIterations = 100,
} = {}) {
  const rawValue = trimRequiredEnv(
    'MM_K6_ITERATIONS',
    String(defaultIterations),
  );
  const parsed = Number.parseInt(rawValue, 10);

  if (!Number.isFinite(parsed) || String(parsed) !== rawValue) {
    throw new Error('MM_K6_ITERATIONS must be a positive integer');
  }

  if (parsed < 1 || parsed > maxIterations) {
    throw new Error(`MM_K6_ITERATIONS must be between 1 and ${maxIterations}`);
  }

  return parsed;
}

export function smokeOptions({
  defaultIterations = 10,
  maxIterations = 100,
  durationThreshold = ['p(95)<1000'],
  additionalThresholds = {},
} = {}) {
  const thresholds = {
    scenario_success: ['rate==1'],
    checks: ['rate==1'],
    http_req_failed: ['rate==0'],
    ...additionalThresholds,
  };

  if (durationThreshold !== null) {
    thresholds.http_req_duration = durationThreshold;
  }

  return {
    scenarios: {
      smoke: {
        executor: 'shared-iterations',
        vus: 1,
        iterations: iterations({ defaultIterations, maxIterations }),
        maxDuration: '2m',
      },
    },
    thresholds,
    systemTags: ['status', 'method', 'name', 'group', 'check', 'error', 'scenario'],
  };
}
