import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/core/theme/app_theme.dart';

class OversTab extends StatefulWidget {
  final MatchModel match;
  
  const OversTab({super.key, required this.match});

  @override
  State<OversTab> createState() => _OversTabState();
}

class _OversTabState extends State<OversTab> {
  late final ScrollController _scrollController1;
  late final ScrollController _scrollController2;
  late final ScrollController _scrollController3;
  
  @override
  void initState() {
    super.initState();
    _scrollController1 = ScrollController();
    _scrollController2 = ScrollController();
    _scrollController3 = ScrollController();
  }

  @override
  void dispose() {
    _scrollController1.dispose();
    _scrollController2.dispose();
    _scrollController3.dispose();
    super.dispose();
  }

  List<BallEvent> _getRegularBalls(List<BallEvent> balls) {
    if (balls.isEmpty) return [];
    if (!widget.match.isSuperOver) return balls; // If not a super over, all balls are regular
    
    List<BallEvent> regular = [];
    int maxOverSoFar = -1;
    bool isSuperOverPhase = false;
    for (var b in balls) {
      if (!isSuperOverPhase && b.overNumber < maxOverSoFar) isSuperOverPhase = true;
      if (!isSuperOverPhase && b.overNumber > maxOverSoFar) maxOverSoFar = b.overNumber;
      if (!isSuperOverPhase) regular.add(b);
    }
    return regular;
  }

  List<BallEvent> _getSuperOverBalls(List<BallEvent> balls) {
    if (balls.isEmpty) return [];
    if (!widget.match.isSuperOver) return []; // If not a super over match, no super over balls
    
    List<BallEvent> superOver = [];
    int maxOverSoFar = -1;
    bool isSuperOverPhase = false;
    for (var b in balls) {
      if (!isSuperOverPhase && b.overNumber < maxOverSoFar) isSuperOverPhase = true;
      if (!isSuperOverPhase && b.overNumber > maxOverSoFar) maxOverSoFar = b.overNumber;
      if (isSuperOverPhase) superOver.add(b);
    }
    return superOver;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Determine Innings Order using Toss
    String? firstBattingTeamId;
    String? secondBattingTeamId;
    
    // 1. Determine Innings Order using Toss
    // Heuristic: Split balls by team
    final team1Balls = widget.match.ballByBall.where((b) => b.battingTeam == widget.match.team1Id).toList();
    final team2Balls = widget.match.ballByBall.where((b) => b.battingTeam == widget.match.team2Id).toList();
    
    // Determine which is 1st Innings
    List<BallEvent> firstInningsBalls = [];
    List<BallEvent> secondInningsBalls = [];
    String firstInningsTeamName = "";
    String secondInningsTeamName = "";
    
    // Logic: If Match is in 2nd innings, the current batting team is 2nd.
    // If Match is in 1st innings, current is 1st.
    // But we need to cater for completed matches too.
    
    // Robust Logic: Check who batted first based on Ball Data Timestamps or order
    // Since list is chronological, invalid assumption? 
    // Actually, usually ballByBall is appended. So first ball in list tells us who batted first.
    
    String firstBattingId = widget.match.team1Id; // default
    if (widget.match.ballByBall.isNotEmpty) {
      firstBattingId = widget.match.ballByBall.first.battingTeam;
    } else {
       // No balls yet. Use Toss if available.
       if (widget.match.tossDecision == 'bat') {
          // If toss winner decided to bat, they are first. 
          // MatchModel usually has tossWinnerId.
          // Let's assume team1 is defaults if no info.
       }
    }
    
    final t1Regular = _getRegularBalls(team1Balls);
    final t2Regular = _getRegularBalls(team2Balls);
    final t1Super = _getSuperOverBalls(team1Balls);
    final t2Super = _getSuperOverBalls(team2Balls);

    if (firstBattingId == widget.match.team1Id) {
      firstInningsBalls = t1Regular;
      firstInningsTeamName = widget.match.team1Name;
      secondInningsBalls = t2Regular;
      secondInningsTeamName = widget.match.team2Name;
    } else {
      firstInningsBalls = t2Regular;
      firstInningsTeamName = widget.match.team2Name;
      secondInningsBalls = t1Regular;
      secondInningsTeamName = widget.match.team1Name;
    }
    
    bool hasSuperOver = widget.match.isSuperOver;

    return DefaultTabController(
      length: hasSuperOver ? 3 : 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: AppTheme.primaryOrange,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryOrange,
              indicatorWeight: 3,
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
              tabs: [
                const Tab(text: '1ST INNINGS'),
                const Tab(text: '2ND INNINGS'),
                if (hasSuperOver) const Tab(text: 'SUPER OVER'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildOversList(firstInningsBalls, firstInningsTeamName, _scrollController1),
                _buildOversList(secondInningsBalls, secondInningsTeamName, _scrollController2),
                if (hasSuperOver) _buildSuperOverTab(t1Super, t2Super, _scrollController3),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSuperOverTab(List<BallEvent> t1Super, List<BallEvent> t2Super, ScrollController controller) {
    if (t1Super.isEmpty && t2Super.isEmpty) {
       return const Center(child: Text("No super over bowled yet", style: TextStyle(color: Colors.grey)));
    }
    return SingleChildScrollView(
      controller: controller,
      child: Column(
        children: [
          if (t1Super.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(top: 16.h, left: 16.w, right: 16.w),
              child: Text("${widget.match.team1Name} Super Over", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 14.sp)),
            ),
            _buildOversList(t1Super, widget.match.team1Name, ScrollController(), shrinkWrap: true, isSuperOver: true),
          ],
          if (t2Super.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(top: 16.h, left: 16.w, right: 16.w),
              child: Text("${widget.match.team2Name} Super Over", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 14.sp)),
            ),
            _buildOversList(t2Super, widget.match.team2Name, ScrollController(), shrinkWrap: true, isSuperOver: true),
          ]
        ],
      ),
    );
  }
  
