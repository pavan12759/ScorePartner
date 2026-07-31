import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/presentation/providers/scoring_provider.dart';
import 'package:provider/provider.dart';

class EditBallDialog extends StatefulWidget {
  final MatchModel match;
  final int ballIndex;
  final BallEvent ball;

  const EditBallDialog({
    super.key,
    required this.match,
    required this.ballIndex,
    required this.ball,
  });

  @override
  State<EditBallDialog> createState() => _EditBallDialogState();
}

class _EditBallDialogState extends State<EditBallDialog> {
  late TextEditingController _runsController;
  late TextEditingController _extraRunsController;
  String? _selectedExtraType;
  bool _isWicket = false;
  String? _selectedWicketType;
  String? _playerOutId;
  String? _fielderId;

  @override
  void initState() {
    super.initState();
    _runsController = TextEditingController(text: widget.ball.runs.toString());
    _extraRunsController = TextEditingController(text: widget.ball.extraRuns.toString());
    _selectedExtraType = widget.ball.extraType;
    _isWicket = widget.ball.wicket != null;
    _selectedWicketType = widget.ball.wicket?.type;
    _playerOutId = widget.ball.wicket?.playerId;
    _fielderId = widget.ball.wicket?.fielderId;
  }

  @override
  void dispose() {
    _runsController.dispose();
    _extraRunsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Ball ${widget.ball.overNumber}.${widget.ball.ballNumber}',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Runs from bat
            Text('Runs (from bat)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
            SizedBox(height: 4.h),
            TextField(
              controller: _runsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '0',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              ),
            ),
            SizedBox(height: 16.h),

            // Extra Type
            Text('Extra Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
            SizedBox(height: 4.h),
            DropdownButtonFormField<String?>(
              value: _selectedExtraType,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                const DropdownMenuItem(value: 'wide', child: Text('Wide')),
                const DropdownMenuItem(value: 'no-ball', child: Text('No Ball')),
                const DropdownMenuItem(value: 'bye', child: Text('Bye')),
                const DropdownMenuItem(value: 'leg-bye', child: Text('Leg Bye')),
              ],
              onChanged: (val) => setState(() => _selectedExtraType = val),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              ),
            ),
            SizedBox(height: 16.h),

            // Extra Runs
            Text('Extra Runs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
            SizedBox(height: 4.h),
            TextField(
              controller: _extraRunsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '0',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              ),
            ),
            SizedBox(height: 16.h),

            // Wicket Toggle
            Row(
              children: [
                Text('Wicket?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                const Spacer(),
                Switch(
                  value: _isWicket,
                  onChanged: (val) => setState(() => _isWicket = val),
                  activeColor: Colors.red,
                ),
              ],
            ),

            if (_isWicket) ...[
              SizedBox(height: 8.h),
              Text('Wicket Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
              SizedBox(height: 4.h),
              DropdownButtonFormField<String>(
                value: _selectedWicketType ?? 'bowled',
                isExpanded: true,
                items: [
                  'bowled', 'caught', 'lbw', 'run out', 'stumped', 'hit wicket', 'retired'
                ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _selectedWicketType = val),
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
          onPressed: _onSave,
          child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _onSave() {
    final runs = int.tryParse(_runsController.text) ?? 0;
    final extraRuns = int.tryParse(_extraRunsController.text) ?? 0;

    // Create updated ball event
    final updatedBall = BallEvent(
      ballNumber: widget.ball.ballNumber,
      overNumber: widget.ball.overNumber,
      battingTeam: widget.ball.battingTeam,
      bowlerId: widget.ball.bowlerId,
      bowlerName: widget.ball.bowlerName,
      batsmanId: widget.ball.batsmanId,
      batsmanName: widget.ball.batsmanName,
      runs: runs,
      extraRuns: extraRuns,
      extraType: _selectedExtraType,
      commentary: widget.ball.commentary, // We keep the commentary as is or we'd need to regenerate it
      timestamp: widget.ball.timestamp,
      isLegalBall: _selectedExtraType != 'wide' && _selectedExtraType != 'no-ball',
      wicket: _isWicket ? Wicket(
        type: _selectedWicketType ?? 'bowled',
        playerId: _playerOutId ?? widget.ball.batsmanId,
        fielderId: _fielderId,
      ) : null,
    );

    Provider.of<ScoringProvider>(context, listen: false).updateBallEvent(
      widget.match,
      widget.ballIndex,
      updatedBall,
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Updating ball event and recalculating scores...')),
    );
  }
}
