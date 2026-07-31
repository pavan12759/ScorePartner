import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scorepatner/data/models/match_model.dart';

/// Simplified DLS (Duckworth-Lewis-Stern) Calculator for rain-affected matches
/// Uses the standard D/L resource table for limited-overs cricket

class DlsCalculator {
  /// Standard D/L resource percentages remaining table
  /// Key: overs remaining, Value: resource % remaining for wickets 0-9
  static const Map<int, List<double>> _resourceTable = {
    50: [100.0, 93.4, 85.1, 74.9, 62.7, 49.0, 34.9, 22.0, 11.9, 4.7],
    45: [95.0, 89.4, 82.2, 73.0, 61.7, 48.6, 34.8, 22.0, 11.9, 4.7],
    40: [89.3, 84.6, 78.5, 70.4, 60.1, 47.8, 34.6, 22.0, 11.9, 4.7],
    35: [82.7, 79.0, 73.9, 67.0, 57.9, 46.6, 34.2, 21.9, 11.9, 4.7],
    30: [75.1, 72.4, 68.3, 62.7, 54.8, 44.7, 33.4, 21.7, 11.9, 4.7],
    25: [66.5, 64.6, 61.5, 57.1, 50.7, 42.0, 31.9, 21.2, 11.8, 4.7],
    20: [56.6, 55.3, 53.2, 50.0, 45.2, 38.1, 29.6, 20.2, 11.5, 4.7],
    15: [45.2, 44.5, 43.1, 41.1, 37.8, 32.7, 26.2, 18.5, 11.0, 4.7],
    10: [32.1, 31.8, 31.1, 30.1, 28.2, 25.2, 21.0, 15.7, 10.0, 4.7],
    5:  [17.2, 17.1, 16.9, 16.6, 15.9, 14.7, 12.9, 10.4, 7.4, 3.9],
    1:  [4.0, 4.0, 3.9, 3.9, 3.8, 3.6, 3.3, 2.8, 2.2, 1.4],
    0:  [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
  };

  /// Interpolate resource percentage for any overs remaining and wickets lost
  static double getResourcePercentage(double oversRemaining, int wicketsLost) {
    if (wicketsLost < 0) wicketsLost = 0;
    if (wicketsLost > 9) wicketsLost = 9;
    if (oversRemaining <= 0) return 0.0;

    final keys = _resourceTable.keys.toList()..sort();
    
    // Find bracketing overs
    int lowerOvers = 0;
    int upperOvers = 50;
    for (int i = 0; i < keys.length - 1; i++) {
      if (oversRemaining >= keys[i] && oversRemaining <= keys[i + 1]) {
        lowerOvers = keys[i];
        upperOvers = keys[i + 1];
        break;
      }
    }

    if (oversRemaining >= 50) return _resourceTable[50]![wicketsLost];

    final lowerVal = _resourceTable[lowerOvers]![wicketsLost];
    final upperVal = _resourceTable[upperOvers]![wicketsLost];

    // Linear interpolation
    final fraction = (oversRemaining - lowerOvers) / (upperOvers - lowerOvers);
    return lowerVal + (upperVal - lowerVal) * fraction;
  }

  /// Calculate revised target for team 2
  /// team1Score: Team 1's final score
  /// team1Overs: Team 1's overs faced
  /// team1MaxOvers: Team 1's maximum overs
  /// team2MaxOvers: Team 2's revised (reduced) overs
  /// team1Wickets: Team 1 wickets lost (not used in simple method)
  static int calculateRevisedTarget({
    required int team1Score,
    required double team1Overs,
    required int team1MaxOvers,
    required double team2MaxOvers,
    int team1Wickets = 0,
    int team2Wickets = 0,
  }) {
    // Resource available to Team 1
    final r1 = getResourcePercentage(team1MaxOvers.toDouble(), 0);
    
    // Resource available to Team 2
    final r2 = getResourcePercentage(team2MaxOvers, team2Wickets);
    
    if (r1 <= 0) return team1Score + 1;
    
    // If Team 2 has more resources, target is inflated
    // If Team 2 has fewer resources, target is reduced
    final ratio = r2 / r1;
    final revisedScore = (team1Score * ratio).ceil();
    
    return revisedScore + 1; // Target = revised score + 1
  }

  /// Calculate par score at current point for team 2
  static int calculateParScore({
    required int team1Score,
    required int team1MaxOvers,
    required double team2MaxOvers,
    required double team2OversUsed,
    required int team2Wickets,
  }) {
    final r1 = getResourcePercentage(team1MaxOvers.toDouble(), 0);
    final r2Total = getResourcePercentage(team2MaxOvers, 0);
    final r2Remaining = getResourcePercentage(team2MaxOvers - team2OversUsed, team2Wickets);
    final r2Used = r2Total - r2Remaining;
    
    if (r1 <= 0) return 0;
    
    final ratio = r2Used / r1;
    return (team1Score * ratio).ceil();
  }
}

/// DLS Calculator Card widget for the match UI
class DlsCalculatorCard extends StatefulWidget {
  final MatchModel match;
  
