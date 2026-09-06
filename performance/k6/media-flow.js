import http from 'k6/http';

import { smokeOptions } from './lib/config.js';
import { discoverStory } from './lib/fixtures.js';
import {
  authenticatedDelete,
  authenticatedGet,
  authenticatedMultipartPost,
  checkObject,
  checkOrFail,
  postJson,
} from './lib/http.js';
import { runScenario } from './lib/scenario.js';

const MEDIA_FIXTURE_FILE_NAME = 'k6-media-fixture.jpg';
const MEDIA_FIXTURE_CONTENT_TYPE = 'image/jpeg';
const MEDIA_FIXTURE_BYTES = open('./fixtures/k6-media-fixture.jpg', 'b');

validateJpegFixture(MEDIA_FIXTURE_BYTES);

const ENDPOINT_DURATION_THRESHOLDS = {
  'http_req_duration{endpoint:memory-create-for-media}': ['p(95)<1000'],
  'http_req_duration{endpoint:media-thumbnail}': ['p(95)<1000'],
  'http_req_duration{endpoint:media-display}': ['p(95)<1000'],
  'http_req_duration{endpoint:media-delete}': ['p(95)<1000'],
  'http_req_duration{endpoint:media-post-delete-check}': ['p(95)<1000'],
  'http_req_duration{endpoint:memory-cleanup}': ['p(95)<1000'],
  'http_req_duration{endpoint:media-upload}': ['p(95)<5000'],
};

export const options = smokeOptions({
  defaultIterations: 2,
  maxIterations: 10,
  durationThreshold: null,
  additionalThresholds: ENDPOINT_DURATION_THRESHOLDS,
});

export function setup() {
  return {
    storyId: discoverStory(),
  };
}

export default function (data) {
  runScenario('media-flow', () => {
    const storyId = data.storyId;
    let createdMemoryId;
    let uploadedMediaId;
    let mediaDeleteSucceeded = false;
    let memoryDeleteSucceeded = false;
    let cleanupError;

    try {
      const createPayload = createMemoryPayload();
      const createdMemory = checkObject(
        postJson(
          `/api/v1/stories/${encodeURIComponent(storyId)}/memories`,
          createPayload,
          {
            endpoint: 'memory-create-for-media',
            expectedStatus: 201,
          },
        ),
        'memory-create-for-media',
      );

      createdMemoryId = requireId(
        createdMemory,
        'id',
        'memory-create-for-media',
      );
      assertCreatedMemory(createdMemory, createdMemoryId, storyId);

      const uploadedMedia = uploadMedia(createdMemoryId);
      uploadedMediaId = requireId(uploadedMedia, 'id', 'media-upload');
      assertUploadedMedia(uploadedMedia, uploadedMediaId, createdMemoryId);

      downloadMediaRepresentation(
        uploadedMedia.thumbnailUrl,
        'media-thumbnail',
      );
      downloadMediaRepresentation(uploadedMedia.displayUrl, 'media-display');

      deleteUploadedMedia(uploadedMediaId);
      mediaDeleteSucceeded = true;

      authenticatedGet(
        `/api/v1/media/${encodeURIComponent(uploadedMediaId)}/thumbnail`,
        {
          endpoint: 'media-post-delete-check',
          expectedStatus: 404,
        },
      );

      deleteCreatedMemory(createdMemoryId);
      memoryDeleteSucceeded = true;
    } finally {
      if (uploadedMediaId !== undefined && !mediaDeleteSucceeded) {
        try {
          deleteUploadedMedia(uploadedMediaId);
        } catch {
          cleanupError = new Error('media cleanup failed');
        }
      }

      if (createdMemoryId !== undefined && !memoryDeleteSucceeded) {
        try {
          deleteCreatedMemory(createdMemoryId);
        } catch {
          cleanupError = new Error('memory cleanup failed');
        }
      }

      if (cleanupError !== undefined) {
        throw cleanupError;
      }
    }
  });
}

function createMemoryPayload() {
  const token = `${Date.now()}_vu${__VU}_iter${__ITER}`;
  const title = `__k6_local_media_${token}`;

  return {
    title,
    description: `Created by local k6 private media automation ${token}`,
    placeName: 'Local private media checkpoint',
    latitude: 41.7151,
    longitude: 44.8271,
    eventDate: '2020-01-15',
  };
}

function uploadMedia(memoryId) {
  const response = authenticatedMultipartPost(
    `/api/v1/memories/${encodeURIComponent(memoryId)}/media`,
    {
      file: http.file(
        MEDIA_FIXTURE_BYTES,
        MEDIA_FIXTURE_FILE_NAME,
        MEDIA_FIXTURE_CONTENT_TYPE,
      ),
    },
    {
      endpoint: 'media-upload',
      expectedStatus: 201,
    },
  );

  try {
    return response.json();
  } catch {
    throw new Error('media-upload returned malformed JSON');
  }
}

