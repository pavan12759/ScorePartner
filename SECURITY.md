# ScorePartner Security Architecture

This document describes the security practices and configurations used in the ScorePartner project.

## 1. Secrets Management

### Backend
- The Node.js backend uses `dotenv` to load environment variables from `.env`.
- The `.env` file must **NEVER** be committed to version control.
- An `.env.example` file is provided as a template.
- **Firebase Admin Credentials**: `serviceAccountKey.json` files are **not** used or checked into source control. Instead, the credentials (Project ID, Client Email, Private Key) are passed securely via environment variables (`FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`).

### Frontend (Flutter)
- No server-side secrets (like Firebase Admin keys, JWT secrets, or DB passwords) are ever stored in the Flutter codebase.
- The `AGORA_APP_ID` is included since it is required for client-side initialization, but the `AGORA_APP_CERTIFICATE` remains strictly on the Node.js backend to generate secure RTC tokens.

## 2. API Security

- **Rate Limiting**: Authentication endpoints (`/api/auth/login` and `/api/auth/register`) are rate-limited using `express-rate-limit` to prevent brute-force and credential stuffing attacks.
- **Helmet**: The Express application uses `helmet` to set secure HTTP headers (e.g., XSS Protection, NoSniff, Frame Options).
- **Payload Limits**: JSON and URL-encoded request payloads are strictly limited to `1mb` to mitigate Denial of Service (DoS) attacks via oversized requests.
- **CORS**: Cross-Origin Resource Sharing is enabled but should be configured to specific domains in a production environment.

## 3. Firebase Security Rules (Firestore)

Our `firestore.rules` enforces the following security boundaries:

- **Users**: Users can only update their own profiles. Critical statistics (e.g., `tennisBallStats`, `leatherBallStats`, `achievements`) cannot be updated by any client directly. These fields are exclusively managed by the secure Node.js backend.
- **Teams**: Only the team creator or designated `adminIds` can modify or delete a team.
- **Matches & Tournaments**: Only the creator or authorized admins can update match and tournament data. View counts and other metrics are protected from client-side manipulation.
- **Reels & Chats**: Users can only modify or delete their own chat messages and reels.

## 4. Role Validations

Role validation (e.g., Match Admin, Scorer, Tournament Admin, Team Admin) is verified using Firebase Authentication tokens and trusted backend data rather than trusting client-side assertions.

## 5. Security Updates

Before applying major-version dependency upgrades, always evaluate potential breaking changes. Run `npm audit` periodically to identify and resolve vulnerabilities.
