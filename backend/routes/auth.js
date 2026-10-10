const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { db, admin } = require('../config/firebase');
const { auth } = require('../middleware/auth');
const rateLimit = require('express-rate-limit');
const { msg91Service, formatPhoneE164 } = require('../services/msg91-service');

// Rate limiting for auth routes
const loginLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 10, // Limit each IP to 10 login requests per hour
    message: { error: 'Too many login attempts, please try again after an hour' },
    standardHeaders: true,
    legacyHeaders: false,
});

const registerLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 10, // Limit each IP to 10 registration requests per hour
    message: { error: 'Too many registration attempts, please try again after an hour' },
    standardHeaders: true,
    legacyHeaders: false,
});

const otpLimiter = rateLimit({
    windowMs: 10 * 60 * 1000, // 10 minutes
    max: 10, // Max 10 OTP requests per 10 minutes per IP
    message: { error: 'Too many OTP attempts, please try again after a few minutes' },
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

// @route   POST /api/auth/otp/send
// @desc    Send OTP to mobile number via MSG91
// @access  Public
router.post('/otp/send', otpLimiter, async (req, res) => {
    try {
        const { phoneNumber } = req.body;
        if (!phoneNumber) {
            return res.status(400).json({ error: 'Please provide a valid phone number' });
        }

        const result = await msg91Service.sendOtp(phoneNumber);
        res.json({
            success: true,
            message: result.message,
            devMode: result.devMode || false,
        });
    } catch (error) {
        console.error('Send OTP error:', error.message);
        res.status(500).json({ error: error.message || 'Failed to send OTP' });
    }
});

// @route   POST /api/auth/otp/resend
// @desc    Resend OTP to mobile number via MSG91
// @access  Public
router.post('/otp/resend', otpLimiter, async (req, res) => {
    try {
        const { phoneNumber, retryType } = req.body;
        if (!phoneNumber) {
            return res.status(400).json({ error: 'Please provide a valid phone number' });
        }

        const result = await msg91Service.resendOtp(phoneNumber, retryType || 'text');
        res.json({
            success: true,
            message: result.message,
            devMode: result.devMode || false,
        });
    } catch (error) {
        console.error('Resend OTP error:', error.message);
        res.status(500).json({ error: error.message || 'Failed to resend OTP' });
    }
});

// @route   POST /api/auth/otp/verify
// @desc    Verify OTP and log in / register user
// @access  Public
router.post('/otp/verify', otpLimiter, async (req, res) => {
    try {
        const { phoneNumber, otp } = req.body;
        if (!phoneNumber || !otp) {
            return res.status(400).json({ error: 'Please provide phone number and OTP' });
        }

        // 1. Verify OTP with MSG91
        await msg91Service.verifyOtp(phoneNumber, otp);

        const e164Phone = formatPhoneE164(phoneNumber);

        // 2. Find or create Firebase Auth user
        let firebaseUser = null;
        try {
            firebaseUser = await admin.auth().getUserByPhoneNumber(e164Phone);
        } catch (err) {
            if (err.code === 'auth/user-not-found') {
                try {
                    firebaseUser = await admin.auth().createUser({
                        phoneNumber: e164Phone,
                    });
                    console.log(`✅ Created new Firebase Auth user for ${e164Phone}`);
                } catch (createErr) {
                    console.warn('⚠️ Firebase createUser warning:', createErr.message);
                }
            } else {
                console.warn('⚠️ Firebase getUserByPhoneNumber warning:', err.message);
            }
        }

        let uid = firebaseUser ? firebaseUser.uid : null;
        const usersRef = db.collection('users');

        // 3. Find or create Firestore profile document
        let userDoc = null;
        if (uid) {
            userDoc = await usersRef.doc(uid).get();
        }

        if (!userDoc || !userDoc.exists) {
            const querySnap = await usersRef.where('phoneNumber', '==', e164Phone).limit(1).get();
            if (!querySnap.empty) {
                userDoc = querySnap.docs[0];
                uid = userDoc.id;
            }
        }

        let userData;
        if (userDoc && userDoc.exists) {
            userData = userDoc.data();
            uid = userDoc.id;
            await usersRef.doc(uid).update({ lastActiveAt: new Date() });
        } else {
            const spPId = await generateUniqueSppId();
            userData = {
                phoneNumber: e164Phone,
                email: '',
                name: '',
                nameLowercase: '',
                spPId,
                role: 'player',
                battingStyle: 'right-hand',
                bowlingStyle: 'medium',
                age: 0,
                location: '',
                profileImageUrl: '',
                instagramUrl: '',
                isVerified: true,
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

            if (uid) {
                await usersRef.doc(uid).set(userData);
            } else {
                const newDocRef = await usersRef.add(userData);
                uid = newDocRef.id;
            }
            console.log(`✅ Created Firestore user profile for ${e164Phone} (SPP: ${userData.spPId})`);
        }

        // 4. Generate custom Firebase token if possible
        let customToken = null;
        if (uid) {
            try {
                customToken = await admin.auth().createCustomToken(uid);
            } catch (tokenErr) {
                console.warn('⚠️ Custom token creation skipped/failed:', tokenErr.message);
            }
        }

        // 5. Generate backend JWT token
        const token = jwt.sign(
            { userId: uid, uid, phoneNumber: e164Phone },
            process.env.JWT_SECRET,
            { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
        );

        delete userData.password;

        res.json({
            message: 'OTP verified successfully',
            customToken,
            token,
            user: { uid, ...userData }
        });

    } catch (error) {
        console.error('Verify OTP error:', error.message);
        res.status(400).json({ error: error.message || 'OTP verification failed' });
    }
});

// @route   POST /api/auth/otp/verify-token
// @desc    Verify MSG91 Client SDK (sendotp_flutter_sdk) Access Token on server
// @access  Public
router.post('/otp/verify-token', otpLimiter, async (req, res) => {
    try {
        const { accessToken } = req.body;
        if (!accessToken) {
            return res.status(400).json({ error: 'Please provide access token' });
        }

        // 1. Verify access token with MSG91 server-side
        const { mobile } = await msg91Service.verifyAccessToken(accessToken);
        if (!mobile) {
            return res.status(400).json({ error: 'Could not verify access token' });
        }

        const e164Phone = formatPhoneE164(mobile);

        // 2. Find or create Firebase Auth user
        let firebaseUser = null;
        try {
            firebaseUser = await admin.auth().getUserByPhoneNumber(e164Phone);
        } catch (err) {
            if (err.code === 'auth/user-not-found') {
                try {
                    firebaseUser = await admin.auth().createUser({
                        phoneNumber: e164Phone,
                    });
                } catch (createErr) {
                    console.warn('⚠️ Firebase createUser warning:', createErr.message);
                }
            }
        }

        let uid = firebaseUser ? firebaseUser.uid : null;
        const usersRef = db.collection('users');

        // 3. Find or create Firestore profile document
        let userDoc = null;
        if (uid) {
            userDoc = await usersRef.doc(uid).get();
        }

        if (!userDoc || !userDoc.exists) {
            const querySnap = await usersRef.where('phoneNumber', '==', e164Phone).limit(1).get();
            if (!querySnap.empty) {
                userDoc = querySnap.docs[0];
                uid = userDoc.id;
            }
        }

        let userData;
        if (userDoc && userDoc.exists) {
            userData = userDoc.data();
            uid = userDoc.id;
            await usersRef.doc(uid).update({ lastActiveAt: new Date() });
        } else {
            const spPId = await generateUniqueSppId();
            userData = {
                phoneNumber: e164Phone,
                email: '',
                name: '',
                nameLowercase: '',
                spPId,
                role: 'player',
                battingStyle: 'right-hand',
                bowlingStyle: 'medium',
                age: 0,
                location: '',
                profileImageUrl: '',
                instagramUrl: '',
                isVerified: true,
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

            if (uid) {
                await usersRef.doc(uid).set(userData);
            } else {
                const newDocRef = await usersRef.add(userData);
                uid = newDocRef.id;
            }
        }

        // 4. Generate custom Firebase token if possible
        let customToken = null;
        if (uid) {
            try {
                customToken = await admin.auth().createCustomToken(uid);
            } catch (tokenErr) {
                console.warn('⚠️ Custom token creation warning:', tokenErr.message);
            }
        }

        // 5. Generate backend JWT token
        const token = jwt.sign(
            { userId: uid, uid, phoneNumber: e164Phone },
            process.env.JWT_SECRET,
            { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
        );

        delete userData.password;

        res.json({
            message: 'Access token verified successfully',
            customToken,
            token,
            user: { uid, ...userData }
        });

    } catch (error) {
        console.error('Verify access token error:', error.message);
        res.status(400).json({ error: error.message || 'Token verification failed' });
    }
});

module.exports = router;
