import { check, fail } from 'k6';

import { getJson, checkArray, checkObject } from './http.js';

const STORIES_PATH = '/api/v1/stories';

function selectedStoryIdFromEnvironment() {
  const rawValue = __ENV.MM_K6_STORY_ID;
  if (rawValue === undefined) {
    return undefined;
  }

  const value = String(rawValue).trim();
  if (value.length === 0) {
    throw new Error('MM_K6_STORY_ID must not be blank');
  }

  return value;
}

function storyId(story) {
  if (story === null || typeof story !== 'object') {
    return undefined;
  }

  const id = story.id;
  return typeof id === 'string' && id.trim().length > 0 ? id : undefined;
}

export function listStories({ endpoint = 'stories-list' } = {}) {
  return checkArray(getJson(STORIES_PATH, { endpoint }), endpoint);
}

export function discoverStory() {
  const requestedStoryId = selectedStoryIdFromEnvironment();
  if (requestedStoryId !== undefined) {
    const story = checkObject(
      getJson(`${STORIES_PATH}/${encodeURIComponent(requestedStoryId)}`, {
        endpoint: 'story-fixture-confirm',
      }),
      'story-fixture-confirm',
    );
    const confirmedId = storyId(story);
    const ok = check(story, {
      'configured story is visible to authenticated user': () =>
        confirmedId === requestedStoryId,
    });

    if (!ok) {
      fail('MM_K6_STORY_ID is not visible to the authenticated user');
    }

    return requestedStoryId;
  }

  const stories = listStories({ endpoint: 'story-fixture-list' });
  const usableStories = stories
    .map(storyId)
    .filter((id) => id !== undefined)
    .sort();

  if (usableStories.length === 0) {
    fail('At least one accessible Story is required for this scenario');
  }

  return usableStories[0];
}
