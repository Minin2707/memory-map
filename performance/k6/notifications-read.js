import { smokeOptions } from './lib/config.js';
import { getJson, checkArray, checkObject, checkOrFail } from './lib/http.js';
import { runScenario, validateScenarioPrerequisites } from './lib/scenario.js';

export const options = smokeOptions();

export function setup() {
  validateScenarioPrerequisites();
}

export default function () {
  runScenario('notifications-read', () => {
    const notifications = checkArray(
      getJson('/api/v1/notifications', {
        endpoint: 'notifications-list',
        query: { limit: 50 },
      }),
      'notifications-list',
    );
    checkOrFail(
      notifications,
      {
        'notifications-list items are objects': (items) =>
          items.every((item) => item !== null && typeof item === 'object'),
      },
      'notifications-list response items are malformed',
    );

    const unreadCount = checkObject(
      getJson('/api/v1/notifications/unread-count', {
        endpoint: 'notifications-unread-count',
      }),
      'notifications-unread-count',
    );
    checkOrFail(
      unreadCount,
      {
        'notifications-unread-count has non-negative count': (data) =>
          Number.isInteger(data.count) && data.count >= 0,
      },
      'notifications-unread-count response is malformed',
    );
  });
}
