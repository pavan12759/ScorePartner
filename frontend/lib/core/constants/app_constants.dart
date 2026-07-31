class AppConstants {
  // App Info
  static const String appName = 'ScorePartner';
  static const String appVersion = '1.0.0';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String matchesCollection = 'matches';
  static const String tournamentsCollection = 'tournaments';
  static const String teamsCollection = 'teams';
  static const String reelsCollection = 'reels';
  static const String newsCollection = 'news';
  static const String notificationsCollection = 'notifications';

  // Match Types
  static const String tennisBall = 'tennis-ball';
  static const String leatherBall = 'leather-ball';

  // Match Status
  static const String scheduledStatus = 'scheduled';
  static const String liveStatus = 'live';
  static const String completedStatus = 'completed';
  static const String abandonedStatus = 'abandoned';

  // Player Roles
  static const String batsmanRole = 'batsman';
  static const String bowlerRole = 'bowler';
  static const String allRounderRole = 'all-rounder';
  static const String wicketKeeperRole = 'wicket-keeper';

  // Batting Styles
  static const String rightHandBatting = 'right-hand';
  static const String leftHandBatting = 'left-hand';

  // Bowling Styles
  static const String fastBowling = 'fast';
  static const String mediumBowling = 'medium';
  static const String spinBowling = 'spin';

  // Tournament Types
  static const String leagueTournament = 'league';
  static const String knockoutTournament = 'knockout';

  // Reel Tags
  static const List<String> reelTags = [
    'six',
    'four',
    'wicket',
    'catch',
    'run-out',
    'celebration',
    'fielding',
  ];

  // Default Overs
  static const List<int> defaultOvers = [5, 6, 8, 10, 15, 20, 25, 30, 40, 50];

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  // Asset Paths
  static const String logoPath = 'assets/images/logo.png';
  static const String defaultProfilePath = 'assets/images/default_profile.png';
}
