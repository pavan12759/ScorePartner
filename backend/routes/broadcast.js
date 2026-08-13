const express = require('express');
const router = express.Router();
const { auth } = require('../middleware/auth');

// Helper to get Firestore db and Socket.io from express app
const getDb = (req) => req.app.get('db');
const getIo = (req) => req.app.get('io');

// POST /api/broadcast/start - Start a new broadcast session
router.post('/start', auth, async (req, res) => {
  try {
    const { matchId, overlayThemeId, title } = req.body;
    const broadcasterId = req.user.uid;
    const db = getDb(req);
    const io = getIo(req);

    if (!matchId) {
      return res.status(400).json({ error: 'matchId is required' });
    }

    // Check if match exists
    const matchDoc = await db.collection('matches').doc(matchId).get();
    if (!matchDoc.exists) {
      return res.status(404).json({ error: 'Match not found' });
    }

    // Generate 6-digit crew invite code
    const crewCode = Math.floor(100000 + Math.random() * 900000).toString();

    const broadcastRef = db.collection('broadcasts').doc();
    const broadcastData = {
      id: broadcastRef.id,
      matchId,
      broadcasterId,
      overlayThemeId: overlayThemeId || 'scorepartner_premium',
      title: title || `${matchDoc.data().team1Name || 'Team A'} vs ${matchDoc.data().team2Name || 'Team B'} - LIVE`,
      status: 'live',
      startedAt: new Date().toISOString(),
      endedAt: null,
      viewerCount: 1,
      peakViewers: 1,
      totalViews: 1,
      chatEnabled: true,
      slowModeSeconds: 0,
      crewCode,
      crew: {
        [broadcasterId]: 'owner',
      },
    };

    await broadcastRef.set(broadcastData);

    // Update match document
    await db.collection('matches').doc(matchId).update({
      isBroadcasting: true,
      activeBroadcastId: broadcastRef.id,
    });

    // Broadcast socket event
    if (io) {
      io.to(`match-${matchId}`).emit('broadcast-started', broadcastData);
    }

    res.status(201).json({ message: 'Broadcast session started', broadcast: broadcastData });
  } catch (error) {
    console.error('Error starting broadcast:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/broadcast/end - End active broadcast session
router.post('/end', auth, async (req, res) => {
  try {
    const { broadcastId } = req.body;
    const db = getDb(req);
    const io = getIo(req);

    if (!broadcastId) {
      return res.status(400).json({ error: 'broadcastId is required' });
    }

    const broadcastRef = db.collection('broadcasts').doc(broadcastId);
    const broadcastDoc = await broadcastRef.get();

    if (!broadcastDoc.exists) {
      return res.status(404).json({ error: 'Broadcast session not found' });
    }

    const broadcastData = broadcastDoc.data();

    await broadcastRef.update({
      status: 'ended',
      endedAt: new Date().toISOString(),
      viewerCount: 0,
    });

    // Update match document
    await db.collection('matches').doc(broadcastData.matchId).update({
      isBroadcasting: false,
      activeBroadcastId: null,
    });

    if (io) {
      io.to(`match-${broadcastData.matchId}`).emit('broadcast-ended', { broadcastId });
    }

    res.json({ message: 'Broadcast session ended successfully' });
  } catch (error) {
    console.error('Error ending broadcast:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/broadcast/match/:matchId - Get active broadcast session for match
router.get('/match/:matchId', async (req, res) => {
  try {
    const { matchId } = req.params;
    const db = getDb(req);

    const snapshot = await db
      .collection('broadcasts')
      .where('matchId', '==', matchId)
      .where('status', '==', 'live')
      .limit(1)
      .get();

    if (snapshot.empty) {
      return res.status(404).json({ message: 'No active broadcast for this match' });
    }

    const doc = snapshot.docs[0];
    res.json({ broadcast: { id: doc.id, ...doc.data() } });
  } catch (error) {
    console.error('Error getting match broadcast:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/broadcast/:id/crew - Join broadcast crew via code
router.post('/:id/crew', auth, async (req, res) => {
  try {
    const { id } = req.params;
    const { userId, crewCode, role } = req.body;
    const db = getDb(req);

    const broadcastRef = db.collection('broadcasts').doc(id);
    const doc = await broadcastRef.get();

    if (!doc.exists) {
      return res.status(404).json({ error: 'Broadcast not found' });
    }

    const data = doc.data();
    if (data.crewCode !== crewCode) {
      return res.status(400).json({ error: 'Invalid 6-digit crew invite code' });
    }

    const assignedRole = role || 'scoring_admin';
    await broadcastRef.update({
      [`crew.${userId}`]: assignedRole,
    });

    res.json({ message: 'Joined broadcast crew successfully', role: assignedRole });
  } catch (error) {
    console.error('Error joining crew:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/broadcast/:id/analytics - Get broadcast analytics metrics
router.get('/:id/analytics', auth, async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDb(req);

    const broadcastDoc = await db.collection('broadcasts').doc(id).get();
    if (!broadcastDoc.exists) {
      return res.status(404).json({ error: 'Broadcast not found' });
    }

    const data = broadcastDoc.data();

    // Fetch message count & highlight count
    const messagesSnap = await db.collection('broadcasts').doc(id).collection('messages').get();
    const highlightsSnap = await db.collection('broadcasts').doc(id).collection('highlights').get();
    const reactionsSnap = await db.collection('broadcasts').doc(id).collection('reactions').get();

    const analytics = {
      broadcastId: id,
      matchId: data.matchId,
      status: data.status,
      startedAt: data.startedAt,
      endedAt: data.endedAt,
      peakViewers: data.peakViewers || 0,
      totalViews: data.totalViews || 0,
      totalMessages: messagesSnap.size,
      totalHighlights: highlightsSnap.size,
      totalReactions: reactionsSnap.size,
    };

    res.json({ analytics });
  } catch (error) {
    console.error('Error getting analytics:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
