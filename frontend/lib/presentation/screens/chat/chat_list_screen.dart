import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:scorepatner/data/services/firebase_data_service.dart';
import 'package:scorepatner/data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import 'chat_screen.dart';
import 'dart:convert';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

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
          
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseDataService.instance.getUserChats(currentUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFA0522D)));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: SelectableText(
                      'Error loading chats: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64.sp, color: Colors.grey[400]),
                      SizedBox(height: 16.h),
                      Text(
                        'No messages yet',
                        style: TextStyle(color: Colors.grey[500], fontSize: 16.sp),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Visit a player profile to start chatting',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12.sp),
                      ),
                    ],
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
                      final lastMessage = chatData['lastMessage'] ?? '';
                      final lastMessageTime = (chatData['lastMessageTime'] as Timestamp?)?.toDate();
                      
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
                          leading: CircleAvatar(
                            radius: 26,
                            backgroundColor: const Color(0xFFA0522D).withOpacity(0.1),
                            backgroundImage: getProfileImageProvider(otherUser.profileImageUrl),
                            child: otherUser.profileImageUrl.isEmpty
                                ? Text(
                                    otherUser.name.isNotEmpty ? otherUser.name[0].toUpperCase() : '?',
                                    style: TextStyle(color: const Color(0xFFA0522D), fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
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
                          trailing: Text(
                            timeText,
                            style: TextStyle(color: Colors.grey[500], fontSize: 12.sp),
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
        ],
      ),
    );
  }
}