  const DlsCalculatorCard({super.key, required this.match});

  @override
  State<DlsCalculatorCard> createState() => _DlsCalculatorCardState();
}

class _DlsCalculatorCardState extends State<DlsCalculatorCard> {
  final _reducedOversController = TextEditingController();
  int? _revisedTarget;
  int? _parScore;
  bool _isExpanded = false;

  @override
  void dispose() {
    _reducedOversController.dispose();
    super.dispose();
  }

  void _calculate() {
    final input = double.tryParse(_reducedOversController.text);
    if (input == null || input <= 0 || input > widget.match.oversPerSide) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enter valid overs between 1 and ${widget.match.oversPerSide}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final match = widget.match;
    final team1Score = match.currentInnings >= 2
        ? match.team1Score.runs
        : match.team2Score.runs;
    
    final team2Overs = match.currentInnings >= 2
        ? match.team2Score.overs
        : match.team1Score.overs;
    
    final team2Wickets = match.currentInnings >= 2
        ? match.team2Score.wickets
        : match.team1Score.wickets;

    setState(() {
      _revisedTarget = DlsCalculator.calculateRevisedTarget(
        team1Score: team1Score,
        team1Overs: match.team1Score.overs,
        team1MaxOvers: match.oversPerSide,
        team2MaxOvers: input,
        team2Wickets: team2Wickets,
      );

      _parScore = DlsCalculator.calculateParScore(
        team1Score: team1Score,
        team1MaxOvers: match.oversPerSide,
        team2MaxOvers: input,
        team2OversUsed: team2Overs,
        team2Wickets: team2Wickets,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade600, Colors.teal.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: _isExpanded
                    ? BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))
                    : BorderRadius.circular(16.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud, color: Colors.white, size: 20.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'DLS CALCULATOR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.sp,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      'RAIN DELAY',
                      style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                ],
              ),
            ),
          ),
          // Body
          if (_isExpanded) ...[
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'If rain reduces Team 2\'s innings, enter the revised overs to calculate the DLS target.',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _reducedOversController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Revised Overs for Team 2',
                            labelStyle: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                            hintText: 'e.g. 15',
                            hintStyle: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      ElevatedButton(
                        onPressed: _calculate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        ),
                        child: Text('CALCULATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp)),
                      ),
                    ],
                  ),
                  // Results
                  if (_revisedTarget != null) ...[
                    SizedBox(height: 16.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal.shade50, Colors.green.shade50],
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildResultStat('REVISED TARGET', '$_revisedTarget', Colors.teal.shade700),
                              Container(width: 1.w, height: 40.h, color: Colors.teal.shade200),
                              _buildResultStat('PAR SCORE', '${_parScore ?? "-"}', Colors.green.shade700),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'Team 2 needs $_revisedTarget to win in ${_reducedOversController.text} overs',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal.shade800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 8.h),
                  Text(
                    '⚡ Simplified D/L method for gully & club cricket',
                    style: TextStyle(fontSize: 9.sp, color: Colors.grey[400], fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w900, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.bold, color: color.withOpacity(0.7), letterSpacing: 0.5),
        ),
      ],
    );
  }
}
