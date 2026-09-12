import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/ai_models.dart';
import '../../data/services/firebase_data_service.dart';
import '../../presentation/screens/matches/match_detail_screen.dart';
import '../../presentation/screens/profile/player_profile_screen.dart';
import '../../presentation/screens/teams/team_details_screen.dart';
import '../../presentation/screens/tournament/tournament_details_screen.dart';

/// Handles AI action navigation — resolves entity IDs to full model objects
/// and pushes the correct existing ScorePartner screens.
class AIActionHandler {
  static Future<void> handleAction(
    BuildContext context,
    AIAction action,
  ) async {
    switch (action.type) {
      case 'open_match':
        _openMatch(context, action.entityId);
        break;
      case 'open_player':
        _openPlayer(context, action.entityId);
        break;
      case 'open_team':
        _openTeam(context, action.entityId);
        break;
      case 'open_tournament':
        _openTournament(context, action.entityId);
        break;
      case 'open_news':
        _openNews(context, action.entityId);
        break;
      default:
        debugPrint('⚠️ Unknown AI action type: ${action.type}');
    }
  }

  /// Open match detail screen — MatchDetailScreen accepts matchId directly
  static void _openMatch(BuildContext context, String matchId) {
    if (matchId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchDetailScreen(matchId: matchId),
      ),
    );
  }

  /// Open player profile — PlayerProfileScreen requires full UserModel
  static Future<void> _openPlayer(BuildContext context, String playerId) async {
    if (playerId.isEmpty) return;

    // Show loading
    _showLoadingSnackBar(context, 'Loading player profile...');

    try {
      final user = await FirebaseDataService.instance.getUserById(playerId);
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (user != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerProfileScreen(player: user),
          ),
        );
      } else {
        _showErrorSnackBar(context, 'Player not found');
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showErrorSnackBar(context, 'Failed to load player');
    }
  }

  /// Open team details — TeamDetailsScreen requires full TeamModel
  static Future<void> _openTeam(BuildContext context, String teamId) async {
    if (teamId.isEmpty) return;

    _showLoadingSnackBar(context, 'Loading team...');

    try {
      final team = await FirebaseDataService.instance.getTeamById(teamId);
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (team != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamDetailsScreen(team: team),
          ),
        );
      } else {
        _showErrorSnackBar(context, 'Team not found');
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showErrorSnackBar(context, 'Failed to load team');
    }
  }

  /// Open tournament details — TournamentDetailsScreen requires full TournamentModel
  static Future<void> _openTournament(
      BuildContext context, String tournamentId) async {
    if (tournamentId.isEmpty) return;

    _showLoadingSnackBar(context, 'Loading tournament...');

    try {
      final tournament =
          await FirebaseDataService.instance.getTournamentById(tournamentId);
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (tournament != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TournamentDetailsScreen(tournament: tournament),
          ),
        );
      } else {
        _showErrorSnackBar(context, 'Tournament not found');
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showErrorSnackBar(context, 'Failed to load tournament');
    }
  }

  /// Open news URL in browser
  static Future<void> _openNews(BuildContext context, String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to open news URL: $e');
    }
  }

  static void _showLoadingSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
