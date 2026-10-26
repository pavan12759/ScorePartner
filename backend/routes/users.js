const express = require('express');
const rateLimit = require('express-rate-limit');
const { db } = require('../config/firebase');
const { auth } = require('../middleware/auth');

const router = express.Router();

// Rate limiting for user lookups to prevent enumeration
const lookupLimiter = rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max: 30, // 30 lookups per minute per IP
    message: { error: 'Too many search requests. Please try again after a minute.' },
    standardHeaders: true,
    legacyHeaders: false,
});

// Helper: Normalize Indian mobile numbers consistently
// Accepts 10 digits, or with +91, 91, 0, spaces, hyphens, parentheses
function normalizeIndianPhone(input) {
    if (!input) return null;
    let digits = input.toString().replace(/\D/g, '');
    if (digits.startsWith('0') && digits.length === 11) {
        digits = digits.substring(1);
    } else if (digits.startsWith('91') && digits.length === 12) {
        digits = digits.substring(2);
    } else if (digits.startsWith('091') && digits.length === 13) {
        digits = digits.substring(3);
    }
    if (digits.length !== 10) {
        return null;
    }
    return digits;
}

// Helper: Mask phone number to protect privacy (e.g. +91 ****** 1136)
function maskPhoneNumber(phone) {
    if (!phone) return '';
    const digits = phone.toString().replace(/\D/g, '');
    if (digits.length < 4) return '******';
    const last4 = digits.slice(-4);
    return `+91 ****** ${last4}`;
}

// Helper: Build Firestore candidate formats for a 10-digit phone
function getPhoneCandidateFormats(tenDigits) {
    return [
        `+91${tenDigits}`,
        `91${tenDigits}`,
        tenDigits,
        `0${tenDigits}`,
    ];
}

// ============================================================
// IMPORTANT: Route ordering matters in Express!
// Specific routes (like /sppid/:sppId, /phone/:phoneNumber, /lookup)
// MUST come BEFORE generic parameter routes (like /:id) to prevent conflicts.
// ============================================================

