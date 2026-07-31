const admin = require('firebase-admin');

// Ensure you have a service account key or rely on default credentials if running locally
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkMatches() {
    console.log("Fetching a match...");
    const matchesSnapshot = await db.collection('matches').limit(1).get();

    if (matchesSnapshot.empty) {
        console.log("No matches found.");
        return;
    }

    matchesSnapshot.forEach(doc => {
        console.log("Match ID:", doc.id);
        const data = doc.data();
        console.log("playerIds:", data.playerIds);
        console.log("status:", data.status);
        console.log("team1Score:", JSON.stringify(data.team1Score).substring(0, 100) + "...");
    });
}

checkMatches().catch(console.error);
