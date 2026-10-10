/**
 * Static RAG knowledge base and basic cricket rules.
 * Does not require external LLM calls for direct matches.
 */

const KNOWLEDGE_BASE = [
  {
    category: 'app_guide',
    keywords: ['create', 'make', 'add', 'match'],
    title: 'How to create a match',
    content: 'To create a match in ScorePartner, go to your Profile, tap the "+" button or "Create Match", fill in the team names, select the number of overs and ground, and then tap "Start".'
  },
  {
    category: 'app_guide',
    keywords: ['create', 'make', 'add', 'team'],
    title: 'How to create a team',
    content: 'To create a team, go to Profile > My Teams > Create Team, and add your players.'
  },
  {
    category: 'app_guide',
    keywords: ['create', 'make', 'add', 'tournament', 'league'],
    title: 'How to create a tournament',
    content: 'To create a tournament, go to Profile > My Tournaments > Create Tournament. Set the format, teams, and fixtures.'
  },
  {
    category: 'app_guide',
    keywords: ['start', 'scoring', 'score', 'match'],
    title: 'How to start scoring',
    content: 'Open the match details, tap "Start Scoring", select the opening batsmen and bowler, and you can start scoring ball by ball.'
  },
  {
    category: 'app_guide',
    keywords: ['live', 'broadcast', 'stream'],
    title: 'How to go live (broadcast)',
    content: 'Open the match, tap "Go Live". This will start your camera broadcast with a live score overlay.'
  },
  {
    category: 'app_guide',
    keywords: ['share', 'match', 'link'],
    title: 'How to share a match',
    content: 'Open the match details and tap the Share icon at the top right to share the match link.'
  },
  {
    category: 'app_guide',
    keywords: ['points table', 'standings'],
    title: 'How points tables work',
    content: 'Points tables are automatically calculated for tournaments. Open a tournament and go to the "Points Table" tab.'
  },
  {
    category: 'cricket',
    keywords: ['lbw', 'leg before wicket'],
    title: 'What is LBW?',
    content: 'LBW (Leg Before Wicket) is a way a batsman can be dismissed in cricket. It happens if the ball hits the batsman\'s body (usually the pad) without hitting the bat first, and the umpire judges that the ball would have gone on to hit the stumps.'
  },
  {
    category: 'cricket',
    keywords: ['drs', 'review'],
    title: 'What is DRS?',
    content: 'DRS (Decision Review System) is a technology-based system used in cricket to assist the on-field umpires with their decision-making. Teams can use it to challenge an umpire\'s decision.'
  },
  {
    category: 'cricket',
    keywords: ['dls', 'duckworth', 'lewis', 'stern', 'rain'],
    title: 'What is DLS?',
    content: 'The Duckworth-Lewis-Stern (DLS) method is a mathematical formulation designed to calculate the target score for the team batting second in a limited-overs cricket match interrupted by weather or other circumstances.'
  },
  {
    category: 'cricket',
    keywords: ['no-ball', 'no ball'],
    title: 'What is a No-ball?',
    content: 'A no-ball is an illegal delivery (usually for overstepping the popping crease, bowling above waist height, or incorrect fielding restrictions). It adds 1 run to the batting team\'s total and requires the bowler to bowl another delivery. In many formats, it is followed by a Free Hit.'
  },
  {
    category: 'cricket',
    keywords: ['wide', 'wide ball'],
    title: 'What is a Wide?',
    content: 'A wide is an illegal delivery that is deemed too wide or too high for the batsman to hit in a normal stance. It adds 1 run to the batting team and the bowler must bowl an extra delivery.'
  },
  {
    category: 'cricket',
    keywords: ['free hit'],
    title: 'What is a Free Hit?',
    content: 'A free hit is given to the batting team after a bowler bowls a no-ball. On a free hit, the batsman cannot be dismissed by normal means like bowled, caught, or lbw, but can still be run out.'
  },
  {
    category: 'cricket',
    keywords: ['powerplay'],
    title: 'What is a Powerplay?',
    content: 'A Powerplay is a set of overs in limited-overs cricket where fielding restrictions are placed on the bowling team, usually allowing only a few fielders outside the 30-yard circle to encourage attacking batting.'
  },
  {
    category: 'cricket',
    keywords: ['super over'],
    title: 'What is a Super Over?',
    content: 'A Super Over is a one-over-per-side tiebreaker used to determine the winner of a limited-overs match that ends in a tie. Each team bats for one over, and the team scoring the most runs wins.'
  },
  {
    category: 'cricket',
    keywords: ['nrr', 'net run rate'],
    title: 'What is Net Run Rate (NRR)?',
    content: 'Net Run Rate is a statistical method used in analyzing teamwork and performance in limited-overs cricket. It is calculated by subtracting the team\'s run rate conceded from their run rate scored.'
  },
  {
    category: 'cricket',
    keywords: ['maiden', 'maiden over'],
    title: 'What is a Maiden Over?',
    content: 'A maiden over is an over in which no runs are scored off the bat and no wides or no-balls are bowled.'
  },
  {
    category: 'cricket',
    keywords: ['six', 'six runs'],
    title: 'What is a Six?',
    content: 'A six is scored when the batsman hits the ball over the boundary rope without it bouncing first.'
  },
  {
    category: 'cricket',
    keywords: ['boundary', 'four'],
    title: 'What is a Boundary?',
    content: 'A boundary usually refers to a four, scored when the ball reaches or crosses the boundary rope after touching the ground. A six is also a boundary.'
  }
];

function retrieveAnswer(message) {
  if (!message) return null;
  const lowerMsg = message.toLowerCase();

  // Basic word matching scoring
  let bestMatch = null;
  let highestScore = 0;

  for (const doc of KNOWLEDGE_BASE) {
    let score = 0;
    
    // Check keyword hits
    for (const kw of doc.keywords) {
      if (lowerMsg.includes(kw.toLowerCase())) {
        score += kw.length; // Longer keywords are worth more points
      }
    }

    if (score > highestScore) {
      highestScore = score;
      bestMatch = doc;
    }
  }

  // Threshold to ensure it's a decent match
  if (bestMatch && highestScore >= 3) {
    return bestMatch.content;
  }

  return null;
}

module.exports = { retrieveAnswer };
