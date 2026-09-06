import { fail } from 'k6';
import { Rate } from 'k6/metrics';

import { requireAccessToken } from './auth.js';
import { baseUrl } from './config.js';

export const scenarioSuccess = new Rate('scenario_success');

export function validateScenarioPrerequisites() {
  requireAccessToken();
  baseUrl();
}

export function runScenario(name, body) {
  try {
    body();
    scenarioSuccess.add(1);
  } catch (error) {
    scenarioSuccess.add(0);
    fail(`${name} did not complete: ${safeErrorMessage(error)}`);
  }
}

function safeErrorMessage(error) {
  if (error === null || error === undefined) {
    return 'unknown error';
  }

  if (typeof error === 'string') {
    return error;
  }

  if (typeof error.message === 'string' && error.message.length > 0) {
    return error.message;
  }

  return String(error);
}
