const express = require('express');
const { db } = require('../config/firebase');
const { auth } = require('../middleware/auth');

const router = express.Router();

// @route   GET /api/tournaments
// @desc    Get all tournaments
// @access  Public
router.get('/', async (req, res) => {
    try {
        const { status, limit = 20 } = req.query;

        let query = db.collection('tournaments').orderBy('startDate', 'desc');

        if (status) {
            query = db.collection('tournaments').where('status', '==', status).orderBy('startDate', 'desc');
        }

        const snapshot = await query.limit(parseInt(limit)).get();
        const tournaments = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

        res.json({ tournaments });
    } catch (error) {
        console.error('Get tournaments error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   GET /api/tournaments/upcoming
// @desc    Get upcoming tournaments
// @access  Public
router.get('/upcoming', async (req, res) => {
    try {
        const snapshot = await db.collection('tournaments')
            .where('status', '==', 'upcoming')
            .orderBy('startDate', 'asc')
            .limit(20)
            .get();

        const tournaments = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        res.json({ tournaments });
    } catch (error) {
        console.error('Get upcoming tournaments error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   GET /api/tournaments/:id
// @desc    Get tournament by ID
// @access  Public
router.get('/:id', async (req, res) => {
    try {
        const tournamentDoc = await db.collection('tournaments').doc(req.params.id).get();

        if (!tournamentDoc.exists) {
            return res.status(404).json({ error: 'Tournament not found' });
        }

        res.json({ tournament: { id: tournamentDoc.id, ...tournamentDoc.data() } });
    } catch (error) {
        console.error('Get tournament error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   POST /api/tournaments
// @desc    Create a new tournament
// @access  Private
router.post('/', auth, async (req, res) => {
    try {
        const tournamentData = {
            ...req.body,
            organizerId: req.user.uid,
            organizerName: req.user.name,
            registeredTeamIds: [],
            createdAt: new Date()
        };

        const docRef = await db.collection('tournaments').add(tournamentData);

        console.log(`✅ Tournament created: ${tournamentData.name}`);

        res.status(201).json({
            message: 'Tournament created successfully',
            tournament: { id: docRef.id, ...tournamentData }
        });
    } catch (error) {
        console.error('Create tournament error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   PUT /api/tournaments/:id
// @desc    Update tournament
// @access  Private
router.put('/:id', auth, async (req, res) => {
    try {
        const tournamentDoc = await db.collection('tournaments').doc(req.params.id).get();

        if (!tournamentDoc.exists) {
            return res.status(404).json({ error: 'Tournament not found' });
        }

        if (tournamentDoc.data().organizerId !== req.user.uid) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        // ✅ Security: Only allow updating safe fields (prevents overwriting organizerId, createdAt)
        const allowedFields = [
            'name', 'description', 'matchType', 'format', 'oversPerMatch',
            'maxTeams', 'startDate', 'endDate', 'location', 'status',
            'teams', 'fixtures', 'pointsTable', 'prize', 'rules',
            'registeredTeamIds', 'logoUrl', 'bannerUrl', 'updatedAt'
        ];
        const filteredUpdates = {};
        Object.keys(req.body).forEach(key => {
            if (allowedFields.includes(key)) {
                filteredUpdates[key] = req.body[key];
            }
        });

        await db.collection('tournaments').doc(req.params.id).update(filteredUpdates);

        const updatedDoc = await db.collection('tournaments').doc(req.params.id).get();

        res.json({
            message: 'Tournament updated',
            tournament: { id: updatedDoc.id, ...updatedDoc.data() }
        });
    } catch (error) {
        console.error('Update tournament error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   POST /api/tournaments/:id/register
// @desc    Register team for tournament
// @access  Private
router.post('/:id/register', auth, async (req, res) => {
    try {
        const { teamId } = req.body;

        const tournamentDoc = await db.collection('tournaments').doc(req.params.id).get();

        if (!tournamentDoc.exists) {
            return res.status(404).json({ error: 'Tournament not found' });
        }

        const data = tournamentDoc.data();
        const registeredTeamIds = data.registeredTeamIds || [];

        if (registeredTeamIds.length >= data.maxTeams) {
            return res.status(400).json({ error: 'Tournament is full' });
        }

        if (registeredTeamIds.includes(teamId)) {
            return res.status(400).json({ error: 'Team already registered' });
        }

        registeredTeamIds.push(teamId);

        await db.collection('tournaments').doc(req.params.id).update({ registeredTeamIds });

        const updatedDoc = await db.collection('tournaments').doc(req.params.id).get();

        console.log(`✅ Team registered for tournament: ${data.name}`);

        res.json({
            message: 'Team registered successfully',
            tournament: { id: updatedDoc.id, ...updatedDoc.data() }
        });
    } catch (error) {
        console.error('Register team error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   DELETE /api/tournaments/:id/register/:teamId
// @desc    Unregister team from tournament
// @access  Private
router.delete('/:id/register/:teamId', auth, async (req, res) => {
    try {
        const tournamentDoc = await db.collection('tournaments').doc(req.params.id).get();

        if (!tournamentDoc.exists) {
            return res.status(404).json({ error: 'Tournament not found' });
        }

        const registeredTeamIds = (tournamentDoc.data().registeredTeamIds || []).filter(
            id => id !== req.params.teamId
        );

        await db.collection('tournaments').doc(req.params.id).update({ registeredTeamIds });

        const updatedDoc = await db.collection('tournaments').doc(req.params.id).get();

        res.json({
            message: 'Team unregistered',
            tournament: { id: updatedDoc.id, ...updatedDoc.data() }
        });
    } catch (error) {
        console.error('Unregister team error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   DELETE /api/tournaments/:id
// @desc    Delete tournament
// @access  Private
router.delete('/:id', auth, async (req, res) => {
    try {
        const tournamentDoc = await db.collection('tournaments').doc(req.params.id).get();

        if (!tournamentDoc.exists) {
            return res.status(404).json({ error: 'Tournament not found' });
        }

        if (tournamentDoc.data().organizerId !== req.user.uid) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        await db.collection('tournaments').doc(req.params.id).delete();

        res.json({ message: 'Tournament deleted' });
    } catch (error) {
        console.error('Delete tournament error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;
