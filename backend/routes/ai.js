/**
 * ScorePartner AI Routes
 * POST /api/ai/chat  — Main AI chat endpoint
 * GET  /api/ai/news  — Cricket news endpoint
 */

const express = require('express');
const { auth, optionalAuth } = require('../middleware/auth');
const { routeRequest } = require('../services/ai/aiRouter');
const { getNews } = require('../services/ai/newsService');
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

    // Route the request through the Smart AI Router
    const response = await routeRequest(message, conversationHistory, userId);

    res.json(response);

  } catch (error) {
    console.error('❌ AI chat error:', error.message);

    if (error.message.includes('not configured')) {
      return res.status(503).json({ error: 'AI service is not configured. Please contact support.' });
    }
    if (error.message.includes('limit reached')) {
      return res.status(429).json({ error: error.message });
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

module.exports = router;
