import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scorepatner/core/broadcast/overlay_theme_data.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/presentation/widgets/broadcast/scorepartner_live_overlay.dart';

void main() {
  test('registers the league and layout broadcast themes', () {
    expect(
      OverlayThemes.getById('full_screen_broadcast').layoutType,
      'full_screen_broadcast',
    );
    expect(
      OverlayThemes.getById('half_screen_compact').layoutType,
      'half_screen_compact',
    );
    expect(OverlayThemes.getById('hundred_inspired').name, 'Electric 100');
    expect(OverlayThemes.getById('bbl_inspired').name, 'Night League');
  });

  testWidgets(
    'uses a compact layout without render overflows on narrow canvases',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(360, 800),
          builder: (context, child) {
            return const MaterialApp(
              home: Scaffold(body: SizedBox.expand(child: _OverlayUnderTest())),
            );
          },
        ),
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}

class _OverlayUnderTest extends StatelessWidget {
  const _OverlayUnderTest();

  @override
  Widget build(BuildContext context) {
    return ScorePartnerLiveOverlay(match: _match);
  }
}

final _match = MatchModel(
  id: 'match-1',
  matchName: 'Evening Premier League Final',
  tournamentName: 'ScorePartner Championship 2026',
  team1Id: 'team-1',
  team2Id: 'team-2',
  team1Name: 'Mumbai Cricket Club',
  team2Name: 'Delhi Warriors',
  ground: 'Municipal Cricket Ground, Sector 14',
  location: 'Mumbai',
  matchType: 'limited_overs',
  matchFormat: 'T20',
  oversPerSide: 20,
  scheduledDate: DateTime(2026, 7, 26),
  status: 'live',
  currentInnings: 1,
  currentBattingTeam: 'team1',
  bowlingTeam: 'team2',
  currentOver: 12,
  currentBall: 3,
  team1Score: const TeamScore(runs: 137, wickets: 4, overs: 12.3),
  team2Score: const TeamScore(runs: 0, wickets: 0, overs: 0),
  ballByBall: const [],
  createdBy: 'user-1',
  createdAt: DateTime(2026, 7, 26),
  updatedAt: DateTime(2026, 7, 26),
);
