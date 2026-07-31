import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/data/services/google_places_service.dart';

/// Callback with selected place details
typedef OnPlaceSelected = void Function(String name, String address, double? lat, double? lng);

/// A reusable autocomplete text field that searches Google Places.
/// Drop-in replacement for venue/location text fields.
class PlacesAutocompleteField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final OnPlaceSelected? onPlaceSelected;
  final String? Function(String?)? validator;

  const PlacesAutocompleteField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.icon = Icons.location_on_outlined,
    this.onPlaceSelected,
    this.validator,
  });

  @override
  State<PlacesAutocompleteField> createState() => _PlacesAutocompleteFieldState();
}

class _PlacesAutocompleteFieldState extends State<PlacesAutocompleteField> {
  final GooglePlacesService _placesService = GooglePlacesService.instance;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<PlacePrediction> _predictions = [];
  Timer? _debounce;
  bool _isLoading = false;
  bool _suppressSearch = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (_suppressSearch) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchPlaces(widget.controller.text);
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (query.trim().length < 2) {
      _removeOverlay();
      return;
    }

    setState(() => _isLoading = true);

    final results = await _placesService.searchPlaces(query);

    if (!mounted) return;
    setState(() {
      _predictions = results;
      _isLoading = false;
    });

    if (_predictions.isNotEmpty) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 48.w,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, 60.h),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12.r),
            shadowColor: Colors.black26,
            child: Container(
              constraints: BoxConstraints(maxHeight: 240.h),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppTheme.primaryOrange.withOpacity(0.2),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _predictions.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.grey.withOpacity(0.15),
                  ),
                  itemBuilder: (context, index) {
                    final prediction = _predictions[index];
                    return InkWell(
                      onTap: () => _onPredictionSelected(prediction),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 12.h,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6.w),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryOrange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Icon(
                                Icons.location_on_rounded,
                                size: 18.sp,
                                color: AppTheme.primaryOrange,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prediction.mainText,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.sp,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (prediction.secondaryText.isNotEmpty) ...[
                                    SizedBox(height: 2.h),
                                    Text(
                                      prediction.secondaryText,
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: Colors.grey,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _onPredictionSelected(PlacePrediction prediction) async {
    _removeOverlay();
    _suppressSearch = true;
    widget.controller.text = prediction.mainText;
    _suppressSearch = false;

    // Fetch place details for lat/lng
    final details = await _placesService.getPlaceDetails(prediction.placeId);

    if (widget.onPlaceSelected != null) {
      widget.onPlaceSelected!(
        prediction.mainText,
        prediction.secondaryText,
        details?.latitude,
        details?.longitude,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        validator: widget.validator,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: Icon(widget.icon, color: AppTheme.primaryOrange),
          suffixIcon: _isLoading
              ? Padding(
                  padding: EdgeInsets.all(12.w),
                  child: SizedBox(
                    width: 18.w,
                    height: 18.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                )
              : widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 18.sp, color: Colors.grey),
                      onPressed: () {
                        widget.controller.clear();
                        _removeOverlay();
                        widget.onPlaceSelected?.call('', '', null, null);
                      },
                    )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: AppTheme.primaryOrange, width: 1.5),
          ),
          filled: true,
          fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        ),
      ),
    );
  }
}
