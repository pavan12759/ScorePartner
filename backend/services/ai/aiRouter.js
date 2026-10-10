/**
 * Smart AI Router for ScorePartner.
 * Intercepts AI requests, classifies intent, and routes to local, DB, RAG, or Gemini endpoints.
 */

const { classifyIntent } = require('./intentClassifier');
const { retrieveAnswer } = require('./ragService');
const { getNews } = require('./newsService');
const { buildResponse, buildErrorResponse } = require('./responseBuilder');
const { executeTool, toolDefinitions } = require('./aiTools');
const { getGeminiService } = require('./geminiService');

const SYSTEM_PROMPT = `You are ScorePartner AI — the intelligent cricket assistant built into the ScorePartner app.

## Your Identity
- You are part of ScorePartner, a cricket scoring, team management, and tournament platform.
- Be friendly, helpful, concise, and cricket-knowledgeable.
- Do NOT pretend to be a generic AI assistant. You ARE ScorePartner AI.

## Your Capabilities
1. **ScorePartner Data**: Search real matches, players, teams, and tournaments in the ScorePartner database using the provided tools.
2. **Cricket Knowledge**: Answer questions about cricket rules, formats (T20, ODI, Test), DLS, DRS, powerplay, free hits, Net Run Rate, Super Over, etc.
3. **ICC & International Cricket**: Answer questions about ICC, World Cup, Champions Trophy, World Test Championship, rankings (use your training knowledge for historical info).
4. **Cricket News**: Fetch current cricket news headlines using the getCricketNews tool.
5. **App Help**: Explain how to use ScorePartner features.

## Response Rules
1. When you find ScorePartner data (matches, players, teams, tournaments), ALWAYS include entity references in your response using this exact format:
   - For matches: [MATCH:id:Team1 vs Team2]
   - For players: [PLAYER:id:PlayerName]
   - For teams: [TEAM:id:TeamName]
   - For tournaments: [TOURNAMENT:id:TournamentName]
   - For news: [NEWS:url:headline]

2. NEVER fabricate ScorePartner data. If a search returns no results, say "I couldn't find that in ScorePartner."
3. NEVER invent match IDs, player IDs, team IDs, or tournament IDs.
4. For ambiguous searches with multiple results, show all results and ask the user to choose.
5. Keep answers concise. For simple questions, give short answers.
6. For cricket rules questions, explain clearly without needing database tools.
7. When the user says "my matches/teams/tournaments", use the getUserMatches/getUserTeams/getUserTournaments tools.

## Important
- Always use tools to search ScorePartner data. Do not make up data.
- Include entity markers in your response so the app can render interactive cards.
- Be brief when possible. Users are on mobile.`;


