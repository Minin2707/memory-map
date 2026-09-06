import { smokeOptions } from './lib/config.js';
import { discoverStory } from './lib/fixtures.js';
import { getJson, checkArray, checkObject, checkOrFail } from './lib/http.js';
import { runScenario } from './lib/scenario.js';

export const options = smokeOptions();

export function setup() {
  return {
    storyId: discoverStory(),
  };
}

export default function (data) {
  runScenario('story-details-read', () => {
    const storyId = data.storyId;

    const story = checkObject(
      getJson(`/api/v1/stories/${encodeURIComponent(storyId)}`, {
        endpoint: 'story-details',
      }),
      'story-details',
    );
    checkOrFail(
      story,
      {
        'story-details has id': (value) =>
          typeof value.id === 'string' && value.id.trim().length > 0,
      },
      'story-details response is missing id',
    );

    const memories = checkArray(
      getJson(`/api/v1/stories/${encodeURIComponent(storyId)}/memories`, {
        endpoint: 'story-memories-list',
      }),
      'story-memories-list',
    );
    checkOrFail(
      memories,
      {
        'story-memories-list items are objects': (items) =>
          items.every((item) => item !== null && typeof item === 'object'),
      },
      'story-memories-list response items are malformed',
    );

    const participants = checkArray(
      getJson(`/api/v1/stories/${encodeURIComponent(storyId)}/participants`, {
        endpoint: 'story-participants-summary',
      }),
      'story-participants-summary',
    );
    checkOrFail(
      participants,
      {
        'story-participants-summary items are objects': (items) =>
          items.every((item) => item !== null && typeof item === 'object'),
      },
      'story-participants-summary response items are malformed',
    );
  });
}
