import { smokeOptions } from './lib/config.js';
import { discoverStory } from './lib/fixtures.js';
import { getJson, checkArray, checkOrFail } from './lib/http.js';
import { runScenario } from './lib/scenario.js';

export const options = smokeOptions();

export function setup() {
  return {
    storyId: discoverStory(),
  };
}

export default function (data) {
  runScenario('participants-read', () => {
    const storyId = data.storyId;
    const participants = checkArray(
      getJson(`/api/v1/stories/${encodeURIComponent(storyId)}/participants`, {
        endpoint: 'participants-list',
      }),
      'participants-list',
    );

    checkOrFail(
      participants,
      {
        'participants-list items have user ids when present': (items) =>
          items.every((item) => (
            item !== null &&
            typeof item === 'object' &&
            typeof item.userId === 'string' &&
            item.userId.trim().length > 0
          )),
      },
      'participants-list response items are malformed',
    );
  });
}
