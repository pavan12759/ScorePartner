const express = require('express');
const { db } = require('../config/firebase');
const { auth, optionalAuth } = require('../middleware/auth');

const router = express.Router();

function listIncludes(list, value) {
    return Array.isArray(list) && list.includes(value);
}

function canManageMatch(userId, matchData) {
    return matchData.createdBy === userId || listIncludes(matchData.adminIds, userId);
}

function canScoreMatch(userId, matchData) {
    return canManageMatch(userId, matchData) ||
        listIncludes(matchData.scorerIds, userId) ||
        listIncludes(matchData.scorers, userId);
}

// @route   GET /api/matches
// @desc    Get all matches (with filters)
// @access  Public
router.get('/', async (req, res) => {
    try {
        const { status, ballType, limit = 20 } = req.query;

        let query = db.collection('matches').orderBy('matchDate', 'desc');

        if (status) {
            query = db.collection('matches').where('status', '==', status).orderBy('matchDate', 'desc');
        }

        const snapshot = await query.limit(parseInt(limit)).get();

        let matches = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

        if (ballType) {
            matches = matches.filter(m => m.ballType === ballType);
        }

        res.json({ matches });
    } catch (error) {
        console.error('Get matches error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   GET /api/matches/live
// @desc    Get live matches
// @access  Public
router.get('/live', async (req, res) => {
    try {
        const snapshot = await db.collection('matches')
            .where('status', '==', 'live')
            .get();

        const matches = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        res.json({ matches });
    } catch (error) {
        console.error('Get live matches error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   GET /api/matches/upcoming
// @desc    Get upcoming matches
// @access  Public
router.get('/upcoming', async (req, res) => {
    try {
        const snapshot = await db.collection('matches')
            .where('status', '==', 'upcoming')
            .orderBy('matchDate', 'asc')
            .limit(20)
            .get();

        const matches = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        res.json({ matches });
    } catch (error) {
        console.error('Get upcoming matches error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   GET /api/matches/user/:userId
// @desc    Get matches for a user
// @access  Public
router.get('/user/:userId', async (req, res) => {
    try {
        const snapshot = await db.collection('matches')
            .where('createdBy', '==', req.params.userId)
            .orderBy('matchDate', 'desc')
            .get();

        const matches = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        res.json({ matches });
    } catch (error) {
        console.error('Get user matches error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   GET /api/matches/:id
// @desc    Get match by ID
// @access  Public
router.get('/:id', async (req, res) => {
    try {
        const matchDoc = await db.collection('matches').doc(req.params.id).get();

        if (!matchDoc.exists) {
            return res.status(404).json({ error: 'Match not found' });
        }

        res.json({ match: { id: matchDoc.id, ...matchDoc.data() } });
    } catch (error) {
        console.error('Get match error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   POST /api/matches
// @desc    Create a new match
// @access  Private
router.post('/', auth, async (req, res) => {
    try {
        const requestAdminIds = Array.isArray(req.body.adminIds) ? req.body.adminIds : [];
        const requestScorerIds = Array.isArray(req.body.scorerIds) ? req.body.scorerIds : [];
        const requestScorers = Array.isArray(req.body.scorers) ? req.body.scorers : [];
        const matchData = {
            ...req.body,
            createdBy: req.user.uid,
            adminIds: Array.from(new Set([...requestAdminIds, req.user.uid])),
            scorerIds: requestScorerIds,
            scorers: Array.from(new Set([...requestScorers, req.user.uid])),
            createdAt: new Date(),
            updatedAt: new Date()
        };

        const docRef = await db.collection('matches').add(matchData);

        console.log(`✅ Match created: ${matchData.team1Name} vs ${matchData.team2Name}`);

        res.status(201).json({
            message: 'Match created successfully',
            match: { id: docRef.id, ...matchData }
        });
    } catch (error) {
        console.error('Create match error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   PUT /api/matches/:id
// @desc    Update match
// @access  Private
router.put('/:id', auth, async (req, res) => {
    try {
        const matchRef = db.collection('matches').doc(req.params.id);
        const matchDoc = await matchRef.get();

        if (!matchDoc.exists) {
            return res.status(404).json({ error: 'Match not found' });
        }

        const matchData = matchDoc.data();
        if (!canScoreMatch(req.user.uid, matchData)) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        await matchRef.update({
            ...req.body,
            updatedAt: new Date()
        });

        const updatedDoc = await matchRef.get();
        const match = { id: updatedDoc.id, ...updatedDoc.data() };

        // Emit real-time update
        const io = req.app.get('io');
        io.to(`match-${req.params.id}`).emit('match-update', match);

        res.json({ message: 'Match updated', match });
    } catch (error) {
        console.error('Update match error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   POST /api/matches/:id/ball
// @desc    Add ball event (live scoring)
// @access  Private
router.post('/:id/ball', auth, async (req, res) => {
    try {
        const matchRef = db.collection('matches').doc(req.params.id);
        const matchDoc = await matchRef.get();

        if (!matchDoc.exists) {
            return res.status(404).json({ error: 'Match not found' });
        }

        const matchData = matchDoc.data();
        if (!canScoreMatch(req.user.uid, matchData)) {
            return res.status(403).json({ error: 'Not authorized' });
        }
        const ballEvent = {
            ...req.body,
            timestamp: new Date()
        };

        // Add ball event to array
        const ballEvents = matchData.ballEvents || [];
        ballEvents.push(ballEvent);

        // Update scores
        const updates = {
            ballEvents,
            currentOver: ballEvent.overNumber,
            currentBall: ballEvent.ballNumber,
            updatedAt: new Date()
        };

        await matchRef.update(updates);

        const updatedDoc = await matchRef.get();
        const match = { id: updatedDoc.id, ...updatedDoc.data() };

        // Emit real-time update
        const io = req.app.get('io');
        io.to(`match-${req.params.id}`).emit('ball-event', { match, ballEvent });

        console.log(`🏏 Ball event: ${matchData.team1Name} vs ${matchData.team2Name}`);

        res.json({ message: 'Ball event added', match, ballEvent });
    } catch (error) {
        console.error('Add ball event error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   PUT /api/matches/:id/complete
// @desc    Complete a match
// @access  Private
router.put('/:id/complete', auth, async (req, res) => {
    try {
        const { winnerId, winnerName, resultText, manOfTheMatch } = req.body;

        const matchRef = db.collection('matches').doc(req.params.id);
        const matchDoc = await matchRef.get();

        if (!matchDoc.exists) {
            return res.status(404).json({ error: 'Match not found' });
        }

        const matchData = matchDoc.data();
        if (!canScoreMatch(req.user.uid, matchData)) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        await matchRef.update({
            status: 'completed',
            result: { winnerId, winnerName, resultText, manOfTheMatch },
            updatedAt: new Date()
        });

        // Update player stats
        try {
            await updatePlayerStats({ ...matchData, id: req.params.id, result: { winnerId, winnerName, resultText, manOfTheMatch } });
        } catch (statsError) {
            console.error('Error updating player stats:', statsError);
            // Continue even if stats update fails, as the match is already marked completed
        }

        const updatedDoc = await matchRef.get();
        const match = { id: updatedDoc.id, ...updatedDoc.data() };

        // Emit real-time update
        const io = req.app.get('io');
        io.to(`match-${req.params.id}`).emit('match-completed', match);

        console.log(`🏆 Match completed: ${winnerName} won!`);

        res.json({ message: 'Match completed', match });
    } catch (error) {
        console.error('Complete match error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

/**
 * Helper to update player stats when match completes
 */
async function updatePlayerStats(match) {
    const ballType = match.matchType && match.matchType.toLowerCase().includes('tennis') ? 'tennis' : 'leather';
    const playersToUpdate = new Map();

    // Process Batters
    const allBatters = [
        ...(match.team1Score?.batters || []),
        ...(match.team2Score?.batters || [])
    ];
    allBatters.forEach(b => {
        if (!b.playerId || !b.playerName || b.playerId.startsWith('p_')) return;

        if (!playersToUpdate.has(b.playerId)) {
            playersToUpdate.set(b.playerId, {
                batting: { runs: 0, balls: 0 },
                bowling: { wickets: 0, runs: 0, balls: 0 },
                isMOM: match.result?.manOfTheMatch === b.playerName
            });
        }
        const stats = playersToUpdate.get(b.playerId);
        stats.batting.runs += b.runs || 0;
        stats.batting.balls += b.balls || 0;
    });

    // Process Bowlers
    const allBowlers = [
        ...(match.team1Score?.bowlers || []),
        ...(match.team2Score?.bowlers || [])
    ];
    allBowlers.forEach(b => {
        if (!b.playerId || !b.playerName || b.playerId.startsWith('p_')) return;

        if (!playersToUpdate.has(b.playerId)) {
            playersToUpdate.set(b.playerId, {
                batting: { runs: 0, balls: 0 },
                bowling: { wickets: 0, runs: 0, balls: 0 },
                isMOM: match.result?.manOfTheMatch === b.playerName
            });
        }
        const stats = playersToUpdate.get(b.playerId);
        stats.bowling.wickets += b.wickets || 0;
        stats.bowling.runs += b.runs || 0;
        stats.bowling.balls += b.balls || 0;
    });

    const updateField = ballType === 'tennis' ? 'tennisBallStats' : 'leatherBallStats';

    for (const [playerId, matchStats] of playersToUpdate.entries()) {
        try {
            const userRef = db.collection('users').doc(playerId);
            const userDoc = await userRef.get();
            if (!userDoc.exists) continue;

            const userData = userDoc.data();
            const currentStats = userData[updateField] || {
                matches: 0, runs: 0, wickets: 0, strikeRate: 0, economy: 0,
                bestScore: 0, bestBowling: '0/0', manOfMatches: 0, tournamentWins: 0
            };

            const newStats = {
                ...currentStats,
                matches: (currentStats.matches || 0) + 1,
                runs: (currentStats.runs || 0) + matchStats.batting.runs,
                wickets: (currentStats.wickets || 0) + matchStats.bowling.wickets,
                manOfMatches: (currentStats.manOfMatches || 0) + (matchStats.isMOM ? 1 : 0),
                bestScore: Math.max(currentStats.bestScore || 0, matchStats.batting.runs),
            };

            // Handle best bowling (parse "W/R")
            const [bestW, bestR] = (currentStats.bestBowling || '0/0').split('/').map(num => parseInt(num) || 0);
            if (matchStats.bowling.wickets > bestW || (matchStats.bowling.wickets === bestW && matchStats.bowling.runs < bestR)) {
                newStats.bestBowling = `${matchStats.bowling.wickets}/${matchStats.bowling.runs}`;
            }

            // Recalculate Strike Rate and Economy for profile
            const totalBallsBatted = (currentStats.totalBallsBatted || 0) + matchStats.batting.balls;
            newStats.totalBallsBatted = totalBallsBatted;
            newStats.strikeRate = totalBallsBatted > 0 ? (newStats.runs / totalBallsBatted) * 100 : 0;

            const totalBallsBowled = (currentStats.totalBallsBowled || 0) + matchStats.bowling.balls;
            newStats.totalBallsBowled = totalBallsBowled;
            const totalOversBowled = totalBallsBowled / 6;
            newStats.totalRunsConceded = (currentStats.totalRunsConceded || 0) + matchStats.bowling.runs;
            newStats.economy = totalOversBowled > 0 ? newStats.totalRunsConceded / totalOversBowled : 0;

            await userRef.update({ [updateField]: newStats });
        } catch (err) {
            console.error(`Error updating user ${playerId} stats:`, err);
        }
    }
}

// @route   DELETE /api/matches/:id
// @desc    Delete match
// @access  Private
router.delete('/:id', auth, async (req, res) => {
    try {
        const matchDoc = await db.collection('matches').doc(req.params.id).get();

        if (!matchDoc.exists) {
            return res.status(404).json({ error: 'Match not found' });
        }

        if (!canManageMatch(req.user.uid, matchDoc.data())) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        await db.collection('matches').doc(req.params.id).delete();

        res.json({ message: 'Match deleted' });
    } catch (error) {
        console.error('Delete match error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;
