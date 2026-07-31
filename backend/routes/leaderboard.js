const express = require('express');
const router = express.Router();
const { db } = require('../config/firebase');

// Get leaderboard
router.get('/', async (req, res) => {
    try {
        const { limit = 10 } = req.query;

        // This is a placeholder implementation
        // In a real app, you would query users sorted by points/stats
        const snapshot = await db.collection('users')
            .orderBy('totalRuns', 'desc')
            .limit(parseInt(limit))
            .get();

        const leaderboard = [];
        snapshot.forEach(doc => {
            leaderboard.push({ id: doc.id, ...doc.data() });
        });

        res.json(leaderboard);
    } catch (error) {
        console.error('Error fetching leaderboard:', error);
        res.status(500).json({ error: 'Failed to fetch leaderboard' });
    }
});

module.exports = router;
