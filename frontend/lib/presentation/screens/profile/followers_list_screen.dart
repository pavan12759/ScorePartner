import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/firebase_data_service.dart';
import 'player_profile_screen.dart';
import 'dart:convert';

class FollowersListScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isFollowing; // true for Following, false for Followers

  const FollowersListScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.isFollowing,
  });

  @override
  State<FollowersListScreen> createState() => _FollowersListScreenState();
}

class _FollowersListScreenState extends State<FollowersListScreen> {
  bool _isLoading = true;
  List<UserModel> _users = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      List<String> userIds;
      if (widget.isFollowing) {
        userIds = await FirebaseDataService.instance.getFollowingIds(widget.userId);
      } else {
        userIds = await FirebaseDataService.instance.getFollowerIds(widget.userId);
      }

      final List<UserModel> loadedUsers = [];
      for (final id in userIds) {
        final user = await FirebaseDataService.instance.getUserById(id);
        if (user != null) {
          loadedUsers.add(user);
        }
      }

      if (mounted) {
        setState(() {
          _users = loadedUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isFollowing ? 'Following' : 'Followers',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48.sp, color: Colors.orange),
            SizedBox(height: 16.h),
            Text('Error loading users:\n$_error', textAlign: TextAlign.center),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _loadUsers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Text(
          widget.isFollowing 
              ? '${widget.userName} is not following anyone yet.' 
              : '${widget.userName} has no followers yet.',
          style: TextStyle(fontSize: 16.sp, color: Colors.grey),
        ),
      );
    }

    ImageProvider? getProfileImageProvider(String url) {
      if (url.isEmpty) return null;
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

    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey[200],
            backgroundImage: getProfileImageProvider(user.profileImageUrl),
            child: user.profileImageUrl.isEmpty
                ? Icon(Icons.person, color: Colors.grey)
                : null,
          ),
          title: Text(
            user.name,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(user.role.isNotEmpty ? user.role : 'Player'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlayerProfileScreen(player: user),
              ),
            );
          },
        );
      },
    );
  }
}
