const express = require('express');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
require('dotenv').config();

// Initialize Firebase
const { db, auth } = require('./config/firebase');

// Initialize Express
const app = express();
const server = http.createServer(app);

// Initialize Socket.io
const io = new Server(server, {
  cors: {
    origin: process.env.SOCKET_CORS_ORIGINS
      ? process.env.SOCKET_CORS_ORIGINS.split(',').map(s => s.trim())
      : ['http://localhost:5000', 'http://127.0.0.1:5000'],
    methods: ['GET', 'POST', 'PUT', 'DELETE']
  }
});

// Middleware
const helmet = require('helmet');
app.use(helmet());
app.use(cors());
// Limit request size to 1MB to prevent payload attacks
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// Make io and db accessible to routes
app.set('io', io);
app.set('db', db);

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/users', require('./routes/users'));
app.use('/api/matches', require('./routes/matches'));
app.use('/api/teams', require('./routes/teams'));
app.use('/api/tournaments', require('./routes/tournaments'));
app.use('/api/leaderboard', require('./routes/leaderboard'));
app.use('/api/notifications', require('./routes/notifications'));
app.use('/api/broadcast', require('./routes/broadcast'));
app.use('/api/agora', require('./routes/agora')); // Agora RTC token generation

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'ScorePartner API is running with Firebase' });
});

// Simple local proxy to bypass CORS for external APIs (like Google Places)
// Only allows whitelisted API domains to prevent SSRF attacks
const ALLOWED_PROXY_HOSTS = [
  'maps.googleapis.com',
  'maps.googleapis.com',
  'api.openweathermap.org',
  'rest.nba.all.api',
];

const url = require('url');
app.get('/api/proxy', (req, res) => {
  const targetUrl = req.query.url;
  if (!targetUrl) return res.status(400).json({ error: 'Missing url parameter' });

  let parsedUrl;
  try {
    parsedUrl = new URL(targetUrl);
  } catch (e) {
    return res.status(400).json({ error: 'Invalid URL' });
  }

  const hostname = parsedUrl.hostname;
  if (!hostname || !ALLOWED_PROXY_HOSTS.includes(hostname)) {
    return res.status(403).json({ error: 'URL host not allowed' });
  }

  if (parsedUrl.protocol !== 'https:') {
    return res.status(403).json({ error: 'Only HTTPS URLs are allowed' });
  }

  https.get(targetUrl, (apiRes) => {
    res.status(apiRes.statusCode);
    res.set('Access-Control-Allow-Origin', '*');
    apiRes.pipe(res);
  }).on('error', (e) => {
    res.status(502).json({ error: e.message });
  });
});

// Socket.io connection handling
io.on('connection', (socket) => {
  console.log('🔌 Client connected:', socket.id);

  // Join a match room for live updates
  socket.on('join-match', (matchId) => {
    socket.join(`match-${matchId}`);
    console.log(`📺 Client ${socket.id} joined match-${matchId}`);
  });

  // Leave a match room
  socket.on('leave-match', (matchId) => {
    socket.leave(`match-${matchId}`);
    console.log(`👋 Client ${socket.id} left match-${matchId}`);
  });

  // Handle ball scoring event from scorer app
  socket.on('score-ball', async (data) => {
    const { matchId, ballEvent } = data;
    console.log(`🏏 Ball scored in match-${matchId}:`, ballEvent);

    try {
      // Get current match data
      const matchRef = db.collection('matches').doc(matchId);
      const matchDoc = await matchRef.get();

      if (matchDoc.exists) {
        const matchData = matchDoc.data();

        // Broadcast to all clients watching this match
        io.to(`match-${matchId}`).emit('ball-event', {
          matchId,
          ballEvent,
          match: { id: matchId, ...matchData }
        });

        console.log(`✅ Ball event broadcasted to match-${matchId}`);
      }
    } catch (error) {
      console.error('Error processing ball event:', error);
      socket.emit('error', { message: 'Failed to process ball event' });
    }
  });

  // Handle innings change
  socket.on('change-innings', async (data) => {
    const { matchId, newInnings, target } = data;
    console.log(`🔄 Innings change for match-${matchId}: Innings ${newInnings}, Target ${target}`);

    try {
      const matchRef = db.collection('matches').doc(matchId);
      const matchDoc = await matchRef.get();

      if (matchDoc.exists) {
        const matchData = matchDoc.data();

        // Swap batting teams
        const newBattingTeam = matchData.currentBattingTeam === 'team1' ? 'team2' : 'team1';
        const newBowlingTeam = matchData.currentBattingTeam === 'team1' ? 'team1' : 'team2';

        await matchRef.update({
          currentInnings: newInnings,
          currentBattingTeam: newBattingTeam,
          bowlingTeam: newBowlingTeam,
          target: target,
          currentOver: 0,
          currentBall: 0,
          updatedAt: new Date()
        });

        const updatedDoc = await matchRef.get();
        const updatedMatch = { id: matchId, ...updatedDoc.data() };

        // Broadcast innings change
        io.to(`match-${matchId}`).emit('innings-change', updatedMatch);

        console.log(`✅ Innings change broadcasted for match-${matchId}`);
      }
    } catch (error) {
      console.error('Error processing innings change:', error);
      socket.emit('error', { message: 'Failed to process innings change' });
    }
  });

  // Handle match completion
  socket.on('complete-match', async (data) => {
    const { matchId, result } = data;
    console.log(`🏆 Match completed: ${matchId}`, result);

    try {
      const matchRef = db.collection('matches').doc(matchId);

      await matchRef.update({
        status: 'completed',
        result: result,
        updatedAt: new Date()
      });

      const updatedDoc = await matchRef.get();
      const updatedMatch = { id: matchId, ...updatedDoc.data() };

      // Broadcast match completion
      io.to(`match-${matchId}`).emit('match-completed', updatedMatch);

      console.log(`✅ Match completion broadcasted for match-${matchId}`);
    } catch (error) {
      console.error('Error completing match:', error);
      socket.emit('error', { message: 'Failed to complete match' });
    }
  });

  // Handle player updates (striker, non-striker, bowler changes)
  socket.on('update-players', async (data) => {
    const { matchId, strikerId, nonStrikerId, bowlerId } = data;
    console.log(`👥 Player update for match-${matchId}`);

    try {
      const matchRef = db.collection('matches').doc(matchId);

      const updates = { updatedAt: new Date() };
      if (strikerId) updates.currentStrikerId = strikerId;
      if (nonStrikerId) updates.currentNonStrikerId = nonStrikerId;
      if (bowlerId) updates.currentBowlerId = bowlerId;

      await matchRef.update(updates);

      const updatedDoc = await matchRef.get();
      const updatedMatch = { id: matchId, ...updatedDoc.data() };

      // Broadcast player update
      io.to(`match-${matchId}`).emit('match-update', updatedMatch);
    } catch (error) {
      console.error('Error updating players:', error);
    }
  });

  socket.on('disconnect', () => {
    console.log('🔌 Client disconnected:', socket.id);
  });
});

// Start server
const PORT = process.env.PORT || 5000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running on port ${PORT} (0.0.0.0)`);
  console.log(`📡 API available at http://localhost:${PORT}/api`);
  console.log(`🔥 Connected to Firebase Firestore`);
});
