const socket = io(); // Connects to the backend Socket.io

// Parse URL to get match ID and theme
const urlParams = new URLSearchParams(window.location.search);
const pathSegments = window.location.pathname.split('/');
// Expected URL: /live/:matchId/overlay
const matchId = pathSegments[2]; 
const theme = urlParams.get('theme') || 'classic';

// Apply theme
document.body.className = `theme-${theme}`;

if (matchId) {
    socket.emit('join-match', matchId);
    console.log(`Joined match room: ${matchId}`);
} else {
    console.error("No match ID found in URL");
    document.getElementById('match-status-badge').innerText = 'ERROR: NO MATCH ID';
}

// Utility: animate value change
function animateValue(id, newValue) {
    const el = document.getElementById(id);
    if (!el) return;
    if (el.innerText != newValue) {
        el.innerText = newValue;
        el.classList.remove('value-changed');
        void el.offsetWidth; // trigger reflow
        el.classList.add('value-changed');
    }
}

// Map score data to UI
function updateUI(matchData) {
    if (!matchData) return;

    // Determine who is batting
    const isTeam1Batting = matchData.currentBattingTeam === 'team1';
    
    // Setup Team Names
    animateValue('team1-name', matchData.team1Name || 'TEAM A');
    animateValue('team2-name', matchData.team2Name || 'TEAM B');

    // Score logic
    const t1Score = matchData.team1Score || {};
    const t2Score = matchData.team2Score || {};

    animateValue('team1-runs', t1Score.runs || 0);
    animateValue('team1-wickets', t1Score.wickets || 0);
    animateValue('team1-overs', `(${(t1Score.overs || 0).toFixed(1)})`);

    animateValue('team2-runs', t2Score.runs || 0);
    animateValue('team2-wickets', t2Score.wickets || 0);
    animateValue('team2-overs', `(${(t2Score.overs || 0).toFixed(1)})`);

    // Dim inactive team
    if (isTeam1Batting) {
        document.getElementById('team1-block').classList.remove('inactive');
        document.getElementById('team2-block').classList.add('inactive');
    } else {
        document.getElementById('team2-block').classList.remove('inactive');
        document.getElementById('team1-block').classList.add('inactive');
    }

    // Match Status Badge
    const badge = document.getElementById('match-status-badge');
    if (matchData.status === 'completed') {
        badge.innerText = 'MATCH COMPLETE';
        badge.style.animation = 'none';
        badge.style.background = 'var(--success)';
    } else {
        badge.innerText = 'LIVE';
        badge.style.animation = 'pulse 2s infinite';
        badge.style.background = 'var(--danger)';
    }

    // Current Batting Team Score object to extract batters
    const currentScore = isTeam1Batting ? t1Score : t2Score;
    const bowlingScore = isTeam1Batting ? t2Score : t1Score;

    // Batters
    const strikerId = matchData.currentStrikerId;
    const nonStrikerId = matchData.currentNonStrikerId;
    const batters = currentScore.batters || [];
    
    const striker = batters.find(b => b.playerId === strikerId) || {};
    const nonStriker = batters.find(b => b.playerId === nonStrikerId) || {};

    animateValue('striker-name', (striker.playerName || 'Batsman 1') + ' *');
    animateValue('striker-runs', striker.runs || 0);
    animateValue('striker-balls', striker.balls || 0);

    animateValue('nonstriker-name', nonStriker.playerName || 'Batsman 2');
    animateValue('nonstriker-runs', nonStriker.runs || 0);
    animateValue('nonstriker-balls', nonStriker.balls || 0);

    // Bowler
    const bowlerId = matchData.currentBowlerId;
    const bowlers = bowlingScore.bowlers || [];
    const bowler = bowlers.find(b => b.playerId === bowlerId) || {};

    animateValue('bowler-name', bowler.playerName || 'Bowler');
    animateValue('bowler-wickets', bowler.wickets || 0);
    animateValue('bowler-runs', bowler.runs || 0);
    const bOvers = `${bowler.overs || 0}.${bowler.balls || 0}`;
    animateValue('bowler-overs', bOvers);

    // Match Context (Target, Innings)
    let contextText = `Innings ${matchData.currentInnings || 1}`;
    if (matchData.currentInnings === 2 && matchData.target) {
        const required = matchData.target - currentScore.runs;
        contextText = `Need ${required} runs`;
    }
    if (matchData.status === 'completed') {
        contextText = matchData.result?.margin || 'Match Over';
    }
    animateValue('target-info', contextText);

    // Recent Balls
    const recentBallsContainer = document.getElementById('recent-balls');
    recentBallsContainer.innerHTML = '';
    const recentEvents = (matchData.ballByBall || []).slice(-6); // Get last 6 balls
    recentEvents.forEach(ball => {
        const div = document.createElement('div');
        div.className = 'ball-bubble';
        
        if (ball.wicket) {
            div.classList.add('wicket');
            div.innerText = 'W';
        } else if (ball.extraType) {
            div.classList.add('extra');
            let initial = ball.extraType.charAt(0).toUpperCase();
            if (ball.extraType === 'leg-bye') initial = 'LB';
            if (ball.extraType === 'no-ball') initial = 'NB';
            div.innerText = `${ball.extraRuns}${initial}`;
        } else {
            div.innerText = ball.runs;
            if (ball.runs === 4) div.classList.add('four');
            if (ball.runs === 6) div.classList.add('six');
        }
        
        recentBallsContainer.appendChild(div);
    });
}

// Trigger Event Banner (Six, Four, Wicket)
function triggerEventBanner(type, text) {
    const banner = document.getElementById('event-banner');
    const bannerText = document.getElementById('event-text');
    
    banner.className = 'event-banner'; // reset
    bannerText.innerText = text;

    if (type === 'six') banner.classList.add('bg-success');
    if (type === 'four') banner.classList.add('bg-accent');
    // wicket uses default danger bg

    banner.classList.add('show');

    setTimeout(() => {
        banner.classList.remove('show');
    }, 4000); // hide after 4 seconds
}

// Socket Listeners
socket.on('connect', () => {
    console.log("Connected to backend");
});

socket.on('ball-event', (data) => {
    console.log("Ball event received:", data);
    updateUI(data.match);

    // Check for special events to trigger banner
    const ball = data.ballEvent;
    if (ball) {
        if (ball.wicket) {
            triggerEventBanner('wicket', 'WICKET!');
        } else if (ball.runs === 6) {
            triggerEventBanner('six', 'SIX!');
        } else if (ball.runs === 4) {
            triggerEventBanner('four', 'FOUR!');
        }
    }
});

socket.on('match-update', (data) => {
    console.log("Match update received:", data);
    updateUI(data);
});

socket.on('innings-change', (data) => {
    console.log("Innings changed:", data);
    updateUI(data);
});

socket.on('match-completed', (data) => {
    console.log("Match completed:", data);
    updateUI(data);
});
