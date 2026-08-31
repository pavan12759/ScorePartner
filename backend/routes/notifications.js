const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');
const { auth } = require('../middleware/auth');
const rateLimit = require('express-rate-limit');

// ✅ Security: Rate limit notification sending to prevent spam
const notificationLimiter = rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max: 10, // Max 10 notification sends per minute per IP
    message: { error: 'Too many notification requests, please slow down' },
    standardHeaders: true,
    legacyHeaders: false,
});

// Ensure Firebase is initialized before this
// Usually done in server.js via admin.initializeApp()

/**
 * Send a push notification to specific FCM tokens
 * POST /api/notifications/send
 */
router.post('/send', auth, notificationLimiter, async (req, res) => {
    try {
        const { tokens, title, body, data } = req.body;

        if (!tokens || !Array.isArray(tokens) || tokens.length === 0) {
            return res.status(400).json({ error: 'FCM tokens are required' });
        }

        const payload = {
            notification: {
                title: title || 'New Notification',
                body: body || 'You have a new update',
            },
            data: data || {},
            tokens: tokens, // Multicast message
        };

        const response = await admin.messaging().sendEachForMulticast(payload);

        console.log(`Successfully sent ${response.successCount} messages`);
        if (response.failureCount > 0) {
            console.log(`Failed to send ${response.failureCount} messages`);
            response.responses.forEach((resp, idx) => {
                if (!resp.success) {
                    console.error(`Token [${tokens[idx]}] failed:`, resp.error);
                }
            });
        }

        res.status(200).json({
            success: true,
            successCount: response.successCount,
            failureCount: response.failureCount
        });
    } catch (error) {
        console.error('Error sending push notification:', error);
        res.status(500).json({ error: 'Failed to send notification' });
    }
});

/**
 * Trigger match start notifications for all followers of all players in a match
 * POST /api/notifications/match-start
 */
router.post('/match-start', auth, async (req, res) => {
    try {
        const { matchId, playerIds, team1Name, team2Name } = req.body;

        if (!matchId || !playerIds || !Array.isArray(playerIds)) {
            return res.status(400).json({ error: 'matchId and playerIds array are required' });
        }

        const db = admin.firestore();
        const tokens = new Set(); // Use Set to avoid duplicate notifications to same device

        // For each player, find their followers
        for (const playerId of playerIds) {
            // 1. Get follower IDs for this player
            const followersSnapshot = await db.collection('users').doc(playerId).collection('followers').get();
            const followerIds = followersSnapshot.docs.map(doc => doc.id);

            // 2. For each follower, get their FCM tokens
            for (const followerId of followerIds) {
                const tokenSnapshot = await db.collection('users').doc(followerId).collection('fcmTokens').get();
                tokenSnapshot.docs.forEach(doc => {
                    if (doc.data().token) {
                        tokens.add(doc.data().token);
                    }
                });
            }
        }

        // Convert Set to Array
        const tokensArray = Array.from(tokens);

        if (tokensArray.length === 0) {
            return res.status(200).json({ message: 'No followers to notify or no FCM tokens found', successCount: 0 });
        }

        // Send the push notification
        const payload = {
            notification: {
                title: 'Match Started! 🏏',
                body: `A player you follow is playing now: ${team1Name} vs ${team2Name}`,
            },
            data: {
                type: 'matchStart',
                matchId: matchId,
            },
            tokens: tokensArray
        };

        const response = await admin.messaging().sendEachForMulticast(payload);

        console.log(`Match start notifications sent. Success: ${response.successCount}, Failed: ${response.failureCount}`);

        res.status(200).json({
            success: true,
            successCount: response.successCount,
            failureCount: response.failureCount
        });

    } catch (error) {
        console.error('Error in match-start notifications:', error);
        res.status(500).json({ error: 'Failed to process match-start notifications' });
    }
});

module.exports = router;
