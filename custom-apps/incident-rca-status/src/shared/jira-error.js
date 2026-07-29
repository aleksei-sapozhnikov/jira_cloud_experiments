/**
 * Converts an unsuccessful Jira REST response into a concise Error that is
 * suitable for Forge logs and for the expanded panel. Jira can return either
 * structured JSON or plain text, so both formats are handled here.
 */

const MAX_ERROR_DETAIL_LENGTH = 300;

const normalizeMessage = (message) =>
  String(message).replace(/\s+/g, ' ').trim();

const stringifyMessage = (message) =>
  typeof message === 'string'
    ? message
    : JSON.stringify(message);

const extractJsonMessages = (responseBody) => {
  try {
    const payload = JSON.parse(responseBody);
    const messages = [
      ...(Array.isArray(payload.errorMessages)
        ? payload.errorMessages
        : []),
      ...Object.values(payload.errors ?? {}),
      ...(payload.message ? [payload.message] : []),
    ];

    return messages
      .map(stringifyMessage)
      .filter((message) => message !== undefined)
      .map(normalizeMessage)
      .filter(Boolean)
      .join(' ');
  } catch {
    return '';
  }
};

const limitMessageLength = (message) =>
  message.length > MAX_ERROR_DETAIL_LENGTH
    ? `${message.slice(0, MAX_ERROR_DETAIL_LENGTH - 1)}…`
    : message;

export const createJiraRequestError = async (issueKey, response) => {
  let responseBody = '';

  try {
    responseBody = await response.text();
  } catch {
    // The HTTP status is still useful if Jira's response body cannot be read.
  }

  const responseDetail =
    extractJsonMessages(responseBody) ||
    normalizeMessage(responseBody);
  const statusText = response.statusText
    ? ` (${response.statusText})`
    : '';
  const detail = responseDetail
    ? `: ${limitMessageLength(responseDetail)}`
    : '';

  return new Error(
    `${issueKey}: Jira returned HTTP ${response.status}${statusText}${detail}`
  );
};