async function routeRequest(message, conversationHistory, userId) {
  try {
    const intent = classifyIntent(message);
    console.log(`[AI ROUTER] Intent: ${intent}, Gemini call: ${intent === 'COMPLEX_AI' ? 'YES' : 'NO'}`);

    // ==========================================
    // 1. LOCAL GREETING
    // ==========================================
    if (intent === 'LOCAL_GREETING') {
      return buildResponse({
        source: 'local',
        intent,
        message: "Hi! 👋 I'm ScorePartner AI. I can help you find matches, players, teams, and tournaments, explain cricket, and keep you updated with cricket news."
      });
    }

    // ==========================================
    // 2. RAG OR CRICKET BASIC
    // ==========================================
    if (intent === 'RAG_KNOWLEDGE' || intent === 'CRICKET_BASIC') {
      const ragAnswer = retrieveAnswer(message);
      if (ragAnswer) {
        return buildResponse({
          source: 'rag',
          intent,
          message: ragAnswer
        });
      }
      // If RAG didn't find a direct match, let it fall through to COMPLEX_AI
    }

    // ==========================================
    // 3. NEWS
    // ==========================================
    if (intent === 'NEWS') {
      const articles = await getNews('cricket', 5);
      if (articles && articles.length > 0) {
        let text = "Here is the latest cricket news:\n\n";
        const entities = [];
        const actions = [];

        articles.forEach(a => {
          text += `• ${a.title}\n`;
          entities.push({ type: 'news', id: a.url, title: a.title });
          actions.push({ type: 'open_news', entityId: a.url, label: 'Read Full News →' });
        });

        return buildResponse({
          source: 'news',
          intent,
          message: text.trim(),
          entities,
          actions,
          raw: text.trim()
        });
      }
    }

    // ==========================================
    // 4. GENERIC ENTITY PROMPTS (no specific name given)
    // ==========================================
    if (intent === 'APP_DATA_GENERIC_PLAYER') {
      return buildResponse({
        source: 'local',
        intent,
        message: "Sure! Tell me the player's name and I'll search for them. For example: \"Find Virat\" or \"Search player Rohit\"."
      });
    }
    if (intent === 'APP_DATA_GENERIC_TEAM') {
      return buildResponse({
        source: 'local',
        intent,
        message: "Sure! Tell me the team name and I'll look it up. For example: \"Find team Mumbai Warriors\" or \"Search team Thunder\"."
      });
    }
    if (intent === 'APP_DATA_GENERIC_TOURNAMENT') {
      return buildResponse({
        source: 'local',
        intent,
        message: "Sure! Tell me the tournament name and I'll find it. For example: \"Find tournament Premier League\" or \"Search league Cricket Cup\"."
      });
    }

    // ==========================================
    // 5. APP DATA (Firebase Direct)
    // ==========================================
    if (intent.startsWith('APP_DATA')) {
      let toolResult = null;
      let resultText = '';
      
      const queryMatch = message.match(/(?:find|search(?: for)?|show) (?:player|team|tournament )?(.+)/i);
      const queryParam = queryMatch ? queryMatch[1].trim() : '';

      switch (intent) {
        case 'APP_DATA_USER_MATCHES':
          toolResult = await executeTool('getUserMatches', { limit: 5 }, userId);
          resultText = "Here are your matches:";
          break;
        case 'APP_DATA_USER_TOURNAMENTS':
          toolResult = await executeTool('getUserTournaments', { limit: 5 }, userId);
          resultText = "Here are your tournaments:";
          break;
        case 'APP_DATA_USER_TEAMS':
          toolResult = await executeTool('getUserTeams', { limit: 5 }, userId);
          resultText = "Here are your teams:";
          break;
        case 'APP_DATA_LIVE_MATCHES':
          toolResult = await executeTool('searchMatches', { query: '', status: 'live', limit: 5 }, userId);
          resultText = "Here are the live matches:";
          break;
        case 'APP_DATA_UPCOMING_MATCHES':
          toolResult = await executeTool('searchMatches', { query: '', status: 'upcoming', limit: 5 }, userId);
          resultText = "Here are the upcoming matches:";
          break;
        case 'APP_DATA_RECENT_MATCHES':
          toolResult = await executeTool('searchMatches', { query: '', status: 'all', limit: 10 }, userId);
          resultText = "Here are the recent matches:";
          break;
        case 'APP_DATA_SEARCH_PLAYER':
          toolResult = await executeTool('searchPlayers', { query: queryParam, limit: 5 }, userId);
          resultText = `Here is what I found for player "${queryParam}":`;
          break;
        case 'APP_DATA_SEARCH_TEAM':
          toolResult = await executeTool('searchTeams', { query: queryParam, limit: 5 }, userId);
          resultText = `Here is what I found for team "${queryParam}":`;
          break;
        case 'APP_DATA_SEARCH_TOURNAMENT':
          toolResult = await executeTool('searchTournaments', { query: queryParam, limit: 5 }, userId);
          resultText = `Here is what I found for tournament "${queryParam}":`;
          break;
        case 'APP_DATA_SEARCH_GENERAL':
        default:
          // Try players first, then teams, etc.
          const players = await executeTool('searchPlayers', { query: queryParam, limit: 3 }, userId);
          const teams = await executeTool('searchTeams', { query: queryParam, limit: 3 }, userId);
          
          if (players.found > 0) {
            toolResult = players;
            resultText = `Here are the players I found for "${queryParam}":`;
          } else if (teams.found > 0) {
            toolResult = teams;
            resultText = `Here are the teams I found for "${queryParam}":`;
          } else {
            const matches = await executeTool('searchMatches', { query: queryParam, limit: 3 }, userId);
            toolResult = matches;
            resultText = `Here are the matches I found for "${queryParam}":`;
          }
          break;
      }

      if (toolResult && toolResult.error) {
        return buildErrorResponse(toolResult.error, intent, 'firestore');
      }

      // Convert tool result into entities and actions
      const entities = [];
      const actions = [];
      let finalMessage = '';

      if (toolResult && toolResult.found > 0) {
        finalMessage = resultText + '\n\n';
        
        if (toolResult.matches) {
          toolResult.matches.forEach(m => {
            entities.push({ type: 'match', id: m.id, title: m.matchName });
            actions.push({ type: 'open_match', entityId: m.id, label: 'Go to Match →' });
          });
        }
        if (toolResult.players) {
          toolResult.players.forEach(p => {
            entities.push({ type: 'player', id: p.id, title: p.name });
            actions.push({ type: 'open_player', entityId: p.id, label: 'View Player →' });
          });
        }
        if (toolResult.teams) {
          toolResult.teams.forEach(t => {
            entities.push({ type: 'team', id: t.id, title: t.name });
            actions.push({ type: 'open_team', entityId: t.id, label: 'Open Team →' });
          });
        }
        if (toolResult.tournaments) {
          toolResult.tournaments.forEach(t => {
            entities.push({ type: 'tournament', id: t.id, title: t.name });
            actions.push({ type: 'open_tournament', entityId: t.id, label: 'Go to Tournament →' });
          });
        }

        return buildResponse({
          source: 'firestore',
          intent,
          message: finalMessage,
          entities,
          actions,
          raw: finalMessage
        });
      } else {
        // Provide a more helpful "not found" message based on intent
        let notFoundMsg = "I couldn't find that in ScorePartner.";
        if (intent === 'APP_DATA_RECENT_MATCHES') {
          notFoundMsg = "There are no recent matches in ScorePartner right now. You can create one from your profile!";
        } else if (intent === 'APP_DATA_LIVE_MATCHES') {
          notFoundMsg = "There are no live matches right now. Check back later or start scoring a match to go live!";
        } else if (intent === 'APP_DATA_UPCOMING_MATCHES') {
          notFoundMsg = "There are no upcoming matches scheduled. You can create one from your profile!";
        }
        return buildResponse({
          source: 'firestore',
          intent,
          message: notFoundMsg
        });
      }
    }

    // ==========================================
    // 5. COMPLEX AI (Gemini Fallback)
    // ==========================================
    console.log(`[AI ROUTER] Routing to Gemini for intent: ${intent}`);
    const geminiService = getGeminiService();
    
    // Build conversation messages
    const messages = [];

    // Include recent conversation history (max 20 messages for context)
    if (Array.isArray(conversationHistory)) {
      const recentHistory = conversationHistory.slice(-20);
      for (const msg of recentHistory) {
        if (msg.role && msg.content && typeof msg.content === 'string') {
          messages.push({
            role: msg.role === 'user' ? 'user' : 'assistant',
            content: msg.content.substring(0, 3000), // Limit context size
          });
        }
      }
    }

    // Add current message
    messages.push({ role: 'user', content: message });

    let result = await geminiService.chat(messages, toolDefinitions, SYSTEM_PROMPT, userId);

    // If AI wants to call tools, execute them and continue
    let maxToolRounds = 3;
    while (result.toolCalls && result.toolCalls.length > 0 && maxToolRounds > 0) {
      maxToolRounds--;

      const toolResults = [];
      for (const toolCall of result.toolCalls) {
        console.log(`🔧 AI tool call: ${toolCall.name}(${JSON.stringify(toolCall.arguments)})`);

        try {
          const toolResult = await executeTool(toolCall.name, toolCall.arguments, userId);
          toolResults.push({
            name: toolCall.name,
            args: toolCall.arguments,
            result: toolResult,
          });
          console.log(`✅ Tool ${toolCall.name} returned ${JSON.stringify(toolResult).length} bytes`);
        } catch (toolError) {
          console.error(`❌ Tool ${toolCall.name} error:`, toolError.message);
          toolResults.push({
            name: toolCall.name,
            args: toolCall.arguments,
            result: { error: 'Failed to execute search. Please try again.' },
          });
        }
      }

      // Continue conversation with tool results, passing raw model parts for thought_signature
      const rawModelParts = result._rawModelParts;
      result = await geminiService.continueWithToolResults(
        messages, toolDefinitions, SYSTEM_PROMPT, toolResults, rawModelParts, userId
      );
    }

    // Parse AI response for entity markers and actions
    const parsed = parseAIResponse(result.text || '');

    return buildResponse({
      source: 'gemini',
      intent: 'COMPLEX_AI',
      message: parsed.cleanText,
      entities: parsed.entities,
      actions: parsed.actions,
      raw: result.text
    });

  } catch (error) {
    console.error('❌ AI router error:', error.message);
    throw error;
  }
}

