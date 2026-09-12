/**
 * ScorePartner News Service — Cricket news aggregation
 * Uses NewsAPI.org for current cricket news with in-memory caching.
 */

const NodeCache = require('node-cache');
const https = require('https');

// Cache news for 15 minutes
const newsCache = new NodeCache({ stdTTL: 900, checkperiod: 120 });

/**
 * Fetch news from NewsAPI.org
 * @param {string} query - Search query
 * @param {number} limit - Max articles
 * @returns {Array} articles
 */
async function getNews(query = 'cricket', limit = 5) {
  const cacheKey = `news_${query.toLowerCase().replace(/\s+/g, '_')}_${limit}`;
  const cached = newsCache.get(cacheKey);
  if (cached) {
    return cached;
  }

  const apiKey = process.env.NEWS_API_KEY;

  // If no API key, return a helpful message instead of failing
  if (!apiKey) {
    console.warn('⚠️ NEWS_API_KEY not set — returning fallback news guidance');
    return [{
      title: 'Cricket News Unavailable',
      summary: 'News API is not configured. Set NEWS_API_KEY in .env to enable live cricket news.',
      source: 'ScorePartner',
      url: '',
      publishedAt: new Date().toISOString(),
      imageUrl: null,
    }];
  }

  try {
    const searchQuery = `${query} cricket`;
    const url = `https://newsapi.org/v2/everything?q=${encodeURIComponent(searchQuery)}&sortBy=publishedAt&pageSize=${limit}&language=en&apiKey=${apiKey}`;

    const articles = await httpGet(url);

    if (articles && articles.articles) {
      const result = articles.articles.map(article => ({
        title: article.title || '',
        summary: article.description || '',
        source: article.source?.name || 'Unknown',
        url: article.url || '',
        publishedAt: article.publishedAt || '',
        imageUrl: article.urlToImage || null,
      }));

      newsCache.set(cacheKey, result);
      return result;
    }

    return [];
  } catch (error) {
    console.error('❌ News fetch error:', error.message);
    return [{
      title: 'Unable to fetch cricket news',
      summary: 'There was a problem retrieving the latest cricket news. Please try again later.',
      source: 'ScorePartner',
      url: '',
      publishedAt: new Date().toISOString(),
      imageUrl: null,
    }];
  }
}

/**
 * Simple HTTPS GET helper
 */
function httpGet(url) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, { timeout: 10000 }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error('Failed to parse news response'));
        }
      });
    });
    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('News request timed out'));
    });
  });
}

module.exports = { getNews };
