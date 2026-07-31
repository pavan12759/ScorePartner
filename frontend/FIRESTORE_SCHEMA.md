# ScorePartner Firestore Database Schema

## Collection Structure

### Users Collection
```
users/{userId}
{
  uid: string,
  phoneNumber: string,
  name: string,
  role: string, // "batsman", "bowler", "all-rounder", "wicket-keeper"
  battingStyle: string, // "right-hand", "left-hand"
  bowlingStyle: string, // "fast", "medium", "spin"
  age: number,
  location: string,
  profileImageUrl: string,
  instagramUrl: string,
  isVerified: boolean,
  createdAt: timestamp,
  lastActiveAt: timestamp,
  
  // Stats separated by ball type
  tennisBallStats: {
    matches: number,
    runs: number,
    wickets: number,
    strikeRate: number,
    economy: number,
    bestScore: number,
    bestBowling: string,
    manOfMatches: number,
    tournamentWins: number
  },
  leatherBallStats: {
    matches: number,
    runs: number,
    wickets: number,
    strikeRate: number,
    economy: number,
    bestScore: number,
    bestBowling: string,
    manOfMatches: number,
    tournamentWins: number
  }
}
```

### Matches Collection
```
matches/{matchId}
{
  matchName: string,
  tournamentId: string, // optional
  team1Id: string,
  team2Id: string,
  team1Name: string,
  team2Name: string,
  ground: string,
  location: string,
  matchType: string, // "tennis-ball", "leather-ball"
  oversPerSide: number,
  scheduledDate: timestamp,
  status: string, // "scheduled", "live", "completed", "abandoned"
  
  // Live match data
  currentInnings: number,
  currentBattingTeam: string,
  bowlingTeam: string,
  currentOver: number,
  currentBall: number,
  team1Score: {
    runs: number,
    wickets: number,
    overs: number
  },
  team2Score: {
    runs: number,
    wickets: number,
    overs: number
  },
  
  // Scoring details
  ballByBall: [
    {
      ballNumber: number,
      overNumber: number,
      battingTeam: string,
      bowlerId: string,
      batsmanId: string,
      runs: number,
      extras: string, // "wide", "no-ball", "bye", "leg-bye"
      wicket: {
        type: string, // "bowled", "caught", "run-out", etc.
        playerId: string,
        fielderId: string
      },
      commentary: string,
      timestamp: timestamp
    }
  ],
  
  result: {
    winner: string,
    margin: string,
    manOfMatch: string
  },
  
  createdBy: string,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### Tournaments Collection
```
tournaments/{tournamentId}
{
  name: string,
  description: string,
  organizerId: string,
  matchType: string, // "tennis-ball", "leather-ball"
  tournamentType: string, // "league", "knockout"
  oversPerMatch: number,
  maxTeams: number,
  entryFee: number,
  prizePool: number,
  startDate: timestamp,
  endDate: timestamp,
  status: string, // "upcoming", "ongoing", "completed"
  
  // League specific
  pointsTable: [
    {
      teamId: string,
      teamName: string,
      matches: number,
      wins: number,
      losses: number,
      ties: number,
      points: number,
      netRunRate: number
    }
  ],
  
  // Fixtures
  fixtures: [
    {
      matchId: string,
      round: string,
      date: timestamp,
      team1Id: string,
      team2Id: string
    }
  ],
  
  logoUrl: string,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### Teams Collection
```
teams/{teamId}
{
  name: string,
  logoUrl: string,
  captainId: string,
  location: string,
  players: [
    {
      playerId: string,
      playerName: string,
      role: string,
      jerseyNumber: number
    }
  ],
  stats: {
    matches: number,
    wins: number,
    losses: number,
    ties: number
  },
  createdBy: string,
  createdAt: timestamp
}
```

### Reels Collection
```
reels/{reelId}
{
  playerId: string,
  videoUrl: string,
  thumbnailUrl: string,
  caption: string,
  tags: [string], // ["six", "wicket", "celebration"]
  matchId: string, // optional
  views: number,
  likes: number,
  comments: [
    {
      userId: string,
      userName: string,
      comment: string,
      timestamp: timestamp
    }
  ],
  isPublic: boolean,
  createdAt: timestamp
}
```

### News Collection (Auto-generated)
```
news/{newsId}
{
  headline: string,
  content: string,
  type: string, // "match-result", "performance", "tournament"
  relatedMatchId: string, // optional
  relatedPlayerId: string, // optional
  imageUrl: string, // optional
  priority: number, // 1-10 for sorting
  createdAt: timestamp,
  expiresAt: timestamp
}
```

### Notifications Collection
```
notifications/{notificationId}
{
  userId: string,
  title: string,
  body: string,
  type: string, // "match-invite", "match-start", "tournament-update"
  data: {
    matchId: string, // optional
    tournamentId: string // optional
  },
  isRead: boolean,
  createdAt: timestamp
}
```

## Indexes Required

### Matches Collection
- `scheduledDate` (ascending) - for upcoming matches
- `status` (where status == "live") - for live matches
- `createdBy` (where createdBy == userId) - for user's matches
- `tournamentId` (where tournamentId == tournamentId) - for tournament matches

### Reels Collection
- `playerId` (descending by createdAt) - for user's reels
- `createdAt` (descending) - for feed
- `likes` (descending) - for trending

### Users Collection
- `phoneNumber` (unique) - for authentication
- `location` (for nearby players)

## Security Rules

### Basic Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Anyone can read public data, only creators can write
    match /matches/{matchId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        request.auth.uid == resource.data.createdBy;
    }
    
    // Similar rules for other collections...
  }
}
```

## Data Flow Patterns

### Live Match Scoring
1. Create match document with status "scheduled"
2. Update status to "live" when match starts
3. Add ball-by-ball entries to `ballByBall` array
4. Update scores after each ball
5. Update result when match completes

### Tournament Management
1. Create tournament document
2. Add teams to tournament
3. Generate fixtures based on tournament type
4. Update points table after each match
5. Calculate standings automatically

### Reels Upload
1. Upload video to Firebase Storage
2. Create reel document with metadata
3. Update user's reel count
4. Add to trending algorithm based on engagement
