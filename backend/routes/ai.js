/**
 * ScorePartner AI Routes
 * POST /api/ai/chat  — Main AI chat endpoint
 * GET  /api/ai/news  — Cricket news endpoint
 */

const express = require('express');
const { auth, optionalAuth } = require('../middleware/auth');
const { getAIService } = require('../services/ai-service');
const { toolDefinitions, executeTool } = require('../services/ai-tools');
const newsService = require('../services/news-service');
const rateLimit = require('express-rate-limit');

const router = express.Router();

// Rate limiting for AI endpoints
const aiChatLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 30,
  message: { error: 'Too many AI requests. Please wait a moment and try again.' },
  standardHeaders: true,
  legacyHeaders: false,
});

const aiNewsLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  message: { error: 'Too many news requests. Please try again shortly.' },
});

// ==================== System Prompt ====================

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
5. **App Help**: Explain how to use ScorePartner features (create match, create team, create tournament, start scoring, go live, share match, etc.)

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

## ScorePartner App Guide
- **Create a Match**: Go to Profile > tap "+" or "Create Match" > fill in teams, overs, ground > start.
- **Create a Team**: Go to Profile > My Teams > Create Team > add players.
- **Create a Tournament**: Go to Profile > My Tournaments > Create Tournament > set format, teams, fixtures.
- **Start Scoring**: Open a match > tap "Start Scoring" > select batsmen and bowler > score ball by ball.
- **Go Live (Broadcast)**: Open a match > tap "Go Live" > start broadcasting with live overlay.
- **Share a Match**: Open match details > tap Share icon > share link.
- **Points Table**: Open a tournament > Points Table tab.
- **View Scorecard**: Open a match > Scorecard tab.

## Important
- Always use tools to search ScorePartner data. Do not make up data.
- Include entity markers in your response so the app can render interactive cards.
- Be brief when possible. Users are on mobile.`;

// ==================== POST /api/ai/chat ====================

router.post('/chat', auth, aiChatLimiter, async (req, res) => {
  try {
    const { message, conversationHistory } = req.body;

    if (!message || typeof message !== 'string') {
      return res.status(400).json({ error: 'Message is required' });
    }

    // Limit message length
    if (message.length > 2000) {
      return res.status(400).json({ error: 'Message too long (max 2000 characters)' });
    }

    const userId = req.user?.uid || null;
    const aiService = getAIService();

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

    // First AI call — may return tool calls
    let result = await aiService.chat(messages, toolDefinitions, SYSTEM_PROMPT);

    // If AI wants to call tools, execute them and continue
    let maxToolRounds = 3; // Prevent infinite loops
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
      result = await aiService.continueWithToolResults(
        messages, toolDefinitions, SYSTEM_PROMPT, toolResults, rawModelParts
      );
    }

    // Parse AI response for entity markers and actions
    const parsed = parseAIResponse(result.text || '');

    res.json({
      message: parsed.cleanText,
      entities: parsed.entities,
      actions: parsed.actions,
      raw: result.text,
    });

  } catch (error) {
    console.error('❌ AI chat error:', error.message);

    if (error.message.includes('not configured')) {
      return res.status(503).json({ error: 'AI service is not configured. Please contact support.' });
    }

    res.status(500).json({ error: 'Something went wrong with ScorePartner AI. Please try again.' });
  }
});

// ==================== GET /api/ai/news ====================

router.get('/news', optionalAuth, aiNewsLimiter, async (req, res) => {
  try {
    const query = req.query.q || 'cricket';
    const limit = Math.min(parseInt(req.query.limit) || 5, 10);

    const articles = await newsService.getNews(query, limit);

    res.json({ articles });
  } catch (error) {
    console.error('❌ News fetch error:', error.message);
    res.status(500).json({ error: 'Failed to fetch cricket news' });
  }
});

// ==================== Response Parser ====================

/**
 * Parse AI response text for entity markers like [MATCH:id:title]
 * and generate structured entities + actions.
 */
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

module.exports = router;
