/**
 * ScorePartner AI Service — Provider-agnostic AI abstraction
 * Supports Gemini (default) and OpenAI as backends.
 * All AI calls go through this service so provider can be swapped easily.
 */

const { GoogleGenAI } = require('@google/genai');

// Track usage in memory (in production this would be in Redis/Firebase)
const userUsage = new Map();

function checkUsageLimit(userId) {
  if (!userId) return true; // Anonymous users (if any) might have a different rule, but let's allow them or block them.
  
  const limit = parseInt(process.env.AI_FREE_DAILY_LIMIT) || 50;
  const today = new Date().toISOString().split('T')[0];
  const userKey = `${userId}_${today}`;
  
  const usage = userUsage.get(userKey) || 0;
  if (usage >= limit) {
    throw new Error(`AI usage limit reached for today. Limit is ${limit} advanced requests.`);
  }
  
  userUsage.set(userKey, usage + 1);
  return true;
}

// ==================== Gemini AI Service ====================

class GeminiAIService {
  constructor() {
    this.apiKey = process.env.GEMINI_API_KEY || '';
    if (!this.apiKey || this.apiKey === 'your_gemini_api_key_here') {
      console.warn('⚠️ GEMINI_API_KEY not set — AI features will not work');
    }
    this.client = new GoogleGenAI({ apiKey: this.apiKey });
    this.model = process.env.GEMINI_MODEL || 'gemini-3.6-flash';
  }

  get hasApiKey() {
    return Boolean(this.apiKey && this.apiKey !== 'your_gemini_api_key_here');
  }

  async chat(messages, tools, systemPrompt, userId = null) {
    const key = process.env.GEMINI_API_KEY;
    if (!key || key === 'your_gemini_api_key_here') {
      throw new Error('AI service not configured. Set GEMINI_API_KEY in .env');
    }
    if (this.apiKey !== key) {
      this.apiKey = key;
      this.client = new GoogleGenAI({ apiKey: key });
    }

    // Check usage limits
    checkUsageLimit(userId);

    const startTime = Date.now();
    try {
      // Build contents array for Gemini
      const contents = messages.map(msg => ({
        role: msg.role === 'assistant' ? 'model' : 'user',
        parts: [{ text: msg.content }],
      }));

      // Build tool declarations for Gemini function calling
      const functionDeclarations = tools.map(tool => ({
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters,
      }));

      const config = {
        systemInstruction: systemPrompt,
      };

      if (functionDeclarations.length > 0) {
        config.tools = [{ functionDeclarations }];
      }

      const response = await this.client.models.generateContent({
        model: this.model,
        contents,
        config,
      });

      // Log success
      console.log(`[GEMINI SERVICE] User: ${userId || 'anon'}, Request: COMPLEX_AI, Time: ${Date.now() - startTime}ms, Status: SUCCESS`);

      // Check for function calls
      const candidate = response.candidates?.[0];
      const parts = candidate?.content?.parts || [];

      const toolCalls = [];
      let text = '';

      for (const part of parts) {
        if (part.functionCall) {
          toolCalls.push({
            name: part.functionCall.name,
            arguments: part.functionCall.args || {},
          });
        }
        if (part.text) {
          text += part.text;
        }
      }

      // Return raw parts so they can be replayed in continuation (preserves thought_signature)
      return { text, toolCalls, _rawModelParts: parts };
    } catch (error) {
      console.error(`[GEMINI SERVICE] User: ${userId || 'anon'}, Request: COMPLEX_AI, Time: ${Date.now() - startTime}ms, Status: FAILED`);
      console.error('❌ Gemini AI error:', error.message);
      throw new Error('AI service temporarily unavailable or usage limit reached');
    }
  }

  /**
   * Continue a conversation after tool results are provided.
   * Uses the raw model parts from the original response to preserve thought_signature.
   */
  async continueWithToolResults(messages, tools, systemPrompt, toolCallResults, rawModelParts, userId = null) {
    if (!process.env.GEMINI_API_KEY) {
      throw new Error('AI service not configured');
    }

    const startTime = Date.now();
    try {
      const contents = messages.map(msg => ({
        role: msg.role === 'assistant' ? 'model' : 'user',
        parts: [{ text: msg.content }],
      }));

      // Use the original raw model parts (with thought_signature) instead of reconstructing them
      if (rawModelParts && rawModelParts.length > 0) {
        contents.push({ role: 'model', parts: rawModelParts });
      } else {
        // Fallback: manually build function call parts (may fail with newer models)
        const functionCallParts = toolCallResults.map(r => ({
          functionCall: { name: r.name, args: r.args || {} },
        }));
        contents.push({ role: 'model', parts: functionCallParts });
      }

      // Add function responses as a user turn
      const functionResponseParts = toolCallResults.map(r => ({
        functionResponse: {
          name: r.name,
          response: { result: r.result },
        },
      }));
      contents.push({ role: 'user', parts: functionResponseParts });

      const functionDeclarations = tools.map(tool => ({
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters,
      }));

      const config = {
        systemInstruction: systemPrompt,
      };

      if (functionDeclarations.length > 0) {
        config.tools = [{ functionDeclarations }];
      }

      const response = await this.client.models.generateContent({
        model: this.model,
        contents,
        config,
      });

      console.log(`[GEMINI SERVICE] User: ${userId || 'anon'}, Request: COMPLEX_AI (Continue), Time: ${Date.now() - startTime}ms, Status: SUCCESS`);

      const candidate = response.candidates?.[0];
      const parts = candidate?.content?.parts || [];

      let text = '';
      const newToolCalls = [];
      for (const part of parts) {
        if (part.text) text += part.text;
        if (part.functionCall) {
          newToolCalls.push({
            name: part.functionCall.name,
            arguments: part.functionCall.args || {},
          });
        }
      }

      // Return raw parts for potential further continuations
      return { text, toolCalls: newToolCalls, _rawModelParts: parts };
    } catch (error) {
      console.error(`[GEMINI SERVICE] User: ${userId || 'anon'}, Request: COMPLEX_AI (Continue), Time: ${Date.now() - startTime}ms, Status: FAILED`);
      console.error('❌ Gemini continuation error:', error.message);
      throw new Error('AI service temporarily unavailable');
    }
  }
}

// Singleton
let _instance = null;
function getGeminiService() {
  try {
    require('dotenv').config();
  } catch (_) {}
  if (!_instance) {
    _instance = new GeminiAIService();
  }
  return _instance;
}

module.exports = { GeminiAIService, getGeminiService };