function downloadMediaRepresentation(path, endpoint) {
  assertBackendMediaPath(path, endpoint);

  const response = authenticatedGet(path, {
    endpoint,
    expectedStatus: 200,
    responseType: 'binary',
  });
  const bodySize = responseBodySize(response.body);
  const contentType = headerValue(response, 'Content-Type');

  checkOrFail(
    response,
    {
      [`${endpoint} body is not empty`]: () => bodySize > 0,
      [`${endpoint} content type is jpeg`]: () =>
        typeof contentType === 'string'
          && contentType.toLowerCase().startsWith('image/jpeg'),
    },
    `${endpoint} response is malformed`,
  );
}

function assertCreatedMemory(memory, expectedMemoryId, expectedStoryId) {
  checkOrFail(
    memory,
    {
      'memory-create-for-media id matches owned memory': (value) =>
        value.id === expectedMemoryId,
      'memory-create-for-media storyId matches selected story': (value) =>
        value.storyId === expectedStoryId,
    },
    'memory-create-for-media response identity is malformed',
  );
}

function assertUploadedMedia(media, expectedMediaId, expectedMemoryId) {
  checkOrFail(
    media,
    {
      'media-upload id matches uploaded media': (value) =>
        value.id === expectedMediaId,
      'media-upload memoryId matches created memory': (value) =>
        value.memoryId === expectedMemoryId,
      'media-upload type is photo': (value) => value.mediaType === 'PHOTO',
      'media-upload mime type is jpeg': (value) =>
        value.mimeType === MEDIA_FIXTURE_CONTENT_TYPE,
      'media-upload display file size is positive': (value) =>
        Number.isFinite(value.displayFileSize) && value.displayFileSize > 0,
      'media-upload thumbnail file size is positive': (value) =>
        Number.isFinite(value.thumbnailFileSize)
          && value.thumbnailFileSize > 0,
      'media-upload thumbnail URL is media backend path': (value) =>
        isExpectedMediaPath(value.thumbnailUrl, expectedMediaId, 'thumbnail'),
      'media-upload display URL is media backend path': (value) =>
        isExpectedMediaPath(value.displayUrl, expectedMediaId, 'display'),
    },
    'media-upload response contract is malformed',
  );
}

function requireId(value, property, endpoint) {
  const id = value[property];
  checkOrFail(
    value,
    {
      [`${endpoint} response has ${property}`]: () =>
        typeof id === 'string' && id.trim().length > 0,
    },
    `${endpoint} response is missing ${property}`,
  );

  return id;
}

function assertBackendMediaPath(path, endpoint) {
  checkOrFail(
    { path },
    {
      [`${endpoint} URL is a backend media path`]: (value) =>
        typeof value.path === 'string'
          && /^\/api\/v1\/media\/[^/?#]+\/(thumbnail|display)$/.test(value.path),
    },
    `${endpoint} URL is malformed`,
  );
}

function isExpectedMediaPath(path, mediaId, representation) {
  return path === `/api/v1/media/${mediaId}/${representation}`;
}

function responseBodySize(body) {
  if (typeof body === 'string') {
    return body.length;
  }

  if (body !== null && typeof body === 'object') {
    if (Number.isFinite(body.byteLength)) {
      return body.byteLength;
    }

    if (Number.isFinite(body.length)) {
      return body.length;
    }
  }

  return 0;
}

function headerValue(response, name) {
  const requested = name.toLowerCase();

  for (const [headerName, value] of Object.entries(response.headers || {})) {
    if (headerName.toLowerCase() === requested) {
      return value;
    }
  }

  return undefined;
}

function deleteUploadedMedia(mediaId) {
  authenticatedDelete(
    `/api/v1/media/${encodeURIComponent(mediaId)}`,
    {
      endpoint: 'media-delete',
      expectedStatus: 204,
    },
  );
}

function deleteCreatedMemory(memoryId) {
  authenticatedDelete(
    `/api/v1/memories/${encodeURIComponent(memoryId)}`,
    {
      endpoint: 'memory-cleanup',
      expectedStatus: 204,
    },
  );
}

function validateJpegFixture(buffer) {
  const bytes = new Uint8Array(buffer);

  if (
    bytes.length === 0 ||
    bytes[0] !== 0xFF ||
    bytes[1] !== 0xD8 ||
    bytes[bytes.length - 2] !== 0xFF ||
    bytes[bytes.length - 1] !== 0xD9
  ) {
    throw new Error('private media fixture is not a JPEG byte stream');
  }
}