  Widget _buildOversList(List<BallEvent> balls, String teamName, ScrollController controller, {bool shrinkWrap = false, bool isSuperOver = false}) {
    if (balls.isEmpty) {
      return Center(
        child: Text("No overs bowled yet for $teamName", style: TextStyle(color: Colors.grey)),
      );
    }

    // Group by Over Number
    final Map<int, List<BallEvent>> oversMap = {};
    for (var ball in balls) {
      if (!oversMap.containsKey(ball.overNumber)) {
        oversMap[ball.overNumber] = [];
      }
      oversMap[ball.overNumber]!.add(ball);
    }
    
    // Sort overs descending (latest first)
    final sortedOverNumbers = oversMap.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      controller: shrinkWrap ? null : controller,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      shrinkWrap: shrinkWrap,
      padding: EdgeInsets.all(16.w),
      itemCount: sortedOverNumbers.length,
      itemBuilder: (context, index) {
        final overNum = sortedOverNumbers[index];
        final overBalls = oversMap[overNum]!;
        
        // Calculate runs in this over
        int runsInOver = 0;
        int wicketsInOver = 0;
        for (var b in overBalls) {
          runsInOver += b.runs + b.extraRuns;
          if (b.wicket != null) wicketsInOver++;
        }

        // Calculate bowler spell up to this over
        int bowlerBalls = 0;
        int bowlerRuns = 0;
        int bowlerWickets = 0;
        String bowlerName = overBalls.isNotEmpty ? overBalls.first.bowlerName : "Bowler";
        
        if (overBalls.isNotEmpty) {
           String bowlerId = overBalls.first.bowlerId;
           for (var b in balls) {
               if (b.bowlerId == bowlerId && b.overNumber <= overNum) {
                   if (b.extraType != 'wide' && b.extraType != 'no-ball') bowlerBalls++;
                   bowlerRuns += b.runs;
                   if (b.extraType == 'wide' || b.extraType == 'no-ball') bowlerRuns += b.extraRuns;
                   if (b.wicket != null && b.wicket?.type != 'run out') bowlerWickets++;
               }
           }
        }
        
        String bowlerSpell = "${bowlerBalls ~/ 6}.${bowlerBalls % 6}-0-$bowlerRuns-$bowlerWickets";

        // Determine Summary
        String summaryText = "";
        IconData summaryIcon = Icons.info_outline;
        Color summaryColor = Colors.grey;

        final wicketBalls = overBalls.where((b) => b.wicket != null).toList();
        if (wicketBalls.isNotEmpty) {
            summaryText = "Wicket! ${wicketBalls.last.batsmanName.isNotEmpty ? wicketBalls.last.batsmanName : 'Batsman'} dismissed.";
            summaryIcon = Icons.person_remove_outlined;
            summaryColor = const Color(0xFFC62828);
        } else if (runsInOver >= 10) {
            summaryText = "Expensive over for the bowling side.";
            summaryIcon = Icons.trending_up;
            summaryColor = Colors.green;
        } else if (runsInOver <= 4) {
            summaryText = "Excellent tight over by the bowler.";
            summaryIcon = Icons.trending_down;
            summaryColor = Colors.blue;
        } else {
            summaryText = "Steady over for the batting side.";
            summaryIcon = Icons.analytics_outlined;
            summaryColor = Colors.grey.shade600;
        }
        
        return GestureDetector(
          onTap: () => _showOverCommentary(context, overNum, overBalls),
          child: Container(
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: isSuperOver ? const Color(0xFFD6E3FF) : Colors.white,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: const Color(0xFFD6DBE9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "OVER ${overNum + 1}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              color: Colors.grey.shade600, 
                              fontSize: 12.sp, 
                              letterSpacing: 0.5
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            bowlerName,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1A3365),
                              fontSize: 18.sp,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            bowlerSpell,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade400,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          runsInOver.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: runsInOver >= 10 ? AppTheme.primaryOrange : const Color(0xFF1A3365),
                            fontSize: 32.sp,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          "RUNS",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade400,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: overBalls.map((b) => Padding(
                      padding: EdgeInsets.only(right: 8.0.w),
                      child: _buildBallCircle(b),
                    )).toList(),
                  ),
                ),
                Divider(color: Colors.grey.shade200, height: 24.h),
                Row(
                  children: [
                    Icon(
                      summaryIcon,
                      color: summaryColor,
                      size: 16.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        summaryText,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13.sp),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildBallCircle(BallEvent ball) {
     Color bgColor = Colors.white;
     Color textColor = const Color(0xFF1A3365);
     Color borderColor = Colors.grey.shade300;
     String label = ball.displayString;
     
     if (ball.wicket != null) { 
       bgColor = const Color(0xFFC62828); 
       textColor = Colors.white;
       borderColor = Colors.transparent;
       label = 'W';
     }
     else if (ball.runs == 6) { 
       bgColor = const Color(0xFF1B5E20); 
       textColor = Colors.white; 
       borderColor = Colors.transparent;
     }
     else if (ball.runs == 4) { 
       bgColor = const Color(0xFF1565C0); 
       textColor = Colors.white; 
       borderColor = Colors.transparent;
     }
     else if (ball.extraType == 'wide') {
       textColor = const Color(0xFFC62828);
       label = 'wd';
     }
     else if (ball.extraType == 'no-ball') {
       textColor = const Color(0xFFE65100);
       label = 'nb';
     }

      return Container(
        width: 36.w,
        height: 36.h,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Text(
            label, 
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13.sp)
          )
        ),
      );
   }

   void _showOverCommentary(BuildContext context, int overNum, List<BallEvent> balls) {
     showModalBottomSheet(
       context: context,
       isScrollControlled: true,
       backgroundColor: Colors.transparent,
       builder: (context) {
         // Sort balls in ascending order for commentary reading (ball 1 to 6)
         final sortedBalls = List<BallEvent>.from(balls)..sort((a, b) => a.ballNumber.compareTo(b.ballNumber));
         
         return Container(
           decoration: BoxDecoration(
             color: Colors.white,
             borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
           ),
           constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
           child: Column(
             children: [
               Container(
                 padding: EdgeInsets.all(16.w),
                 decoration: BoxDecoration(
                   border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                 ),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text(
                       'OVER ${overNum + 1} COMMENTARY',
                       style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
                     ),
                     IconButton(
                       icon: Icon(Icons.close),
                       onPressed: () => Navigator.pop(context),
                       padding: EdgeInsets.zero,
                       constraints: BoxConstraints(),
                     ),
                   ],
                 ),
               ),
               Expanded(
                 child: ListView.separated(
                   padding: EdgeInsets.all(16.w),
                   itemCount: sortedBalls.length,
                   separatorBuilder: (_, __) => SizedBox(height: 12.h),
                   itemBuilder: (context, index) {
                     final event = sortedBalls[index];
                     bool isWicket = event.wicket != null;
                     bool isBoundary = event.runs == 4 || event.runs == 6;
                     
                     return Row(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         // Ball bubble
                         _buildBallCircle(event),
                         SizedBox(width: 12.w),
                         // Commentary text
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Row(
                                 children: [
                                   Text(
                                     '${event.overNumber}.${event.ballNumber}',
                                     style: TextStyle(
                                       fontWeight: FontWeight.bold,
                                       color: AppTheme.primaryOrange,
                                       fontSize: 12.sp,
                                     ),
                                   ),
                                   SizedBox(width: 8.w),
                                   if (isWicket)
                                     Container(
                                       padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                       decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4.r)),
                                       child: Text('WICKET', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9.sp)),
                                     )
                                   else if (isBoundary)
                                     Container(
                                       padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                       decoration: BoxDecoration(
                                         color: event.runs == 6 ? AppTheme.primaryOrange : Colors.blueAccent, 
                                         borderRadius: BorderRadius.circular(4.r)
                                       ),
                                       child: Text(
                                         event.runs == 4 ? 'FOUR' : 'SIX', 
                                         style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9.sp)
                                       ),
                                     )
                                   else
                                     Text(
                                       '${event.runs} RUN(S)', 
                                       style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 11.sp)
                                     ),
                                 ],
                               ),
                               SizedBox(height: 4.h),
                               Text(
                                 event.commentary.isNotEmpty ? event.commentary : _generateCommentaryFallback(event),
                                 style: TextStyle(color: Colors.black87, height: 1.4, fontSize: 13.sp),
                               ),
                             ],
                           ),
                         ),
                       ],
                     );
                   },
                 ),
               ),
             ],
           ),
         );
       },
     );
   }

   String _generateCommentaryFallback(BallEvent event) {
     if (event.wicket != null) return "OUT! That's a huge wicket.";
     if (event.runs == 6) return "HUGE! That's gone all the way for six!";
     if (event.runs == 4) return "Great shot found the gap for four.";
     if (event.runs == 0) return "Dot ball, good bowling.";
     return "Takes a single.";
   }
}
