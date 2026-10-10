/**
 * ScorePartner AI Tools — Controlled data access functions
 * These are the ONLY ways the AI can access ScorePartner data.
 * Each tool validates inputs and enforces authorization.
 */

const { db } = require('../../config/firebase');

// ==================== Tool Definitions (for Gemini function calling) ====================

const toolDefinitions = [
  {
    name: 'searchMatches',
    description: 'Search for cricket matches in ScorePartner by team names, match name, or status. Use this when the user asks about matches, scores, or results.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Search term (team name, match name)' },
        status: { type: 'string', enum: ['live', 'upcoming', 'completed', 'all'], description: 'Filter by match status' },
        limit: { type: 'number', description: 'Max results to return (default 5)' },
      },
      required: ['query'],
    },
  },
  {
    name: 'searchPlayers',
    description: 'Search for players/users in ScorePartner by name. Use this when the user asks about a player, cricketer, or user in ScorePartner.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Player name to search for' },
        limit: { type: 'number', description: 'Max results (default 5)' },
      },
      required: ['query'],
    },
  },
  {
    name: 'searchTeams',
    description: 'Search for cricket teams in ScorePartner by team name. Use this when the user asks about a team.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Team name to search for' },
        limit: { type: 'number', description: 'Max results (default 5)' },
      },
      required: ['query'],
    },
  },
  {
    name: 'searchTournaments',
    description: 'Search for tournaments in ScorePartner by name. Use this when the user asks about a tournament, league, or cup.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Tournament name to search for' },
        status: { type: 'string', enum: ['upcoming', 'ongoing', 'completed', 'all'], description: 'Filter by status' },
        limit: { type: 'number', description: 'Max results (default 5)' },
      },
      required: ['query'],
    },
  },
  {
    name: 'getMatchById',
    description: 'Get detailed information about a specific match by its ID.',
    parameters: {
      type: 'object',
      properties: {
        matchId: { type: 'string', description: 'The match document ID' },
      },
      required: ['matchId'],
    },
  },
  {
    name: 'getPlayerById',
    description: 'Get detailed player profile and statistics by player/user ID.',
    parameters: {
      type: 'object',
      properties: {
        playerId: { type: 'string', description: 'The player/user document ID' },
      },
      required: ['playerId'],
    },
  },
  {
    name: 'getTeamById',
    description: 'Get team details including players, record, and stats.',
    parameters: {
      type: 'object',
      properties: {
        teamId: { type: 'string', description: 'The team document ID' },
      },
      required: ['teamId'],
    },
  },
  {
    name: 'getTournamentById',
    description: 'Get tournament details including teams, matches, standings.',
    parameters: {
      type: 'object',
      properties: {
        tournamentId: { type: 'string', description: 'The tournament document ID' },
      },
      required: ['tournamentId'],
    },
  },
  {
    name: 'getUserMatches',
    description: 'Get matches created by or involving the authenticated user. Use when user asks about "my matches".',
    parameters: {
      type: 'object',
      properties: {
        limit: { type: 'number', description: 'Max results (default 10)' },
      },
    },
  },
  {
    name: 'getUserPlayedMatches',
    description: 'Get matches where the authenticated user played. Use when user asks about "my played matches".',
    parameters: {
      type: 'object',
      properties: {
        limit: { type: 'number', description: 'Max results (default 10)' },
      },
    },
  },
  {
    name: 'getUserTeams',
    description: 'Get teams where the authenticated user is a member. Use when user asks about "my teams".',
    parameters: {
      type: 'object',
      properties: {
        limit: { type: 'number', description: 'Max results (default 10)' },
      },
    },
  },
  {
    name: 'getUserTournaments',
    description: 'Get tournaments organized by or involving the authenticated user. Use when user asks about "my tournaments".',
    parameters: {
      type: 'object',
      properties: {
        limit: { type: 'number', description: 'Max results (default 10)' },
      },
    },
  },
  {
    name: 'getTournamentMatches',
    description: 'Get all matches in a specific tournament.',
    parameters: {
      type: 'object',
      properties: {
        tournamentId: { type: 'string', description: 'The tournament ID' },
        limit: { type: 'number', description: 'Max results (default 20)' },
      },
      required: ['tournamentId'],
    },
  },
  {
    name: 'getCricketNews',
    description: 'Get current cricket news headlines. Use when the user asks about cricket news, ICC news, or latest updates.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Optional search query (e.g., "ICC", "IPL", "India cricket")' },
        limit: { type: 'number', description: 'Max articles (default 5)' },
      },
    },
  },
];

