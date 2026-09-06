import { smokeOptions } from './lib/config.js';
import { discoverStory } from './lib/fixtures.js';
import {
  authenticatedDelete,
  authenticatedGet,
  checkObject,
  checkOrFail,
  getJson,
  patchJson,
  postJson,
} from './lib/http.js';
import { runScenario } from './lib/scenario.js';

export const options = smokeOptions({
  defaultIterations: 5,
  maxIterations: 20,
});

export function setup() {
  return {
    storyId: discoverStory(),
  };
}

export default function (data) {
  runScenario('memory-crud', () => {
    const storyId = data.storyId;
    let createdMemoryId;
    let deleteAttempted = false;
    let deleted = false;

    try {
      const createPayload = createMemoryPayload();
      const created = checkObject(
        postJson(
          `/api/v1/stories/${encodeURIComponent(storyId)}/memories`,
          createPayload,
          {
            endpoint: 'memory-create',
            expectedStatus: 201,
          },
        ),
        'memory-create',
      );

      createdMemoryId = requireMemoryId(created, 'memory-create');
      assertMemoryIdentity(
        created,
        createdMemoryId,
        storyId,
        'memory-create',
      );
      assertMemoryFields(
        created,
        createPayload,
        'memory-create',
      );

      const readCreated = checkObject(
        getJson(`/api/v1/memories/${encodeURIComponent(createdMemoryId)}`, {
          endpoint: 'memory-read',
        }),
        'memory-read',
      );
      assertMemoryIdentity(
        readCreated,
        createdMemoryId,
        storyId,
        'memory-read',
      );
      assertMemoryFields(
        readCreated,
        createPayload,
        'memory-read',
      );

      const updatePayload = updateMemoryPayload(createPayload.title);
      const updated = checkObject(
        patchJson(
          `/api/v1/memories/${encodeURIComponent(createdMemoryId)}`,
          updatePayload,
          {
            endpoint: 'memory-update',
          },
        ),
        'memory-update',
      );
      assertMemoryIdentity(
        updated,
        createdMemoryId,
        storyId,
        'memory-update',
      );
      assertMemoryFields(
        updated,
        updatePayload,
        'memory-update',
      );

      const readUpdated = checkObject(
        getJson(`/api/v1/memories/${encodeURIComponent(createdMemoryId)}`, {
          endpoint: 'memory-read-updated',
        }),
        'memory-read-updated',
      );
      assertMemoryIdentity(
        readUpdated,
        createdMemoryId,
        storyId,
        'memory-read-updated',
      );
      assertMemoryFields(
        readUpdated,
        updatePayload,
        'memory-read-updated',
      );

      deleteAttempted = true;
      deleteCreatedMemory(createdMemoryId);
      deleted = true;

      authenticatedGet(
        `/api/v1/memories/${encodeURIComponent(createdMemoryId)}`,
        {
          endpoint: 'memory-post-delete-check',
          expectedStatus: 404,
        },
      );
    } finally {
      if (createdMemoryId !== undefined && !deleted && !deleteAttempted) {
        try {
          deleteAttempted = true;
          deleteCreatedMemory(createdMemoryId);
        } catch {
          throw new Error('memory cleanup failed');
        }
      }
    }
  });
}

function createMemoryPayload() {
  const token = `${Date.now()}_vu${__VU}_iter${__ITER}`;
  const title = `__k6_local_memory_${token}`;

  return {
    title,
    description: `Created by local k6 automation ${token}`,
    placeName: 'Local automation checkpoint',
    latitude: 41.7151,
    longitude: 44.8271,
    eventDate: '2020-01-15',
  };
}

function updateMemoryPayload(originalTitle) {
  return {
    title: `${originalTitle}_updated`,
    description: 'Updated by local k6 automation',
    placeName: 'Local automation checkpoint updated',
    latitude: 41.7161,
    longitude: 44.8281,
    eventDate: '2020-01-16',
  };
}

function requireMemoryId(memory, endpoint) {
  const id = memory.id;
  checkOrFail(
    memory,
    {
      [`${endpoint} response has memory id`]: () =>
        typeof id === 'string' && id.trim().length > 0,
    },
    `${endpoint} response is missing memory id`,
  );

  return id;
}

function assertMemoryIdentity(memory, expectedMemoryId, expectedStoryId, endpoint) {
  checkOrFail(
    memory,
    {
      [`${endpoint} id matches owned memory`]: (value) =>
        value.id === expectedMemoryId,
      [`${endpoint} storyId matches selected story`]: (value) =>
        value.storyId === expectedStoryId,
    },
    `${endpoint} response identity is malformed`,
  );
}

function assertMemoryFields(memory, expected, endpoint) {
  checkOrFail(
    memory,
    {
      [`${endpoint} title matches`]: (value) => value.title === expected.title,
      [`${endpoint} description matches`]: (value) =>
        value.description === expected.description,
      [`${endpoint} placeName matches`]: (value) =>
        value.placeName === expected.placeName,
      [`${endpoint} latitude matches`]: (value) =>
        value.latitude === expected.latitude,
      [`${endpoint} longitude matches`]: (value) =>
        value.longitude === expected.longitude,
      [`${endpoint} eventDate matches`]: (value) =>
        value.eventDate === expected.eventDate,
    },
    `${endpoint} response fields are malformed`,
  );
}

function deleteCreatedMemory(memoryId) {
  authenticatedDelete(
    `/api/v1/memories/${encodeURIComponent(memoryId)}`,
    {
      endpoint: 'memory-delete',
      expectedStatus: 204,
    },
  );
}