// @route   GET /api/users/lookup
// @desc    Unified lookup by either SPP ID or mobile number
// @access  Public
router.get('/lookup', lookupLimiter, async (req, res) => {
    try {
        const query = (req.query.q || req.query.query || '').trim();
        if (!query) {
            return res.status(400).json({ error: 'Please enter an SPP ID or mobile number' });
        }

        const isSpp = query.toUpperCase().startsWith('SPP');
        if (isSpp) {
            const sppId = query.toUpperCase();
            console.log(`🔍 Unified lookup: searching by SPP ID ${sppId}`);
            const snapshot = await db.collection('users').where('spPId', '==', sppId).limit(1).get();
            if (snapshot.empty) {
                return res.status(404).json({ error: 'No registered player found' });
            }
            const userDoc = snapshot.docs[0];
            const userData = userDoc.data();
            delete userData.password;
            if (userData.phoneNumber) {
                userData.phoneNumber = maskPhoneNumber(userData.phoneNumber);
            }
            return res.json({ user: { uid: userDoc.id, ...userData }, searchType: 'sppId' });
        }

        // Mobile number search
        const normalized = normalizeIndianPhone(query);
        if (!normalized) {
            return res.status(400).json({ error: 'Invalid search input. Enter a valid SPP ID or 10-digit mobile number' });
        }

        console.log(`🔍 Unified lookup: searching by normalized mobile ${normalized}`);
        const candidateFormats = getPhoneCandidateFormats(normalized);
        const snapshot = await db.collection('users')
            .where('phoneNumber', 'in', candidateFormats)
            .limit(5)
            .get();

        if (snapshot.empty) {
            return res.status(404).json({ error: 'No registered player found' });
        }

        // Only return registered, verified players (do not treat unverified phone as account proof)
        const verifiedDoc = snapshot.docs.find(doc => {
            const data = doc.data();
            return data.isVerified === true;
        }) || snapshot.docs[0];

        const userData = verifiedDoc.data();
        if (userData.isVerified === false) {
            return res.status(404).json({ error: 'No registered player found' });
        }

        delete userData.password;
        if (userData.phoneNumber) {
            userData.phoneNumber = maskPhoneNumber(userData.phoneNumber);
        }

        console.log(`✅ Found user by phone: ${userData.name} (SPP ID: ${userData.spPId})`);
        res.json({ user: { uid: verifiedDoc.id, ...userData }, searchType: 'mobile' });
    } catch (error) {
        console.error('Unified lookup error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   GET /api/users/sppid/:sppId
// @desc    Get user by SPP ID
// @access  Public
router.get('/sppid/:sppId', lookupLimiter, async (req, res) => {
    try {
        const sppId = req.params.sppId.toUpperCase();
        console.log(`🔍 Looking up user by SPP ID: ${sppId}`);

        const snapshot = await db.collection('users').where('spPId', '==', sppId).limit(1).get();

        if (snapshot.empty) {
            console.log(`❌ No user found with SPP ID: ${sppId}`);
            return res.status(404).json({ error: 'No registered player found' });
        }

        const userDoc = snapshot.docs[0];
        const userData = userDoc.data();
        delete userData.password;
        if (userData.phoneNumber) {
            userData.phoneNumber = maskPhoneNumber(userData.phoneNumber);
        }

        console.log(`✅ Found user: ${userData.name} with SPP ID: ${sppId}`);
        res.json({ user: { uid: userDoc.id, ...userData } });
    } catch (error) {
        console.error('Get user by SPP ID error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   GET /api/users/phone/:phoneNumber
// @desc    Get user by verified mobile number
// @access  Public
router.get('/phone/:phoneNumber', lookupLimiter, async (req, res) => {
    try {
        const rawPhone = req.params.phoneNumber;
        const normalized = normalizeIndianPhone(rawPhone);

        if (!normalized) {
            return res.status(400).json({ error: 'Invalid mobile number format. Please provide a valid 10-digit Indian number' });
        }

        console.log(`🔍 Looking up user by phone: normalized ${normalized}`);
        const candidateFormats = getPhoneCandidateFormats(normalized);

        const snapshot = await db.collection('users')
            .where('phoneNumber', 'in', candidateFormats)
            .limit(5)
            .get();

        if (snapshot.empty) {
            console.log(`❌ No user found with phone: ${normalized}`);
            return res.status(404).json({ error: 'No registered player found' });
        }

        const verifiedDoc = snapshot.docs.find(doc => {
            const data = doc.data();
            return data.isVerified === true;
        }) || snapshot.docs[0];

        const userData = verifiedDoc.data();
        if (userData.isVerified === false) {
            return res.status(404).json({ error: 'No registered player found' });
        }

        delete userData.password;
        if (userData.phoneNumber) {
            userData.phoneNumber = maskPhoneNumber(userData.phoneNumber);
        }

        console.log(`✅ Found user: ${userData.name} with SPP ID: ${userData.spPId}`);
        res.json({ user: { uid: verifiedDoc.id, ...userData } });
    } catch (error) {
        console.error('Get user by phone error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   GET /api/users/search/:query
// @desc    Search users by name
// @access  Public
router.get('/search/:query', async (req, res) => {
    try {
        const query = req.params.query.toLowerCase();

        // Firestore doesn't support LIKE queries, so we use range query on nameLowercase
        const snapshot = await db.collection('users')
            .orderBy('nameLowercase')
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
        // ✅ Security: Only allow users to update their own stats
        if (req.user.uid !== req.params.id) {
            return res.status(403).json({ error: 'Not authorized to update another user\'s stats' });
        }

        const { ballType, stats } = req.body;

        if (!['tennis', 'leather'].includes(ballType)) {
            return res.status(400).json({ error: 'Invalid ball type' });
        }

        // ✅ Security: Whitelist allowed stat fields to prevent injection
        const allowedStatFields = [
            'matches', 'runs', 'wickets', 'strikeRate', 'economy',
            'bestScore', 'bestBowling', 'manOfMatches', 'tournamentWins',
            'totalBallsBatted', 'totalBallsBowled', 'totalRunsConceded'
        ];
        const filteredStats = {};
        Object.keys(stats || {}).forEach(key => {
            if (allowedStatFields.includes(key)) {
                filteredStats[key] = stats[key];
            }
        });

        const updateField = ballType === 'tennis' ? 'tennisBallStats' : 'leatherBallStats';

        await db.collection('users').doc(req.params.id).update({
            [updateField]: filteredStats
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