// ==================== Tool Implementations ====================

/**
 * Sanitize match data for AI consumption — strip unnecessary large fields
 */
function sanitizeMatch(match) {
  return {
    id: match.id,
    matchName: match.matchName || `${match.team1Name || 'Team 1'} vs ${match.team2Name || 'Team 2'}`,
    team1Name: match.team1Name || '',
    team2Name: match.team2Name || '',
    team1Id: match.team1Id || '',
    team2Id: match.team2Id || '',
    team1Score: match.team1Score ? {
      runs: match.team1Score.runs || 0,
      wickets: match.team1Score.wickets || 0,
      overs: match.team1Score.overs || 0,
    } : { runs: 0, wickets: 0, overs: 0 },
    team2Score: match.team2Score ? {
      runs: match.team2Score.runs || 0,
      wickets: match.team2Score.wickets || 0,
      overs: match.team2Score.overs || 0,
    } : { runs: 0, wickets: 0, overs: 0 },
    status: match.status || 'upcoming',
    result: match.result || null,
    matchType: match.matchType || '',
    oversPerSide: match.oversPerSide || 0,
    ground: match.ground || '',
    location: match.location || '',
    tournamentId: match.tournamentId || '',
    tournamentName: match.tournamentName || '',
    scheduledDate: match.scheduledDate || match.matchDate || null,
  };
}

function sanitizePlayer(user) {
  return {
    id: user.uid || user.id,
    name: user.name || '',
    spPId: user.spPId || '',
    role: user.role || '',
    battingStyle: user.battingStyle || '',
    bowlingStyle: user.bowlingStyle || '',
    location: user.location || '',
    profileImageUrl: user.profileImageUrl || '',
    isVerified: user.isVerified || false,
    tennisBallStats: user.tennisBallStats ? {
      matchesPlayed: user.tennisBallStats.matchesPlayed || 0,
      totalRuns: user.tennisBallStats.totalRuns || 0,
      totalWickets: user.tennisBallStats.totalWickets || 0,
      highestScore: user.tennisBallStats.highestScore || 0,
      bestBowling: user.tennisBallStats.bestBowling || '',
    } : null,
    leatherBallStats: user.leatherBallStats ? {
      matchesPlayed: user.leatherBallStats.matchesPlayed || 0,
      totalRuns: user.leatherBallStats.totalRuns || 0,
      totalWickets: user.leatherBallStats.totalWickets || 0,
      highestScore: user.leatherBallStats.highestScore || 0,
      bestBowling: user.leatherBallStats.bestBowling || '',
    } : null,
    stars: user.stars || 0,
    rankTitle: user.rankTitle || '',
  };
}

function sanitizeTeam(team) {
  return {
    id: team.id,
    name: team.name || '',
    spTId: team.spTId || '',
    captainName: team.captainName || '',
    logoUrl: team.logoUrl || '',
    playerCount: Array.isArray(team.players) ? team.players.length : 0,
    players: Array.isArray(team.players) ? team.players.slice(0, 15).map(p => ({
      name: p.name || '',
      role: p.role || '',
      id: p.id || p.userId || '',
    })) : [],
    matchesPlayed: team.matchesPlayed || 0,
    matchesWon: team.matchesWon || 0,
    matchesLost: team.matchesLost || 0,
  };
}

