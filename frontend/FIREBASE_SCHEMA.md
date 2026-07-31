# Firebase Firestore Database Schema

## 📊 Collections Structure

### 1. users Collection
```dart
{
  "uid": "string",                    // Firebase Auth UID
  "phoneNumber": "string",             // +919876543210
  "name": "string",                    // Player Name
  "role": "string",                    // batsman/bowler/all-rounder/wicket-keeper
  "battingStyle": "string",            // right-hand/left-hand
  "bowlingStyle": "string",            // fast/medium/spin
  "age": "number",                     // 18-50
  "location": "string",                // City/Area
  "profileImageUrl": "string",         // Firebase Storage URL
  "instagramUrl": "string",            // Optional
  "isVerified": "boolean",             // Phone verified
  "createdAt": "Timestamp",
  "lastActiveAt": "Timestamp",
  "tennisBallStats": {
    "matches": "number",
    "runs": "number",
    "wickets": "number",
    "strikeRate": "number",
    "economy": "number",
    "bestScore": "number",
    "bestBowling": "string",           // "3/15"
    "manOfMatches": "number",
    "tournamentWins": "number"
  },
  "leatherBallStats": {
    "matches": "number",
    "runs": "number",
    "wickets": "number",
    "strikeRate": "number",
    "economy": "number",
    "bestScore": "number",
    "bestBowling": "string",
    "manOfMatches": "number",
    "tournamentWins": "number"
  }
}
```

