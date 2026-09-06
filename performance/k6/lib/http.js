import { check, fail } from 'k6';
import http from 'k6/http';

import { authHeaders } from './auth.js';
import { baseUrl } from './config.js';

function apiUrl(path, query = undefined) {
  if (typeof path !== 'string' || path.trim().length === 0) {
    throw new Error('API path must not be blank');
  }

  if (!path.startsWith('/')) {
    throw new Error('API path must be absolute');
  }

  const url = `${baseUrl()}${path}`;
  if (query === undefined) {
    return url;
  }

  const entries = Object.entries(query)
    .filter(([, value]) => value !== undefined && value !== null)
    .map(([name, value]) => (
      `${encodeURIComponent(name)}=${encodeURIComponent(String(value))}`
    ));

  if (entries.length === 0) {
    return url;
  }

  return `${url}?${entries.join('&')}`;
}

export function authenticatedGet(
  path,
  {
    endpoint,
    name = endpoint,
    stage = 'local-smoke',
    expectedStatus = 200,
    query,
    headers = {},
    responseType,
  } = {},
) {
  return authenticatedRequest('GET', path, undefined, {
    endpoint,
    name,
    stage,
    expectedStatus,
    query,
    headers,
    responseType,
  });
}

export function authenticatedPost(
  path,
  body,
  options = {},
) {
  return authenticatedRequest('POST', path, body, options);
}

export function authenticatedMultipartPost(
  path,
  formData,
  options = {},
) {
  return authenticatedRequest('POST', path, formData, {
    ...options,
    serializeJson: false,
  });
}

export function authenticatedPatch(
  path,
  body,
  options = {},
) {
  return authenticatedRequest('PATCH', path, body, options);
}

export function authenticatedDelete(
  path,
  options = {},
) {
  return authenticatedRequest('DELETE', path, undefined, options);
}

function authenticatedRequest(
  method,
  path,
  body,
  {
    endpoint,
    name = endpoint,
    stage = 'local-smoke',
    expectedStatus = 200,
    query,
    headers = {},
    responseType,
    serializeJson = true,
  } = {},
) {
  if (typeof endpoint !== 'string' || endpoint.trim().length === 0) {
    throw new Error('endpoint tag is required');
  }

  const requestHeaders = authHeaders(headers);
  const params = {
    headers: requestHeaders,
    responseCallback: http.expectedStatuses(expectedStatus),
    tags: {
      endpoint,
      stage,
      name,
      method,
    },
  };

  if (responseType !== undefined) {
    params.responseType = responseType;
  }

  const url = apiUrl(path, query);
  const response = method === 'GET'
    ? http.get(url, params)
    : method === 'POST'
      ? http.post(
        url,
        serializeJson ? JSON.stringify(body) : body,
        params,
      )
      : method === 'PATCH'
        ? http.patch(url, JSON.stringify(body), params)
        : http.del(url, undefined, params);

  const ok = check(response, {
    [`${endpoint} status is ${expectedStatus}`]: (res) =>
      res.status === expectedStatus,
  });

  if (!ok) {
    fail(`${endpoint} returned unexpected status ${response.status}`);
  }

  return response;
}

export function jsonHeaders(additionalHeaders = {}) {
  return {
    ...(additionalHeaders || {}),
    'Content-Type': 'application/json',
  };
}

export function postJson(path, body, options = {}) {
  const response = authenticatedPost(path, body, {
    ...options,
    headers: jsonHeaders(options.headers),
  });

  try {
    return response.json();
  } catch {
    fail(`${options.endpoint} returned malformed JSON`);
  }
}

export function patchJson(path, body, options = {}) {
  const response = authenticatedPatch(path, body, {
    ...options,
    headers: jsonHeaders(options.headers),
  });

  try {
    return response.json();
  } catch {
    fail(`${options.endpoint} returned malformed JSON`);
  }
}

export function getJson(path, options = {}) {
  const response = authenticatedGet(path, options);

  try {
    return response.json();
  } catch {
    fail(`${options.endpoint} returned malformed JSON`);
  }
}

export function checkArray(value, endpoint) {
  const ok = check(value, {
    [`${endpoint} response is an array`]: (data) => Array.isArray(data),
  });

  if (!ok) {
    fail(`${endpoint} response contract is malformed`);
  }

  return value;
}

export function checkObject(value, endpoint) {
  const ok = check(value, {
    [`${endpoint} response is an object`]: (data) =>
      data !== null && typeof data === 'object' && !Array.isArray(data),
  });

  if (!ok) {
    fail(`${endpoint} response contract is malformed`);
  }

  return value;
}

export function checkOrFail(value, checks, failureMessage) {
  if (!check(value, checks)) {
    fail(failureMessage);
  }
}