function sanitizeTournament(tournament) {
  return {
    id: tournament.id,
    name: tournament.name || '',
    description: tournament.description || '',
    organizerName: tournament.organizerName || '',
    location: tournament.location || '',
    startDate: tournament.startDate || null,
    endDate: tournament.endDate || null,
    status: tournament.status || 'upcoming',
    format: tournament.format || '',
    overs: tournament.overs || 0,
    ballType: tournament.ballType || '',
    maxTeams: tournament.maxTeams || 0,
    registeredTeamCount: Array.isArray(tournament.registeredTeamIds) ? tournament.registeredTeamIds.length : 0,
    matchCount: Array.isArray(tournament.matchIds) ? tournament.matchIds.length : 0,
    category: tournament.category || '',
    logoUrl: tournament.logoUrl || '',
  };
}

// ==================== Tool Executor ====================

async function executeTool(toolName, args, userId) {
  const limit = Math.min(parseInt(args.limit) || 5, 20); // Cap at 20

  switch (toolName) {
    case 'searchMatches': {
      const query = (args.query || '').trim().toLowerCase();
      const status = args.status || 'all';

      let ref = db.collection('matches');
      if (status && status !== 'all') {
        ref = ref.where('status', '==', status);
      }

      const snapshot = await ref.orderBy('matchDate', 'desc').limit(50).get();
      let matches = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

      // Client-side text filter (Firestore doesn't support full-text search)
      if (query) {
        matches = matches.filter(m => {
          const searchable = [
            m.matchName, m.team1Name, m.team2Name,
            m.ground, m.location, m.tournamentName,
          ].filter(Boolean).join(' ').toLowerCase();
          return searchable.includes(query);
        });
      }

      return {
        found: matches.length,
        matches: matches.slice(0, limit).map(sanitizeMatch),
      };
    }

    case 'searchPlayers': {
      const query = (args.query || '').trim();
      if (!query) return { found: 0, players: [] };

      // Search by name prefix (case-insensitive via multiple queries)
      const variants = [
        query.charAt(0).toUpperCase() + query.slice(1).toLowerCase(),
        query.toLowerCase(),
        query.toUpperCase(),
        query,
      ];

      const results = new Map();
      for (const variant of variants) {
        const snap = await db.collection('users')
          .orderBy('name')
          .startAt(variant)
          .endAt(variant + '\uf8ff')
          .limit(limit)
          .get();
        snap.docs.forEach(doc => {
          if (!results.has(doc.id)) {
            results.set(doc.id, { uid: doc.id, ...doc.data() });
          }
        });
      }

      const players = Array.from(results.values()).slice(0, limit);
      return {
        found: players.length,
        players: players.map(sanitizePlayer),
      };
    }

    case 'searchTeams': {
      const query = (args.query || '').trim().toLowerCase();
      if (!query) return { found: 0, teams: [] };

      const snapshot = await db.collection('teams').limit(100).get();
      let teams = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

      teams = teams.filter(t => {
        const name = (t.name || '').toLowerCase();
        return name.includes(query);
      });

      return {
        found: teams.length,
        teams: teams.slice(0, limit).map(sanitizeTeam),
      };
    }

    case 'searchTournaments': {
      const query = (args.query || '').trim().toLowerCase();
      const status = args.status || 'all';

      let ref = db.collection('tournaments');
      if (status && status !== 'all') {
        ref = ref.where('status', '==', status);
      }

      const snapshot = await ref.orderBy('startDate', 'desc').limit(50).get();
      let tournaments = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

      if (query) {
        tournaments = tournaments.filter(t => {
          const searchable = [t.name, t.location, t.organizerName, t.description]
            .filter(Boolean).join(' ').toLowerCase();
          return searchable.includes(query);
        });
      }

      return {
        found: tournaments.length,
        tournaments: tournaments.slice(0, limit).map(sanitizeTournament),
      };
    }

    case 'getMatchById': {
      const matchId = (args.matchId || '').trim();
      if (!matchId) return { error: 'Match ID required' };

      const doc = await db.collection('matches').doc(matchId).get();
      if (!doc.exists) return { error: 'Match not found' };

      return { match: sanitizeMatch({ id: doc.id, ...doc.data() }) };
    }

    case 'getPlayerById': {
      const playerId = (args.playerId || '').trim();
      if (!playerId) return { error: 'Player ID required' };

      const doc = await db.collection('users').doc(playerId).get();
      if (!doc.exists) return { error: 'Player not found' };

      return { player: sanitizePlayer({ uid: doc.id, ...doc.data() }) };
    }

    case 'getTeamById': {
      const teamId = (args.teamId || '').trim();
      if (!teamId) return { error: 'Team ID required' };

      const doc = await db.collection('teams').doc(teamId).get();
      if (!doc.exists) return { error: 'Team not found' };

      return { team: sanitizeTeam({ id: doc.id, ...doc.data() }) };
    }

    case 'getTournamentById': {
      const tournamentId = (args.tournamentId || '').trim();
      if (!tournamentId) return { error: 'Tournament ID required' };

      const doc = await db.collection('tournaments').doc(tournamentId).get();
      if (!doc.exists) return { error: 'Tournament not found' };

      return { tournament: sanitizeTournament({ id: doc.id, ...doc.data() }) };
    }

    case 'getUserMatches': {
      if (!userId) return { error: 'Authentication required to view your matches' };

      const snapshot = await db.collection('matches')
        .where('createdBy', '==', userId)
        .orderBy('matchDate', 'desc')
        .limit(limit)
        .get();

      const matches = snapshot.docs.map(doc => sanitizeMatch({ id: doc.id, ...doc.data() }));
      return { found: matches.length, matches };
    }

    case 'getUserPlayedMatches': {
      if (!userId) return { error: 'Authentication required to view your played matches' };

      const [snap1, snap2] = await Promise.all([
        db.collection('matches').where('player1Id', '==', userId).orderBy('matchDate', 'desc').limit(limit).get(),
        db.collection('matches').where('player2Id', '==', userId).orderBy('matchDate', 'desc').limit(limit).get(),
      ]);

      const allMatches = [... snap1.docs, ... snap2.docs];
      const seen = new Set();
      const matches = allMatches.filter(doc => {
        const id = doc.id;
        if (seen.has(id)) return false;
        seen.add(id);
        return true;
      }).map(doc => sanitizeMatch({ id: doc.id, ...doc.data() }));

      return { found: matches.length, matches };
    }

    case 'getUserTeams': {
      if (!userId) return { error: 'Authentication required to view your teams' };

      // Search teams where user is captain or player
      const snapshot = await db.collection('teams').limit(100).get();
      let teams = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

      teams = teams.filter(t => {
        if (t.captainId === userId || t.creatorId === userId) return true;
        if (Array.isArray(t.players)) {
          return t.players.some(p => (p.userId || p.id) === userId);
        }
        return false;
      });

      return {
        found: teams.length,
        teams: teams.slice(0, limit).map(sanitizeTeam),
      };
    }

    case 'getUserTournaments': {
      if (!userId) return { error: 'Authentication required to view your tournaments' };

      const snapshot = await db.collection('tournaments')
        .where('organizerId', '==', userId)
        .orderBy('startDate', 'desc')
        .limit(limit)
        .get();

      const tournaments = snapshot.docs.map(doc => sanitizeTournament({ id: doc.id, ...doc.data() }));
      return { found: tournaments.length, tournaments };
    }

    case 'getTournamentMatches': {
      const tournamentId = (args.tournamentId || '').trim();
      if (!tournamentId) return { error: 'Tournament ID required' };

      const snapshot = await db.collection('matches')
        .where('tournamentId', '==', tournamentId)
        .orderBy('matchDate', 'desc')
        .limit(limit)
        .get();

      const matches = snapshot.docs.map(doc => sanitizeMatch({ id: doc.id, ...doc.data() }));
      return { found: matches.length, matches };
    }

    case 'getCricketNews': {
      // Delegate to news service
      const newsService = require('./newsService');
      const articles = await newsService.getNews(args.query || 'cricket', limit);
      return { found: articles.length, articles };
    }

    default:
      return { error: `Unknown tool: ${toolName}` };
  }
}

module.exports = { toolDefinitions, executeTool };
