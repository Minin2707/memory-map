import { smokeOptions } from './lib/config.js';
import { listStories } from './lib/fixtures.js';
import { checkOrFail } from './lib/http.js';
import { runScenario, validateScenarioPrerequisites } from './lib/scenario.js';

export const options = smokeOptions();

export function setup() {
  validateScenarioPrerequisites();
}

export default function () {
  runScenario('stories-read', () => {
    const stories = listStories();

    checkOrFail(
      stories,
      {
        'stories-list items have ids when present': (items) =>
          items.every((item) => (
            item !== null &&
            typeof item === 'object' &&
            typeof item.id === 'string' &&
            item.id.trim().length > 0
          )),
      },
      'stories-list response items are malformed',
    );
  });
}
