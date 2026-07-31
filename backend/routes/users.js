const express = require('express');
const { db } = require('../config/firebase');
const { auth } = require('../middleware/auth');

const router = express.Router();

// ============================================================
// IMPORTANT: Route ordering matters in Express!
// Specific routes (like /sppid/:sppId) MUST come BEFORE 
// generic parameter routes (like /:id) to prevent conflicts.
// ============================================================

// @route   GET /api/users/sppid/:sppId
// @desc    Get user by SPP ID
// @access  Public
router.get('/sppid/:sppId', async (req, res) => {
    try {
        const sppId = req.params.sppId.toUpperCase();
        console.log(`🔍 Looking up user by SPP ID: ${sppId}`);

        const snapshot = await db.collection('users').where('spPId', '==', sppId).get();

        if (snapshot.empty) {
            console.log(`❌ No user found with SPP ID: ${sppId}`);
            return res.status(404).json({ error: 'User not found with this SPP ID' });
        }

        const userDoc = snapshot.docs[0];
        const userData = userDoc.data();
        delete userData.password;

        console.log(`✅ Found user: ${userData.name} with SPP ID: ${sppId}`);
        res.json({ user: { uid: userDoc.id, ...userData } });
    } catch (error) {
        console.error('Get user by SPP ID error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   GET /api/users/search/:query
// @desc    Search users by name
// @access  Public
router.get('/search/:query', async (req, res) => {
    try {
        const query = req.params.query.toLowerCase();

        // Firestore doesn't support LIKE queries, so we use range query
        const snapshot = await db.collection('users')
            .orderBy('name')
            .startAt(query)
            .endAt(query + '\uf8ff')
            .limit(20)
            .get();

        const users = snapshot.docs.map(doc => {
            const data = doc.data();
            delete data.password;
            return { uid: doc.id, ...data };
        });

        res.json({ users });
    } catch (error) {
        console.error('Search users error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   GET /api/users/:id/stats
// @desc    Get user player stats
// @access  Public
router.get('/:id/stats', async (req, res) => {
    try {
        const userDoc = await db.collection('users').doc(req.params.id).get();

        if (!userDoc.exists) {
            return res.status(404).json({ error: 'User not found' });
        }

        const userData = userDoc.data();

        res.json({
            name: userData.name,
            tennisBallStats: userData.tennisBallStats,
            leatherBallStats: userData.leatherBallStats
        });
    } catch (error) {
        console.error('Get stats error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   GET /api/users/:id
// @desc    Get user by ID
// @access  Public
router.get('/:id', async (req, res) => {
    try {
        const userDoc = await db.collection('users').doc(req.params.id).get();

        if (!userDoc.exists) {
            return res.status(404).json({ error: 'User not found' });
        }

        const userData = userDoc.data();
        delete userData.password;

        res.json({ user: { uid: userDoc.id, ...userData } });
    } catch (error) {
        console.error('Get user error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   PUT /api/users/:id/stats
// @desc    Update user stats (after match)
// @access  Private
router.put('/:id/stats', auth, async (req, res) => {
    try {
        const { ballType, stats } = req.body;

        if (!['tennis', 'leather'].includes(ballType)) {
            return res.status(400).json({ error: 'Invalid ball type' });
        }

        const updateField = ballType === 'tennis' ? 'tennisBallStats' : 'leatherBallStats';

        await db.collection('users').doc(req.params.id).update({
            [updateField]: stats
        });

        const userDoc = await db.collection('users').doc(req.params.id).get();

        res.json({
            message: 'Stats updated',
            [updateField]: userDoc.data()[updateField]
        });
    } catch (error) {
        console.error('Update stats error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;
