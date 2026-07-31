import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_theme.dart';
import 'places_autocomplete_field.dart';

/// Dialog shown before starting a tournament match to configure match-specific settings
class MatchConfigDialog extends StatefulWidget {
  final String team1Name;
  final String team2Name;
  final int defaultOvers;
  final String? defaultVenue;
  final String matchFormat; // 'T20', 'ODI', 'Test'

  const MatchConfigDialog({
    super.key,
    required this.team1Name,
    required this.team2Name,
    required this.defaultOvers,
    this.defaultVenue,
    this.matchFormat = 'T20',
  });

  @override
  State<MatchConfigDialog> createState() => _MatchConfigDialogState();
}

class _MatchConfigDialogState extends State<MatchConfigDialog> {
  late int _overs;
  late TextEditingController _venueController;
  double? _venueLatitude;
  double? _venueLongitude;

  @override
  void initState() {
    super.initState();
    _overs = widget.defaultOvers;
    _venueController = TextEditingController(text: widget.defaultVenue ?? '');
  }

  @override
  void dispose() {
    _venueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(Icons.settings, color: AppTheme.primaryOrange),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Match Configuration',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              '${widget.team1Name} vs ${widget.team2Name}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
            ),
            SizedBox(height: 16.h),
            
            // Format Info
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                   Icon(
                    widget.matchFormat == 'T20' ? Icons.flash_on :
                    widget.matchFormat == 'ODI' ? Icons.sports_cricket : Icons.shield,
                    size: 20.sp,
                    color: Colors.grey[700],
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Format: ${widget.matchFormat}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const Spacer(),
                  if (widget.matchFormat == 'Test')
                    Text('Unlimited Overs', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Overs Selection
            const Text(
              'Overs per Side',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _overs > 1 ? () => setState(() => _overs--) : null,
                    icon: Icon(Icons.remove_circle_outline),
                    color: AppTheme.primaryOrange,
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    '$_overs',
                    style: TextStyle(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  IconButton(
                    onPressed: _overs < 50 ? () => setState(() => _overs++) : null,
                    icon: Icon(Icons.add_circle_outline),
                    color: AppTheme.primaryOrange,
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            
            if (widget.matchFormat != 'Test')
              Wrap(
                spacing: 8,
                children: (widget.matchFormat == 'T20'
                        ? [10, 12, 15, 20]
                        : [20, 30, 40, 50])
                    .map((o) => ChoiceChip(
                          label: Text('$o'),
                          selected: _overs == o,
                          selectedColor: AppTheme.primaryOrange.withOpacity(0.2),
                          onSelected: (_) => setState(() => _overs = o),
                        ))
                    .toList(),
              ),
            SizedBox(height: 20.h),

            // Venue Input
            const Text(
              'Venue (Optional)',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8.h),
            PlacesAutocompleteField(
              label: 'Venue (Optional)',
              hint: 'Enter match venue',
              controller: _venueController,
              onPlaceSelected: (name, address, lat, lng) {
                setState(() {
                  _venueLatitude = lat;
                  _venueLongitude = lng;
                });
              },
            ),
            SizedBox(height: 24.h),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'overs': _overs,
                        'venue': _venueController.text.trim().isEmpty 
                            ? null 
                            : _venueController.text.trim(),
                        'latitude': _venueLatitude,
                        'longitude': _venueLongitude,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: const Text('Proceed to Toss'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
