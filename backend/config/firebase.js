const admin = require('firebase-admin');

// Initialize Firebase Admin SDK securely using environment variables
const projectId = process.env.FIREBASE_PROJECT_ID || 'scorepatner-3f634';
const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
let privateKey = process.env.FIREBASE_PRIVATE_KEY;

if (privateKey) {
  // Handle escaped newline characters in the private key string from .env
  privateKey = privateKey.replace(/\\n/g, '\n');
  
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId,
      clientEmail,
      privateKey,
    })
  });
  console.log('✅ Firebase Admin SDK initialized with secure credentials');
} else {
  // Fallback for local development if credentials aren't provided yet
  admin.initializeApp({
    projectId
  });
  console.log('⚠️ Firebase Admin SDK initialized without private key (using default/fallback)');
}

const db = admin.firestore();
const auth = admin.auth();

module.exports = { admin, db, auth };