// ==================== Response Parser ====================

function parseAIResponse(text) {
  const entities = [];
  const actions = [];
  let cleanText = text;

  // Pattern: [TYPE:id:title]
  const entityPattern = /\[(MATCH|PLAYER|TEAM|TOURNAMENT|NEWS):([^:]+):([^\]]+)\]/g;
  let match;

  while ((match = entityPattern.exec(text)) !== null) {
    const [fullMatch, type, id, title] = match;
    const lowerType = type.toLowerCase();

    entities.push({
      type: lowerType,
      id: id.trim(),
      title: title.trim(),
    });

    // Generate navigation action
    if (lowerType !== 'news') {
      actions.push({
        type: `open_${lowerType}`,
        entityId: id.trim(),
        label: getActionLabel(lowerType, title.trim()),
      });
    } else {
      actions.push({
        type: 'open_news',
        entityId: id.trim(), // URL for news
        label: 'Read Full News →',
      });
    }

    // Clean the marker from display text, keep the title
    cleanText = cleanText.replace(fullMatch, title.trim());
  }

  return { cleanText: cleanText.trim(), entities, actions };
}

function getActionLabel(type, title) {
  switch (type) {
    case 'match': return `Go to Match →`;
    case 'player': return `View Player →`;
    case 'team': return `Open Team →`;
    case 'tournament': return `Go to Tournament →`;
    default: return `Open →`;
  }
}

module.exports = { routeRequest };
