import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:scorepatner/data/services/firebase_data_service.dart';
import 'package:scorepatner/data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import 'chat_screen.dart';
import 'dart:convert';
import '../../widgets/state/scorepartner_skeleton.dart';
import '../../widgets/state/scorepartner_empty_state.dart';
import '../../widgets/state/scorepartner_error_state.dart';
import '../../../core/theme/app_theme.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<AuthProvider>().user?.uid;

    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view messages')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Future: Open contacts or search screen to start new chat
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Search users to start a new chat!')),
          );
        },
        backgroundColor: AppTheme.primaryOrange,
        child: const Icon(Icons.message, color: Colors.white),
      ),
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey[200],
            height: 1.0,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Logo Watermark
          Center(
            child: Opacity(
              opacity: 0.08,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.shield_outlined, size: 180.sp, color: Colors.grey[400]),
                      Positioned(
                        top: 40.h,
                        child: Icon(Icons.sports_cricket, size: 80.sp, color: Colors.grey[600]),
                      ),
                      Positioned(
                        bottom: 35.h,
                        child: Icon(Icons.star, size: 24.sp, color: Color(0xFFA0522D)),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'SCOREPARTNER',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey[400],
                      letterSpacing: 4.0,
                    ),
                  ),
                  Text(
                    'OFFICIAL CHAT',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA0522D),
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Column(
            children: [
              // Search Bar
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search conversations...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24.r),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseDataService.instance.getUserChats(currentUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: 4,
                  itemBuilder: (_, __) => Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: ScorePartnerSkeleton(
                      width: double.infinity,
                      height: 80.h,
                      borderRadius: 12.r,
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: EdgeInsets.all(24.w),
                  child: ScorePartnerErrorState(message: snapshot.error.toString()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: ScorePartnerEmptyState(
                    title: 'No messages yet',
                    description: 'Visit a player profile to start chatting.',
                    icon: Icons.chat_bubble_outline,
                  ),
                );
              }

              final chatDocs = snapshot.data!.docs;
              
              // Sort locally by lastMessageTime descending
              final sortedDocs = List<QueryDocumentSnapshot>.from(chatDocs);
              sortedDocs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTime = (aData['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(2000);
                final bTime = (bData['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(2000);
                return bTime.compareTo(aTime);
              });

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
                itemCount: sortedDocs.length,
                itemBuilder: (context, index) {
                  final chatData = sortedDocs[index].data() as Map<String, dynamic>;
                  final chatId = sortedDocs[index].id;
                  final participants = List<String>.from(chatData['participants'] ?? []);
                  final otherUserId = participants.firstWhere(
                    (id) => id != currentUserId,
                    orElse: () => '',
                  );

                  if (otherUserId.isEmpty) return SizedBox.shrink();

                  // Fetch other user's details
                  return FutureBuilder<UserModel?>(
                    future: FirebaseDataService.instance.getUserById(otherUserId),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Material(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12.r),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              leading: CircleAvatar(backgroundColor: Colors.grey[200]),
                              title: Text('Loading...', style: TextStyle(color: Colors.grey[500])),
                            ),
                          ),
                        );
                      }

                      final otherUser = userSnapshot.data!;
                      if (_searchQuery.isNotEmpty && !otherUser.name.toLowerCase().contains(_searchQuery)) {
                        return const SizedBox.shrink();
                      }

                      final lastMessage = chatData['lastMessage'] ?? '';
                      final lastMessageTime = (chatData['lastMessageTime'] as Timestamp?)?.toDate();
                      
                      // Example unread logic: you can hook this up to actual backend fields
                      final bool hasUnread = chatData['lastMessageSenderId'] != currentUserId && 
                                             chatData['isLastMessageRead'] == false;
                      
                      // Simple time formatting
                      String timeText = '';
                      if (lastMessageTime != null) {
                        final now = DateTime.now();
                        final diff = now.difference(lastMessageTime);
                        if (diff.inMinutes < 60) {
                          timeText = '${diff.inMinutes}m';
                        } else if (diff.inHours < 24) {
                          timeText = '${diff.inHours}h';
                        } else {
                          timeText = '${diff.inDays}d';
                        }
                      }

                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: Colors.grey[200]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                          leading: (() {
                            final imgProvider = getProfileImageProvider(otherUser.profileImageUrl);
                            return CircleAvatar(
                              radius: 26,
                              backgroundColor: const Color(0xFFA0522D).withOpacity(0.1),
                              backgroundImage: imgProvider,
                              child: imgProvider == null
                                  ? Text(
                                      otherUser.name.isNotEmpty ? otherUser.name[0].toUpperCase() : '?',
                                      style: TextStyle(color: const Color(0xFFA0522D), fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            );
                          })(),
                          title: Text(
                            otherUser.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 16.sp,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                timeText,
                                style: TextStyle(
                                  color: hasUnread ? AppTheme.primaryOrange : Colors.grey[500], 
                                  fontSize: 12.sp,
                                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              if (hasUnread) ...[
                                SizedBox(height: 4.h),
                                Container(
                                  width: 8.w,
                                  height: 8.w,
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ]
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  chatId: chatId,
                                  otherUserId: otherUserId,
                                  otherUserName: otherUser.name,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
        ],
      ),
    );
  }
}
