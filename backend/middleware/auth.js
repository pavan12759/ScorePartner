const { admin, db } = require('../config/firebase');
const jwt = require('jsonwebtoken');

async function loadUser(uid, decodedToken = {}) {
    let userData = {};
    try {
        const userDoc = await db.collection('users').doc(uid).get();
        if (userDoc.exists) {
            userData = userDoc.data();
            delete userData.password;
        }
    } catch (dbError) {
        console.log('User lookup optional:', dbError.message);
    }

    return {
        uid,
        email: decodedToken.email || '',
        name: decodedToken.name || '',
        ...userData
    };
}

async function verifyToken(token) {
    try {
        const decodedToken = await admin.auth().verifyIdToken(token);
        return loadUser(decodedToken.uid, decodedToken);
    } catch (firebaseError) {
        if (!process.env.JWT_SECRET) {
            throw firebaseError;
        }

        const decodedToken = jwt.verify(token, process.env.JWT_SECRET);
        const uid = decodedToken.uid || decodedToken.userId;
        if (!uid) {
            throw new Error('Token missing user id');
        }
        return loadUser(uid, decodedToken);
    }
}

const auth = async (req, res, next) => {
    try {
        // Get token from header
        const authHeader = req.header('Authorization');

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'No token, authorization denied' });
        }

        const token = authHeader.replace('Bearer ', '');

        req.user = await verifyToken(token);
        req.token = token;
        next();
    } catch (error) {
        console.error('Auth middleware error:', error.message);
        res.status(401).json({ error: 'Token is not valid' });
    }
};

// Optional auth - doesn't fail if no token
const optionalAuth = async (req, res, next) => {
    try {
        const authHeader = req.header('Authorization');

        if (authHeader && authHeader.startsWith('Bearer ')) {
            const token = authHeader.replace('Bearer ', '');
            req.user = await verifyToken(token);
        }

        next();
    } catch (error) {
        // Continue without auth
        console.log('Optional auth failed:', error.message);
        next();
    }
};

module.exports = { auth, optionalAuth };
