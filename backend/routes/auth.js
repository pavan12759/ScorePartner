const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { db } = require('../config/firebase');
const { auth } = require('../middleware/auth');
const rateLimit = require('express-rate-limit');

// Rate limiting for auth routes
const loginLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 5, // Limit each IP to 5 login requests per hour
    message: { error: 'Too many login attempts, please try again after an hour' },
    standardHeaders: true,
    legacyHeaders: false,
});

const registerLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 3, // Limit each IP to 3 registration requests per hour
    message: { error: 'Too many registration attempts, please try again after an hour' },
    standardHeaders: true,
    legacyHeaders: false,
});

const router = express.Router();

// Helper to generate a random 8-digit ID
const generateRandomId = (prefix) => {
    const digits = Math.floor(10000000 + Math.random() * 90000000);
    return `${prefix}${digits}`;
};

// Helper to check and generate unique SPP ID
const generateUniqueSppId = async () => {
    let sppId;
    let exists = true;
    while (exists) {
        sppId = generateRandomId('SPP');
        const snapshot = await db.collection('users').where('spPId', '==', sppId).get();
        if (snapshot.empty) {
            exists = false;
        }
    }
    return sppId;
};

// @route   POST /api/auth/register
// @desc    Register a new user
// @access  Public
router.post('/register', registerLimiter, async (req, res) => {
    try {
        const { email, password, name, phoneNumber } = req.body;

        // Validate input
        if (!email || !password || !name) {
            return res.status(400).json({ error: 'Please provide email, password, and name' });
        }

        // Check if user exists
        const usersRef = db.collection('users');
        const existingUser = await usersRef.where('email', '==', email.toLowerCase()).get();

        if (!existingUser.empty) {
            return res.status(400).json({ error: 'User already exists with this email' });
        }

        // Hash password
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        // Generate SPP ID
        const spPId = await generateUniqueSppId();

        // Create user document
        const newUser = {
            email: email.toLowerCase(),
            password: hashedPassword,
            name,
            nameLowercase: name.toLowerCase(),
            spPId,
            phoneNumber: phoneNumber || '',
            role: 'player',

            battingStyle: 'right-hand',
            bowlingStyle: 'medium',
            age: 0,
            location: '',
            profileImageUrl: '',
            instagramUrl: '',
            isVerified: false,
            isProfileComplete: false,
            createdAt: new Date(),
            lastActiveAt: new Date(),
            tennisBallStats: {
                matches: 0, runs: 0, wickets: 0, strikeRate: 0, economy: 0,
                bestScore: 0, bestBowling: '0/0', manOfMatches: 0, tournamentWins: 0
            },
            leatherBallStats: {
                matches: 0, runs: 0, wickets: 0, strikeRate: 0, economy: 0,
                bestScore: 0, bestBowling: '0/0', manOfMatches: 0, tournamentWins: 0
            }
        };

        const docRef = await usersRef.add(newUser);

        // Generate token
        const token = jwt.sign(
            { userId: docRef.id },
            process.env.JWT_SECRET,
            { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
        );

        // Remove password from response
        delete newUser.password;

        console.log(`✅ New user registered: ${email}`);

        res.status(201).json({
            message: 'User registered successfully',
            token,
            user: { uid: docRef.id, ...newUser }
        });

    } catch (error) {
        console.error('Registration error:', error);
        res.status(500).json({ error: 'Server error during registration' });
    }
});

// @route   POST /api/auth/login
// @desc    Login user
// @access  Public
router.post('/login', loginLimiter, async (req, res) => {
    try {
        const { email, password } = req.body;

        // Validate input
        if (!email || !password) {
            return res.status(400).json({ error: 'Please provide email and password' });
        }

        // Find user
        const usersRef = db.collection('users');
        const snapshot = await usersRef.where('email', '==', email.toLowerCase()).get();

        if (snapshot.empty) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const userDoc = snapshot.docs[0];
        const userData = userDoc.data();

        // Check password
        const isMatch = await bcrypt.compare(password, userData.password);
        if (!isMatch) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Generate token
        const token = jwt.sign(
            { userId: userDoc.id },
            process.env.JWT_SECRET,
            { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
        );

        // Update last active
        await userDoc.ref.update({ lastActiveAt: new Date() });

        // Remove password from response
        delete userData.password;

        console.log(`✅ User logged in: ${email}`);

        res.json({
            message: 'Login successful',
            token,
            user: { uid: userDoc.id, ...userData }
        });

    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ error: 'Server error during login' });
    }
});

// @route   GET /api/auth/profile
// @desc    Get current user profile
// @access  Private
router.get('/profile', auth, async (req, res) => {
    try {
        res.json({ user: req.user });
    } catch (error) {
        console.error('Profile error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// @route   PUT /api/auth/profile
// @desc    Update current user profile
// @access  Private
router.put('/profile', auth, async (req, res) => {
    try {
        const updates = req.body;
        const allowedUpdates = [
            'name', 'phoneNumber', 'role', 'battingStyle', 'bowlingStyle',
            'age', 'location', 'profileImageUrl', 'instagramUrl', 'isProfileComplete'
        ];

        // Filter only allowed fields
        const filteredUpdates = {};
        Object.keys(updates).forEach(key => {
            if (allowedUpdates.includes(key)) {
                filteredUpdates[key] = updates[key];
            }
        });

        if (filteredUpdates.name) {
            filteredUpdates.nameLowercase = filteredUpdates.name.toLowerCase();
        }

        filteredUpdates.lastActiveAt = new Date();

        await db.collection('users').doc(req.user.uid).update(filteredUpdates);

        const updatedDoc = await db.collection('users').doc(req.user.uid).get();
        const updatedUser = { uid: updatedDoc.id, ...updatedDoc.data() };
        delete updatedUser.password;

        console.log(`✅ Profile updated for: ${req.user.email}`);

        res.json({
            message: 'Profile updated successfully',
            user: updatedUser
        });

    } catch (error) {
        console.error('Profile update error:', error);
        res.status(500).json({ error: 'Server error during profile update' });
    }
});

module.exports = router;
