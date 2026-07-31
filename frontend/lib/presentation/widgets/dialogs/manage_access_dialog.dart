import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/services/firebase_data_service.dart';

class ManageAccessDialog extends StatefulWidget {
  final MatchModel match;
  const ManageAccessDialog({super.key, required this.match});

  @override
  State<ManageAccessDialog> createState() => _ManageAccessDialogState();
}

class _ManageAccessDialogState extends State<ManageAccessDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = []; // Using dynamic to avoid import issues if User model not directly available
  bool _isSearching = false;
  final FirebaseDataService _dataService = FirebaseDataService.instance;

  void _searchUsers(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    
    // STRICT: SPP ID ONLY
    if (!query.toUpperCase().startsWith('SPP')) {
       if (mounted) setState(() => _searchResults = []);
       return;
    }

    if (mounted) setState(() => _isSearching = true);
    try {
      final user = await _dataService.getUserBySppId(query.toUpperCase());
      
      if (mounted) {
        setState(() {
          _searchResults = user != null ? [user] : [];
        });
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _addAccess(String userId, String accessType) async {
    // accessType: 'admin' or 'scorer'
    try {
      final match = widget.match;
      List<String> currentList = accessType == 'admin' 
          ? List.from(match.adminIds) 
          : List.from(match.scorerIds);
      
      if (currentList.contains(userId)) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User already has this access')),
          );
        }
        return; 
      }
      
      currentList.add(userId);
      
      Map<String, dynamic> updateData = {};
      if (accessType == 'admin') {
        updateData['adminIds'] = currentList;
      } else {
        updateData['scorerIds'] = currentList;
      }
      
      await _dataService.updateMatch(match.id, updateData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User added as $accessType')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding user: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Match Access'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by SPP ID (Required)',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _isSearching 
                    ? SizedBox(width: 20.w, height: 20.h, child: Padding(padding: EdgeInsets.all(8.0.w), child: CircularProgressIndicator(strokeWidth: 2))) 
                    : IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchUsers('');
                        },
                      ),
              ),
              onChanged: (val) {
                // Debounce could be added here
                if (val.length > 2) _searchUsers(val);
              },
            ),
            SizedBox(height: 16.h),
            if (_searchResults.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    // user is UserModel, accessing properties via map or assumed getter if visible
                    // Assuming UserModel has name and email/id
                    return ListTile(
                      leading: CircleAvatar(child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?')),
                      title: Text(user.name),
                      subtitle: Text('${user.email.isNotEmpty ? user.email : 'No email'}${user.spPId.isNotEmpty ? ' • ID: ${user.spPId}' : ''}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (type) => _addAccess(user.uid, type),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'admin',
                            child: Text('Make Admin'),
                          ),
                          const PopupMenuItem(
                            value: 'scorer',
                            child: Text('Make Scorer'),
                          ),
                        ],
                        child: const Chip(label: Text('Add')),
                      ),
                    );
                  },
                ),
              ),
            if (_searchResults.isEmpty && _searchController.text.isNotEmpty && !_isSearching)
              Padding(
                padding: EdgeInsets.all(8.0.w),
                child: Text('No users found'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}
