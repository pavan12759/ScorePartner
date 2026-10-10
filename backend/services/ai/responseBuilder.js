/**
 * Standardizes AI responses across different intents.
 */

function buildResponse(options = {}) {
  const {
    success = true,
    source = 'system',
    intent = 'UNKNOWN',
    message = '',
    entities = [],
    actions = [],
    raw = ''
  } = options;

  return {
    success,
    source,
    intent,
    message,
    entities,
    actions,
    raw: raw || message
  };
}

/**
 * Helper to build an error response.
 */
function buildErrorResponse(message, intent = 'UNKNOWN', source = 'system') {
  return buildResponse({
    success: false,
    source,
    intent,
    message,
    raw: message
  });
}

module.exports = { buildResponse, buildErrorResponse };
