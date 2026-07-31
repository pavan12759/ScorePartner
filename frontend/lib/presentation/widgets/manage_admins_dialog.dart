import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/firebase_data_service.dart';
import '../../data/models/user_model.dart';
import 'dart:convert';

/// Dialog for managing tournament co-admins
/// Only accessible by the main organizer
class ManageAdminsDialog extends StatefulWidget {
  final String tournamentId;
  final String organizerId;
  final List<String> currentAdminIds;
  final Function(List<String>) onAdminsUpdated;

  const ManageAdminsDialog({
    super.key,
    required this.tournamentId,
    required this.organizerId,
    required this.currentAdminIds,
    required this.onAdminsUpdated,
  });

  @override
  State<ManageAdminsDialog> createState() => _ManageAdminsDialogState();
}

class _ManageAdminsDialogState extends State<ManageAdminsDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _adminIds = [];
  Map<String, UserModel> _adminUsers = {};
  List<UserModel> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _adminIds = List.from(widget.currentAdminIds);
    _loadAdminUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminUsers() async {
    final users = <String, UserModel>{};
    for (final adminId in _adminIds) {
      final user = await FirebaseDataService.instance.getUserById(adminId);
      if (user != null) {
        users[adminId] = user;
      }
    }
    if (mounted) {
      setState(() {
        _adminUsers = users;
        _isLoading = false;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    
    try {
      // STRICT: Search by SPP ID ONLY
      // We assume SPP ID starts with "SPP" (case insensitive check)
      if (query.toUpperCase().startsWith('SPP')) {
        final user = await FirebaseDataService.instance.getUserBySppId(query.toUpperCase());
        if (user != null && 
            user.uid != widget.organizerId && 
            !_adminIds.contains(user.uid)) {
          setState(() => _searchResults = [user]);
        } else {
          setState(() => _searchResults = []);
        }
      } else {
        // Did not start with SPP - clear results and maybe show a snackbar or just nothing
        // We only want to support SPP ID.
        setState(() => _searchResults = []);
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }

    if (mounted) {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _addAdmin(UserModel user) async {
    setState(() {
      _adminIds.add(user.uid);
      _adminUsers[user.uid] = user;
      _searchResults = [];
      _searchController.clear();
    });
  }

  Future<void> _removeAdmin(String userId) async {
    setState(() {
      _adminIds.remove(userId);
      _adminUsers.remove(userId);
    });
  }

  Future<void> _saveChanges() async {
    // Update tournament with new admin list
    final success = await FirebaseDataService.instance.updateTournament(
      widget.tournamentId,
      {'adminIds': _adminIds},
    );

    if (success) {
      widget.onAdminsUpdated(_adminIds);
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update admins')),
        );
      }
    }
  }

  ImageProvider? getProfileImageProvider(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.trim().startsWith('data:')) {
      try {
        final base64Str = url.split(',').last.trim();
        return MemoryImage(base64Decode(base64Str));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(maxHeight: 500),
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
                  child: Icon(Icons.admin_panel_settings, color: AppTheme.primaryOrange),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Manage Admins',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              'Co-admins can start and score matches',
              style: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
            ),
            SizedBox(height: 16.h),

            // Search Box
            TextField(
              controller: _searchController,
              onChanged: _searchUsers,
              decoration: InputDecoration(
                hintText: 'Search by SPP ID only (e.g., SPP...)',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _isSearching 
                    ? SizedBox(
                        width: 20.w, 
                        height: 20.h, 
                        child: Padding(
                          padding: EdgeInsets.all(12.w),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                helperText: 'Enter exact SPP ID to find user',
              ),
            ),

            // Search Results
            if (_searchResults.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Container(
                constraints: BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          style: TextStyle(color: AppTheme.primaryOrange),
                        ),
                      ),
                      title: Text(user.name),
                      subtitle: Text(user.spPId, style: TextStyle(fontSize: 11.sp)),
                      trailing: IconButton(
                        icon: Icon(Icons.add_circle, color: Colors.green),
                        onPressed: () => _addAdmin(user),
                      ),
                    );
                  },
                ),
              ),
            ],
            SizedBox(height: 16.h),

            // Current Admins
            const Text(
              'Current Co-Admins',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8.h),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_adminIds.isEmpty)
              Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.group_off, size: 40.sp, color: Colors.grey[400]),
                      SizedBox(height: 8.h),
                      Text(
                        'No co-admins yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Search and add users above',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12.sp),
                      ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _adminIds.length,
                  itemBuilder: (context, index) {
                    final adminId = _adminIds[index];
                    final user = _adminUsers[adminId];
                    return Card(
                      margin: EdgeInsets.only(bottom: 8.h),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                          backgroundImage: getProfileImageProvider(user?.profileImageUrl),
                          child: user?.profileImageUrl == null || user!.profileImageUrl.isEmpty
                              ? Text(
                                  user?.name.isNotEmpty == true 
                                      ? user!.name[0].toUpperCase() 
                                      : '?',
                                  style: TextStyle(color: AppTheme.primaryOrange),
                                )
                              : null,
                        ),
                        title: Text(user?.name ?? 'Unknown'),
                        subtitle: Text(user?.spPId ?? adminId, style: TextStyle(fontSize: 11.sp)),
                        trailing: IconButton(
                          icon: Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => _removeAdmin(adminId),
                        ),
                      ),
                    );
                  },
                ),
              ),
            SizedBox(height: 16.h),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
