/**
 * ScorePartner AI Service — Provider-agnostic AI abstraction
 * Supports Gemini (default) and OpenAI as backends.
 * All AI calls go through this service so provider can be swapped easily.
 */

const { GoogleGenAI } = require('@google/genai');

// ==================== Base AI Service ====================

class AIService {
  /**
   * Send a chat message with tool definitions and get a response.
   * @param {Array} messages - Conversation history [{role, content}]
   * @param {Array} tools - Tool definitions for function calling
   * @param {string} systemPrompt - System instructions
   * @returns {Object} { text, toolCalls[] }
   */
  async chat(messages, tools, systemPrompt) {
    throw new Error('chat() must be implemented by subclass');
  }
}

// ==================== Gemini AI Service ====================

class GeminiAIService extends AIService {
  constructor() {
    super();
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

  async chat(messages, tools, systemPrompt) {
    const key = process.env.GEMINI_API_KEY;
    if (!key || key === 'your_gemini_api_key_here') {
      throw new Error('AI service not configured. Set GEMINI_API_KEY in .env');
    }
    if (this.apiKey !== key) {
      this.apiKey = key;
      this.client = new GoogleGenAI({ apiKey: key });
    }

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
      console.error('❌ Gemini AI error:', error.message);
      throw new Error('AI service temporarily unavailable');
    }
  }

  /**
   * Continue a conversation after tool results are provided.
   * Uses the raw model parts from the original response to preserve thought_signature.
   */
  async continueWithToolResults(messages, tools, systemPrompt, toolCallResults, rawModelParts) {
    if (!process.env.GEMINI_API_KEY) {
      throw new Error('AI service not configured');
    }

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
      console.error('❌ Gemini continuation error:', error.message);
      throw new Error('AI service temporarily unavailable');
    }
  }
}

// ==================== Factory ====================

function createAIService() {
  const provider = (process.env.AI_PROVIDER || 'gemini').toLowerCase();

  switch (provider) {
    case 'gemini':
      return new GeminiAIService();
    default:
      console.warn(`⚠️ Unknown AI provider "${provider}", defaulting to Gemini`);
      return new GeminiAIService();
  }
}

// Singleton
let _instance = null;
function getAIService() {
  try {
    require('dotenv').config();
  } catch (_) {}
  if (!_instance) {
    _instance = createAIService();
  }
  return _instance;
}

module.exports = { AIService, GeminiAIService, getAIService };
