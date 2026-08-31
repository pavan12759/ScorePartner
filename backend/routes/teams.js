const express = require('express');
const { db } = require('../config/firebase');
const { auth, optionalAuth } = require('../middleware/auth');

const router = express.Router();

// Helper to generate a random 8-digit ID
const generateRandomId = (prefix) => {
    const digits = Math.floor(10000000 + Math.random() * 90000000);
    return `${prefix}${digits}`;
};

// Helper to check and generate unique SPT ID
const generateUniqueSptId = async () => {
    const db = require('../config/firebase').db;
    let sptId;
    let exists = true;
    while (exists) {
        sptId = generateRandomId('SPT');
        const snapshot = await db.collection('teams').where('spTId', '==', sptId).get();
        if (snapshot.empty) {
            exists = false;
        }
    }
    return sptId;
};

// @route   GET /api/teams

// @desc    Get all teams
// @access  Public
router.get('/', async (req, res) => {
    try {
        const { limit = 20 } = req.query;

        const snapshot = await db.collection('teams')
            .orderBy('createdAt', 'desc')
            .limit(parseInt(limit))
            .get();

        const teams = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

        res.json({ teams });
    } catch (error) {
        console.error('Get teams error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   GET /api/teams/user/:userId
// @desc    Get teams created by user
// @access  Public
router.get('/user/:userId', async (req, res) => {
    try {
        const snapshot = await db.collection('teams')
            .where('createdBy', '==', req.params.userId)
            .get();

        const teams = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        res.json({ teams });
    } catch (error) {
        console.error('Get user teams error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   GET /api/teams/sptid/:sptId
// @desc    Get team by SPT ID
// @access  Public
router.get('/sptid/:sptId', async (req, res) => {
    try {
        const sptId = req.params.sptId.toUpperCase();
        const snapshot = await db.collection('teams').where('spTId', '==', sptId).get();

        if (snapshot.empty) {
            return res.status(404).json({ error: 'Team not found' });
        }

        const teamDoc = snapshot.docs[0];
        res.json({ team: { id: teamDoc.id, ...teamDoc.data() } });
    } catch (error) {
        console.error('Get team by SPT ID error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   GET /api/teams/:id
// @desc    Get team by ID
// @access  Public
router.get('/:id', async (req, res) => {
    try {
        const teamDoc = await db.collection('teams').doc(req.params.id).get();

        if (!teamDoc.exists) {
            return res.status(404).json({ error: 'Team not found' });
        }

        res.json({ team: { id: teamDoc.id, ...teamDoc.data() } });
    } catch (error) {
        console.error('Get team error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   POST /api/teams
// @desc    Create a new team
// @access  Private
router.post('/', auth, async (req, res) => {
    try {
        const spTId = await generateUniqueSptId();
        const teamData = {
            ...req.body,
            createdBy: req.user.uid,
            spTId,
            createdAt: new Date(),
            matchesPlayed: 0,
            matchesWon: 0,
            matchesLost: 0
        };

        const docRef = await db.collection('teams').add(teamData);

        console.log(`✅ Team created: ${teamData.name} (ID: ${spTId})`);

        res.status(201).json({
            message: 'Team created successfully',
            team: { id: docRef.id, ...teamData }
        });
    } catch (error) {
        console.error('Create team error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   PUT /api/teams/:id
// @desc    Update team
// @access  Private
router.put('/:id', auth, async (req, res) => {
    try {
        const teamDoc = await db.collection('teams').doc(req.params.id).get();

        if (!teamDoc.exists) {
            return res.status(404).json({ error: 'Team not found' });
        }

        const teamData = teamDoc.data();
        if (teamData.createdBy !== req.user.uid && teamData.captainId !== req.user.uid && teamData.viceCaptainId !== req.user.uid) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        // ✅ Security: Only allow updating safe fields (prevents overwriting createdBy, spTId, etc.)
        const allowedFields = [
            'name', 'logoUrl', 'players', 'captainId', 'captainName',
            'viceCaptainId', 'viceCaptainName', 'adminIds', 'description',
            'homeGround', 'city', 'inviteLinkEnabled'
        ];
        const filteredUpdates = {};
        Object.keys(req.body).forEach(key => {
            if (allowedFields.includes(key)) {
                filteredUpdates[key] = req.body[key];
            }
        });

        await db.collection('teams').doc(req.params.id).update(filteredUpdates);

        const updatedDoc = await db.collection('teams').doc(req.params.id).get();

        res.json({
            message: 'Team updated',
            team: { id: updatedDoc.id, ...updatedDoc.data() }
        });
    } catch (error) {
        console.error('Update team error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   POST /api/teams/:id/players
// @desc    Add player to team
// @access  Private
router.post('/:id/players', auth, async (req, res) => {
    try {
        const teamDoc = await db.collection('teams').doc(req.params.id).get();

        if (!teamDoc.exists) {
            return res.status(404).json({ error: 'Team not found' });
        }

        const teamData = teamDoc.data();
        if (teamData.createdBy !== req.user.uid && teamData.captainId !== req.user.uid && teamData.viceCaptainId !== req.user.uid) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        const players = teamDoc.data().players || [];
        players.push(req.body);

        await db.collection('teams').doc(req.params.id).update({ players });

        const updatedDoc = await db.collection('teams').doc(req.params.id).get();

        res.json({
            message: 'Player added',
            team: { id: updatedDoc.id, ...updatedDoc.data() }
        });
    } catch (error) {
        console.error('Add player error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   DELETE /api/teams/:id/players/:playerId
// @desc    Remove player from team
// @access  Private
router.delete('/:id/players/:playerId', auth, async (req, res) => {
    try {
        const teamDoc = await db.collection('teams').doc(req.params.id).get();

        if (!teamDoc.exists) {
            return res.status(404).json({ error: 'Team not found' });
        }

        const teamData = teamDoc.data();
        if (teamData.createdBy !== req.user.uid && teamData.captainId !== req.user.uid && teamData.viceCaptainId !== req.user.uid) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        const players = (teamDoc.data().players || []).filter(
            p => p.userId !== req.params.playerId
        );

        await db.collection('teams').doc(req.params.id).update({ players });

        const updatedDoc = await db.collection('teams').doc(req.params.id).get();

        res.json({
            message: 'Player removed',
            team: { id: updatedDoc.id, ...updatedDoc.data() }
        });
    } catch (error) {
        console.error('Remove player error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   DELETE /api/teams/:id
// @desc    Delete team
// @access  Private
router.delete('/:id', auth, async (req, res) => {
    try {
        const teamDoc = await db.collection('teams').doc(req.params.id).get();

        if (!teamDoc.exists) {
            return res.status(404).json({ error: 'Team not found' });
        }

        if (teamDoc.data().createdBy !== req.user.uid) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        await db.collection('teams').doc(req.params.id).delete();

        res.json({ message: 'Team deleted' });
    } catch (error) {
        console.error('Delete team error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// ==================== TEAM INVITATIONS ====================

// Helper to generate a unique invite token
const generateInviteToken = () => {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let token = '';
    for (let i = 0; i < 24; i++) {
        token += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return token;
};

// @route   POST /api/teams/:id/invite
// @desc    Generate or regenerate invite link
// @access  Private (Admin/Captain only)
router.post('/:id/invite', auth, async (req, res) => {
    try {
        const teamDoc = await db.collection('teams').doc(req.params.id).get();
        if (!teamDoc.exists) {
            return res.status(404).json({ error: 'Team not found' });
        }

        const teamData = teamDoc.data();
        if (teamData.createdBy !== req.user.uid && teamData.captainId !== req.user.uid && teamData.viceCaptainId !== req.user.uid) {
            return res.status(403).json({ error: 'Not authorized. Only admin or captain can generate invite links.' });
        }

        const token = generateInviteToken();
        const expiry = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days
        const link = `https://scorepartner.in/join/team/${req.params.id}?invite=${token}`;

        await db.collection('teams').doc(req.params.id).update({
            inviteToken: token,
            inviteLinkEnabled: true,
            inviteExpiry: expiry.toISOString(),
            inviteLink: link,
        });

        console.log(`✅ Invite link generated for team ${teamData.name}`);
        res.json({ link, token, expiry: expiry.toISOString() });
    } catch (error) {
        console.error('Generate invite error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   DELETE /api/teams/:id/invite
// @desc    Revoke invite link
// @access  Private (Admin/Captain only)
router.delete('/:id/invite', auth, async (req, res) => {
    try {
        const teamDoc = await db.collection('teams').doc(req.params.id).get();
        if (!teamDoc.exists) {
            return res.status(404).json({ error: 'Team not found' });
        }

        const teamData = teamDoc.data();
        if (teamData.createdBy !== req.user.uid && teamData.captainId !== req.user.uid && teamData.viceCaptainId !== req.user.uid) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        await db.collection('teams').doc(req.params.id).update({
            inviteToken: '',
            inviteLinkEnabled: false,
            inviteExpiry: null,
            inviteLink: '',
        });

        res.json({ message: 'Invite link revoked' });
    } catch (error) {
        console.error('Revoke invite error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   GET /api/teams/:id/invite/validate
// @desc    Validate invite token (public - used when player opens link)
// @access  Public
router.get('/:id/invite/validate', async (req, res) => {
    try {
        const { token } = req.query;
        if (!token) {
            return res.status(400).json({ error: 'Token is required' });
        }

        const teamDoc = await db.collection('teams').doc(req.params.id).get();
        if (!teamDoc.exists) {
            return res.status(404).json({ error: 'Team not found' });
        }

        const teamData = teamDoc.data();

        if (teamData.inviteToken !== token) {
            return res.status(400).json({ error: 'Invalid invite token' });
        }
        if (!teamData.inviteLinkEnabled) {
            return res.status(400).json({ error: 'Invite link is disabled' });
        }
        if (teamData.inviteExpiry && new Date(teamData.inviteExpiry) < new Date()) {
            return res.status(400).json({ error: 'Invite link has expired' });
        }

        res.json({
            valid: true,
            team: {
                id: teamDoc.id,
                name: teamData.name,
                captainName: teamData.captainName,
                logoUrl: teamData.logoUrl || '',
                playerCount: (teamData.players || []).length,
                matchesPlayed: teamData.matchesPlayed || 0,
                matchesWon: teamData.matchesWon || 0,
                spTId: teamData.spTId || '',
            }
        });
    } catch (error) {
        console.error('Validate invite error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   POST /api/teams/:id/join-requests
// @desc    Submit a join request
// @access  Private
router.post('/:id/join-requests', auth, async (req, res) => {
    try {
        const teamDoc = await db.collection('teams').doc(req.params.id).get();
        if (!teamDoc.exists) {
            return res.status(404).json({ error: 'Team not found' });
        }

        const teamData = teamDoc.data();
        const playerId = req.user.uid;

        // Check if already a member
        const isMember = (teamData.players || []).some(p => p.userId === playerId);
        if (isMember) {
            return res.status(400).json({ error: 'You are already a member of this team' });
        }

        // Check for existing pending request
        const existingSnapshot = await db.collection('joinRequests')
            .where('playerId', '==', playerId)
            .where('teamId', '==', req.params.id)
            .where('status', '==', 'pending')
            .limit(1)
            .get();

        if (!existingSnapshot.empty) {
            return res.status(400).json({ error: 'You already have a pending request for this team' });
        }

        const requestData = {
            teamId: req.params.id,
            teamName: teamData.name,
            playerId: playerId,
            playerName: req.body.playerName || req.user.name || '',
            playerPhotoUrl: req.body.playerPhotoUrl || '',
            playerSpPId: req.body.playerSpPId || '',
            playerRole: req.body.playerRole || '',
            battingStyle: req.body.battingStyle || '',
            bowlingStyle: req.body.bowlingStyle || '',
            playerCity: req.body.playerCity || '',
            status: 'pending',
            requestedAt: new Date(),
            reviewedAt: null,
            reviewedBy: '',
        };

        const docRef = await db.collection('joinRequests').add(requestData);

        console.log(`✅ Join request created: ${docRef.id} for team ${teamData.name}`);
        res.status(201).json({
            message: 'Join request submitted',
            requestId: docRef.id,
        });
    } catch (error) {
        console.error('Create join request error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   GET /api/teams/:id/join-requests
// @desc    Get pending join requests for a team (admin only)
// @access  Private
router.get('/:id/join-requests', auth, async (req, res) => {
    try {
        const teamDoc = await db.collection('teams').doc(req.params.id).get();
        if (!teamDoc.exists) {
            return res.status(404).json({ error: 'Team not found' });
        }

        const teamData = teamDoc.data();
        if (teamData.createdBy !== req.user.uid && teamData.captainId !== req.user.uid && teamData.viceCaptainId !== req.user.uid) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        const snapshot = await db.collection('joinRequests')
            .where('teamId', '==', req.params.id)
            .where('status', '==', 'pending')
            .orderBy('requestedAt', 'desc')
            .get();

        const requests = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        res.json({ requests });
    } catch (error) {
        console.error('Get join requests error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   PUT /api/teams/:id/join-requests/:requestId/accept
// @desc    Accept a join request
// @access  Private (Admin/Captain only)
router.put('/:id/join-requests/:requestId/accept', auth, async (req, res) => {
    try {
        const teamDoc = await db.collection('teams').doc(req.params.id).get();
        if (!teamDoc.exists) {
            return res.status(404).json({ error: 'Team not found' });
        }

        const teamData = teamDoc.data();
        if (teamData.createdBy !== req.user.uid && teamData.captainId !== req.user.uid && teamData.viceCaptainId !== req.user.uid) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        const requestDoc = await db.collection('joinRequests').doc(req.params.requestId).get();
        if (!requestDoc.exists) {
            return res.status(404).json({ error: 'Join request not found' });
        }

        const requestData = requestDoc.data();
        if (requestData.status !== 'pending') {
            return res.status(400).json({ error: 'Request already processed' });
        }

        // Add player to team
        const players = teamData.players || [];
        players.push({
            userId: requestData.playerId,
            spPId: requestData.playerSpPId || '',
            name: requestData.playerName,
            role: requestData.playerRole || '',
            battingStyle: requestData.battingStyle || '',
            bowlingStyle: requestData.bowlingStyle || '',
            isCaptain: false,
            isViceCaptain: false,
            isRegistered: true,
        });

        await db.collection('teams').doc(req.params.id).update({ players });

        // Update request status
        await db.collection('joinRequests').doc(req.params.requestId).update({
            status: 'accepted',
            reviewedAt: new Date(),
            reviewedBy: req.user.uid,
        });

        console.log(`✅ Join request ${req.params.requestId} accepted`);
        res.json({ message: 'Join request accepted' });
    } catch (error) {
        console.error('Accept join request error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   PUT /api/teams/:id/join-requests/:requestId/reject
// @desc    Reject a join request
// @access  Private (Admin/Captain only)
router.put('/:id/join-requests/:requestId/reject', auth, async (req, res) => {
    try {
        const teamDoc = await db.collection('teams').doc(req.params.id).get();
        if (!teamDoc.exists) {
            return res.status(404).json({ error: 'Team not found' });
        }

        const teamData = teamDoc.data();
        if (teamData.createdBy !== req.user.uid && teamData.captainId !== req.user.uid && teamData.viceCaptainId !== req.user.uid) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        const requestDoc = await db.collection('joinRequests').doc(req.params.requestId).get();
        if (!requestDoc.exists) {
            return res.status(404).json({ error: 'Join request not found' });
        }

        if (requestDoc.data().status !== 'pending') {
            return res.status(400).json({ error: 'Request already processed' });
        }

        await db.collection('joinRequests').doc(req.params.requestId).update({
            status: 'rejected',
            reviewedAt: new Date(),
            reviewedBy: req.user.uid,
        });

        console.log(`✅ Join request ${req.params.requestId} rejected`);
        res.json({ message: 'Join request rejected' });
    } catch (error) {
        console.error('Reject join request error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   PUT /api/teams/:id/rename
// @desc    Rename team and propagate to matches & tournaments
// @access  Public/Private (team creator or captain)
// ✅ Security Fix: Changed from optionalAuth to auth — require authentication
router.put('/:id/rename', auth, async (req, res) => {
    try {
        const { name } = req.body;
        if (!name || !name.trim()) {
            return res.status(400).json({ error: 'Name is required' });
        }

        const newName = name.trim();
        const teamId = req.params.id;

        const teamDoc = await db.collection('teams').doc(teamId).get();
        if (!teamDoc.exists) {
            return res.status(404).json({ error: 'Team not found' });
        }

        const teamData = teamDoc.data();
        // ✅ Security: Always check authorization (no more optional bypass)
        if (teamData.createdBy !== req.user.uid && teamData.captainId !== req.user.uid && teamData.viceCaptainId !== req.user.uid) {
            return res.status(403).json({ error: 'Not authorized' });
        }

        // Update team name
        await db.collection('teams').doc(teamId).update({ name: newName });

        // --- Propagate to matches where this team is team1 ---
        const matchesAsTeam1 = await db.collection('matches')
            .where('team1Id', '==', teamId).get();
        for (const doc of matchesAsTeam1.docs) {
            await doc.ref.update({ team1Name: newName });
        }

        // --- Propagate to matches where this team is team2 ---
        const matchesAsTeam2 = await db.collection('matches')
            .where('team2Id', '==', teamId).get();
        for (const doc of matchesAsTeam2.docs) {
            await doc.ref.update({ team2Name: newName });
        }

        // --- Propagate to tournaments ---
        const tournamentsWithTeam = await db.collection('tournaments')
            .where('registeredTeamIds', 'array-contains', teamId).get();

        for (const doc of tournamentsWithTeam.docs) {
            const tData = doc.data();
            let changed = false;
            const updateData = {};

            // Update fixtures
            if (tData.fixtures && Array.isArray(tData.fixtures)) {
                const fixtures = tData.fixtures.map(f => {
                    const updated = { ...f };
                    if (f.team1Id === teamId) { updated.team1Name = newName; changed = true; }
                    if (f.team2Id === teamId) { updated.team2Name = newName; changed = true; }
                    return updated;
                });
                if (changed) updateData.fixtures = fixtures;
            }

            // Update points table
            if (tData.pointsTable && Array.isArray(tData.pointsTable)) {
                const pointsTable = tData.pointsTable.map(p => {
                    if (p.teamId === teamId) {
                        changed = true;
                        return { ...p, teamName: newName };
                    }
                    return p;
                });
                if (changed) updateData.pointsTable = pointsTable;
            }

            if (changed) {
                await doc.ref.update(updateData);
            }
        }

        const totalUpdated = matchesAsTeam1.docs.length + matchesAsTeam2.docs.length;
        console.log(`✅ Team ${teamId} renamed to "${newName}". Updated ${totalUpdated} matches, ${tournamentsWithTeam.docs.length} tournaments.`);

        res.json({ message: 'Team renamed successfully', matchesUpdated: totalUpdated, tournamentsUpdated: tournamentsWithTeam.docs.length });
    } catch (error) {
        console.error('Rename team error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;