### 2. matches Collection
```dart
{
  "id": "string",                      // Auto-generated
  "matchName": "string",               // "T20 Championship Final"
  "tournamentId": "string",            // Reference to tournament (optional)
  "team1Id": "string",                 // Reference to team/user
  "team2Id": "string",                 // Reference to team/user
  "team1Name": "string",               // "Street Kings"
  "team2Name": "string",               // "Warriors"
  "team1Players": ["string"],         // Array of user IDs
  "team2Players": ["string"],         // Array of user IDs
  "ground": "string",                  // "Mahbubnagar Stadium"
  "location": "string",                // City/Area
  "matchType": "string",               // "tennis-ball"/"leather-ball"
  "oversPerSide": "number",           // 20/10/5
  "scheduledDate": "Timestamp",
  "status": "string",                  // "scheduled"/"live"/"completed"/"abandoned"
  "currentInnings": "number",          // 1 or 2
  "currentBattingTeam": "string",      // "team1"/"team2"
  "currentOver": "number",            // 0-19
  "currentBall": "number",            // 1-6
  "team1Score": {
    "runs": "number",
    "wickets": "number",
    "overs": "number"
  },
  "team2Score": {
    "runs": "number",
    "wickets": "number", 
    "overs": "number"
  },
  "ballByBall": [
    {
      "ballNumber": "number",
      "overNumber": "number",
      "battingTeam": "string",
      "bowlerId": "string",
      "batsmanId": "string",
      "runs": "number",
      "extras": "string",              // "wide"/"no-ball"/"bye"/"leg-bye"
      "wicket": {
        "type": "string",              // "bowled"/"caught"/"lbw"/"run-out"
        "playerId": "string",          // Out player
        "fielderId": "string"         // Optional (for catches)
      },
      "commentary": "string",
      "timestamp": "Timestamp"
    }
  ],
  "result": {                           // Only for completed matches
    "winner": "string",                 // "team1"/"team2"
    "margin": "string",                 // "5 wickets"/"23 runs"
    "manOfMatch": "string"             // User ID
  },
  "createdBy": "string",               // User ID who created match
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### 3. tournaments Collection
```dart
{
  "id": "string",
  "name": "string",                    // "Mahbubnagar Premier League"
  "description": "string",
  "organizerId": "string",             // User ID
  "matchType": "string",               // "tennis-ball"/"leather-ball"
  "format": "string",                   // "league"/"knockout"/"double-league"
  "oversPerMatch": "number",           // 20/10/5
  "maxTeams": "number",                // 8/16/32
  "startDate": "Timestamp",
  "endDate": "Timestamp",
  "location": "string",                // City/Area
  "status": "string",                  // "upcoming"/"ongoing"/"completed"
  "teams": [
    {
      "id": "string",                  // Team ID
      "name": "string",                // Team Name
      "captainId": "string",           // User ID
      "players": ["string"]           // Array of user IDs
    }
  ],
  "fixtures": [
    {
      "matchId": "string",             // Reference to match
      "team1Id": "string",
      "team2Id": "string",
      "round": "string",                // "group-stage"/"semi-final"/"final"
      "matchNumber": "number",
      "scheduledDate": "Timestamp"
    }
  ],
  "pointsTable": [
    {
      "teamId": "string",
      "played": "number",
      "won": "number",
      "lost": "number",
      "tied": "number",
      "points": "number",
      "nrr": "number"                   // Net Run Rate
    }
  ],
  "prize": "string",                    // Optional prize info
  "rules": "string",                    // Tournament rules
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### 4. reels Collection
```dart
{
  "id": "string",
  "userId": "string",                   // Who uploaded
  "videoUrl": "string",                 // Firebase Storage URL
  "thumbnailUrl": "string",             // Thumbnail image URL
  "caption": "string",                  // Optional caption
  "tags": ["string"],                   // ["six", "wicket", "catch"]
  "matchId": "string",                  // Optional: linked match
  "playerIds": ["string"],              // Players featured in video
  "duration": "number",                 // Seconds
  "views": "number",
  "likes": ["string"],                  // Array of user IDs who liked
  "comments": [
    {
      "id": "string",
      "userId": "string",
      "comment": "string",
      "timestamp": "Timestamp"
    }
  ],
  "isPublic": "boolean",
  "isVerified": "boolean",              // Verified by admin
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### 5. news Collection
```dart
{
  "id": "string",
  "title": "string",                    // "Pavan scored 78 (42) in Mahbubnagar league"
  "content": "string",                  // Full news content
  "type": "string",                     // "match-summary"/"achievement"/"tournament"
  "matchId": "string",                  // Related match (if applicable)
  "playerIds": ["string"],              // Featured players
  "tournamentId": "string",             // Related tournament (if applicable)
  "imageUrl": "string",                 // Optional image
  "priority": "number",                 // 1-10 (for sorting)
  "isTrending": "boolean",
  "viewCount": "number",
  "createdAt": "Timestamp",
  "generatedBy": "string"               // "auto"/"manual"
}
```

### 6. notifications Collection
```dart
{
  "id": "string",
  "userId": "string",                   // Target user
  "title": "string",
  "body": "string",
  "type": "string",                     // "match"/"tournament"/"reel"/"achievement"
  "data": "Map<String, dynamic>",       // Additional data
  "isRead": "boolean",
  "createdAt": "Timestamp"
}
```

## 🔗 Indexes for Performance

### matches Collection Indexes
- `status` + `scheduledDate` (for live/upcoming matches)
- `createdBy` + `createdAt` (for user's matches)
- `tournamentId` + `status` (for tournament matches)

### users Collection Indexes
- `location` + `lastActiveAt` (for nearby players)
- `phoneNumber` (unique)

### reels Collection Indexes
- `createdAt` (for feed sorting)
- `userId` + `createdAt` (for user's reels)
- `isPublic` + `createdAt` (for public reels)

## 🔐 Security Rules

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Anyone can read public data, only creators can write
    match /matches/{matchId} {
      allow read: if true;
      allow write: if request.auth != null && 
        request.auth.uid == resource.data.createdBy;
    }
    
    // Reels are public to read, only uploaders can write
    match /reels/{reelId} {
      allow read: if resource.data.isPublic == true;
      allow write: if request.auth != null && 
        request.auth.uid == resource.data.userId;
    }
    
    // Tournament rules
    match /tournaments/{tournamentId} {
      allow read: if true;
      allow write: if request.auth != null && 
        request.auth.uid == resource.data.organizerId;
    }
  }
}
```

## 📈 Data Scaling Considerations

1. **Match Data**: Use subcollections for ball-by-ball data to avoid document size limits
2. **User Activity**: Separate collections for different activity types
3. **Analytics**: Consider BigQuery for large-scale analytics
4. **CDN**: Use Firebase Hosting with CDN for static assets
