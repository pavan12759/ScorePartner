/**
 * Determines the intent of a user's message using lightweight regex and keyword matching.
 * Returns one of the following intents:
 * - APP_DATA
 * - RAG_KNOWLEDGE
 * - CRICKET_BASIC
 * - NEWS
 * - LOCAL_GREETING
 * - COMPLEX_AI
 */

function classifyIntent(message) {
  if (!message || typeof message !== 'string') {
    return 'UNKNOWN';
  }

  const msg = message.toLowerCase().trim();

  // 1. Local Greeting
  const greetings = ['hi', 'hello', 'hey', 'what can you do', 'what can you do?', 'help', 'what is scorepartner'];
  if (greetings.includes(msg)) {
    return 'LOCAL_GREETING';
  }

  // 2. News
  if (msg.includes('news') || msg.includes('latest cricket') || msg.includes('icc news') || msg.includes('ipl news')) {
    return 'NEWS';
  }

  // 3. App Data (Direct Firebase Searches)
  // Specific user data
  if (/show (my )?(matches|games)/.test(msg) || /my matches/.test(msg)) return 'APP_DATA_USER_MATCHES';
  if (/show (my )?tournaments/.test(msg) || /my tournaments/.test(msg)) return 'APP_DATA_USER_TOURNAMENTS';
  if (/show (my )?teams/.test(msg) || /my teams/.test(msg)) return 'APP_DATA_USER_TEAMS';
  if (/(show live|live) matches/.test(msg)) return 'APP_DATA_LIVE_MATCHES';
  if (/(show upcoming|upcoming) matches/.test(msg)) return 'APP_DATA_UPCOMING_MATCHES';

  // Temporal match queries (today, recent, latest, yesterday, this week)
  if (/(?:today(?:'?s)?|recent|latest|yesterday(?:'?s)?|this week(?:'?s)?|ongoing|current)\s*(?:matches|games|results|scores)/.test(msg)) {
    return 'APP_DATA_RECENT_MATCHES';
  }
  // Reverse: "matches today", "games today"
  if (/(?:matches|games|results|scores)\s*(?:today|yesterday|this week|right now|going on)/.test(msg)) {
    return 'APP_DATA_RECENT_MATCHES';
  }

  // Generic entity requests WITHOUT a specific name (e.g. "find a player", "search for a team")
  // These should prompt the user rather than searching for "a player" literally
  if (/^(?:find|search|search for|look for|show me)\s+(?:a |an |some )?(?:player|players)$/i.test(msg)) {
    return 'APP_DATA_GENERIC_PLAYER';
  }
  if (/^(?:find|search|search for|look for|show me)\s+(?:a |an |some )?(?:team|teams)$/i.test(msg)) {
    return 'APP_DATA_GENERIC_TEAM';
  }
  if (/^(?:find|search|search for|look for|show me)\s+(?:a |an |some )?(?:tournament|tournaments|league|leagues)$/i.test(msg)) {
    return 'APP_DATA_GENERIC_TOURNAMENT';
  }
  if (/^(?:find|search|search for|look for|show me)\s+(?:a |an |some )?(?:match|matches|game|games)$/i.test(msg)) {
    return 'APP_DATA_RECENT_MATCHES';
  }

  // Search entities with a specific name
  if (/find player (.+)/.test(msg) || /search player (.+)/.test(msg)) return 'APP_DATA_SEARCH_PLAYER';
  if (/find team (.+)/.test(msg) || /search team (.+)/.test(msg)) return 'APP_DATA_SEARCH_TEAM';
  if (/find tournament (.+)/.test(msg) || /search tournament (.+)/.test(msg)) return 'APP_DATA_SEARCH_TOURNAMENT';
  
  // General find with an actual name (e.g. "Find Pavan", "Search for Virat")
  // Filter out generic articles/pronouns that aren't real search terms
  if (/(?:find|search(?: for)?)\s+(.+)/i.test(msg)) {
    const captured = RegExp.$1.trim();
    const genericWords = ['a', 'an', 'the', 'some', 'any', 'me', 'my', 'it', 'this', 'that'];
    if (!genericWords.includes(captured) && !msg.includes('analyze') && !msg.includes('compare') && !msg.includes('report') && !msg.includes('explain')) {
      return 'APP_DATA_SEARCH_GENERAL';
    }
  }

  // General show (e.g. "Show Team A", "Show Rahul's profile")
  if (/show (.+)/.test(msg)) {
    if (!msg.includes('analyze') && !msg.includes('compare') && !msg.includes('report') && !msg.includes('explain')) {
      return 'APP_DATA_SEARCH_GENERAL';
    }
  }

  // 4. ScorePartner RAG Knowledge
  const ragPatterns = [
    /how to (create|add|start|use)/,
    /how does (scoring|live scoring|live broadcast) work/,
    /how do i/
  ];

  for (const pattern of ragPatterns) {
    if (pattern.test(msg)) {
      return 'RAG_KNOWLEDGE';
    }
  }

  // 5. Cricket Basic Knowledge
  const cricketBasicPatterns = [
    /what is (lbw|drs|dls|nrr)/,
    /what is a (six|boundary|maiden|wicket|powerplay|super over|free hit|no-ball|wide)/,
    /how does a free hit work/
  ];

  for (const pattern of cricketBasicPatterns) {
    if (pattern.test(msg)) {
      if (!msg.includes('explain the difference') && !msg.includes('compare')) {
        return 'CRICKET_BASIC';
      }
    }
  }

  // 6. Complex AI
  return 'COMPLEX_AI';
}

module.exports = { classifyIntent };
