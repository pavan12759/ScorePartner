import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:scorepatner/data/services/firebase_data_service.dart';
import 'package:scorepatner/data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/presentation/widgets/typing_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scorepatner/presentation/widgets/voice_message_player.dart';
import 'package:flutter/foundation.dart';
import 'package:scorepatner/presentation/screens/profile/player_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}



class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isTyping = false;
  
  Map<String, dynamic>? _replyMessage;
  String? _replyMessageId;

  late Stream<DocumentSnapshot> _chatStream;
  late Stream<bool> _userPresenceStream;
  late Stream<QuerySnapshot> _messagesStream;

  // Chat Theme variables
  List<Color> _bubbleGradient = [AppTheme.primaryOrange, AppTheme.deepOrange];
  String _currentThemeName = 'Classic Orange';

  // Search variables
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _chatStream = FirebaseDataService.instance.getChatStream(widget.chatId);
    _userPresenceStream = FirebaseDataService.instance.getUserPresenceStream(widget.otherUserId);
    _messagesStream = FirebaseDataService.instance.getMessages(widget.chatId);
    _loadChatTheme();
  }

  void _loadChatTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('chat_theme_${widget.chatId}') ?? 'Classic Orange';
    _setThemeColors(theme);
  }

  void _setThemeColors(String theme) {
    setState(() {
      _currentThemeName = theme;
      switch (theme) {
        case 'Sunset Pink':
          _bubbleGradient = [Colors.pinkAccent, Colors.orangeAccent];
          break;
        case 'Neon Purple':
          _bubbleGradient = [Colors.purpleAccent, Colors.indigoAccent];
          break;
        case 'Ocean Breeze':
          _bubbleGradient = [Colors.blueAccent, Colors.tealAccent];
          break;
        case 'Midnight Dark':
          _bubbleGradient = [const Color(0xFF2C3E50), const Color(0xFF000000)];
          break;
        case 'Forest Green':
          _bubbleGradient = [const Color(0xFF27AE60), const Color(0xFF2ECC71)];
          break;
        case 'Ruby Red':
          _bubbleGradient = [const Color(0xFFE74C3C), const Color(0xFFC0392B)];
          break;
        case 'Gold':
          _bubbleGradient = [const Color(0xFFF39C12), const Color(0xFFD4AC0D)];
          break;
        case 'Lavender':
          _bubbleGradient = [const Color(0xFF9B59B6), const Color(0xFFBB8FCE)];
          break;
        case 'Crimson':
          _bubbleGradient = [const Color(0xFFC0392B), const Color(0xFF922B21)];
          break;
        case 'Classic Orange':
        default:
          _bubbleGradient = [AppTheme.primaryOrange, AppTheme.deepOrange];
          break;
      }
    });
  }

  void _changeChatTheme(String theme) async {
    _setThemeColors(theme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_theme_${widget.chatId}', theme);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    setState(() {}); // Trigger rebuild to update Send/Mic button
    if (value.trim().isEmpty) {
      if (_isTyping) {
        _isTyping = false;
        _updateTypingStatus(false);
      }
      return;
    }

    if (!_isTyping) {
      _isTyping = true;
      _updateTypingStatus(true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        _updateTypingStatus(false);
      }
    });
  }

  void _updateTypingStatus(bool isTyping) {
    final currentUserId = context.read<AuthProvider>().user?.uid;
    if (currentUserId != null) {
      FirebaseDataService.instance.setTypingStatus(widget.chatId, currentUserId, isTyping);
    }
  }

  void _sendMessage() async {
    _typingTimer?.cancel(); // Cancel timer
    if (_isTyping) {
       _isTyping = false;
       _updateTypingStatus(false); // Immediate stop typing
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    final currentUserId = context.read<AuthProvider>().user?.uid ?? '';
    final replyId = _replyMessageId;
    final replyText = _replyMessage?['text'] ?? (_replyMessage?['type'] == 'image' ? '📷 Image' : (_replyMessage?['type'] == 'audio' ? '🎤 Voice Message' : null));
    
    setState(() {
      _replyMessage = null;
      _replyMessageId = null;
    });

    HapticFeedback.lightImpact();

    await FirebaseDataService.instance.sendMessage(
      widget.chatId,
      text,
      currentUserId,
      replyToId: replyId,
      replyToText: replyText,
    );
     // Scroll to bottom
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, // Reversed list
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showMessageActions(Map<String, dynamic> message, String docId, bool isMe) {
    if (message['isDeleted'] == true) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              ListTile(
                leading: Icon(Icons.copy_rounded, color: Colors.grey),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: message['text'] ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
              if (isMe)
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    // Confirm delete
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Message?'),
                        content: const Text('This message will be removed for everyone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              FirebaseDataService.instance.deleteMessage(widget.chatId, docId);
                            },
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }



  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
      
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        _uploadAndSendImage(pickedFile.path, bytes: bytes);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _uploadAndSendImage(String path, {Uint8List? bytes}) async {
    final currentUserId = context.read<AuthProvider>().user?.uid;
    if (currentUserId == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sending image...')),
    );

    final imageUrl = await FirebaseDataService.instance.uploadChatImage(path, bytes: bytes);
    
    if (imageUrl != null) {
      await FirebaseDataService.instance.sendMessage(
        widget.chatId,
        '', 
        currentUserId,
        type: 'image',
        imageUrl: imageUrl,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload image')),
      );
    }
  }

  Widget _buildImageMessage(String? imageUrl, {bool isMe = false}) {
    final bubbleColor = isMe ? Colors.white : Color(0xFFF2F2F2);

    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 200.w,
        height: 150.h,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(Icons.broken_image, color: Colors.grey, size: 40.sp),
      );
    }

    final isDataUrl = imageUrl.trim().startsWith('data:');
    final ImageProvider imageProvider = isDataUrl
        ? MemoryImage(base64Decode(imageUrl.split(',').last.trim()))
        : NetworkImage(imageUrl) as ImageProvider;

    return Container(
      width: 200.w,
      constraints: BoxConstraints(maxHeight: 200.h),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Image(
          image: imageProvider,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 200.w,
              height: 150.h,
              color: Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryOrange,
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 200.w,
              height: 150.h,
              color: Colors.grey[300],
              child: Icon(Icons.broken_image, color: Colors.grey, size: 40.sp),
            );
          },
        ),
      ),
    );
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Text(
                  'Chat Settings',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.palette_outlined, color: AppTheme.primaryOrange),
                title: const Text('Change Chat Theme'),
                subtitle: Text('Current: $_currentThemeName'),
                onTap: () {
                  Navigator.pop(context);
                  _showThemeSelector();
                },
              ),
              ListTile(
                leading: const Icon(Icons.search_rounded, color: Colors.blue),
                title: const Text('Search Conversation'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _isSearching = true;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
                title: const Text('Clear Chat History'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmClearChat();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        final themes = [
          'Classic Orange', 'Sunset Pink', 'Neon Purple', 'Ocean Breeze', 
          'Midnight Dark', 'Forest Green', 'Ruby Red', 'Gold', 'Lavender', 'Crimson'
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Text(
                  'Choose Theme',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: themes.map((themeName) {
                    return ListTile(
                      title: Text(themeName),
                      trailing: _currentThemeName == themeName
                          ? Icon(Icons.check_circle, color: AppTheme.primaryOrange)
                          : null,
                      onTap: () {
                        _changeChatTheme(themeName);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat?'),
        content: const Text('This will delete all messages in this conversation for you. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FirebaseDataService.instance.clearChatMessages(widget.chatId);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().user?.uid ?? '';
    
    // Aesthetic: "ScorePartner" White Theme / Clean / Wood Accents
    // Background: White with ScorePartner Logo Watermark.
    // Bubbles: White (Received) vs Wood Brown (Sent).
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        title: _isSearching
            ? TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.black, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Search messages...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
              )
            : FutureBuilder<UserModel?>(
                future: FirebaseDataService.instance.getUserById(widget.otherUserId),
                builder: (context, userSnapshot) {
                  final user = userSnapshot.data;
                  final imageUrl = user?.profileImageUrl ?? '';
                  
                  ImageProvider? imgProvider;
                  if (imageUrl.isNotEmpty) {
                    if (imageUrl.trim().startsWith('data:')) {
                      try {
                        final base64Str = imageUrl.split(',').last.trim();
                        imgProvider = MemoryImage(base64Decode(base64Str));
                      } catch (_) {}
                    } else {
                      imgProvider = NetworkImage(imageUrl);
                    }
                  }

                  return GestureDetector(
                    onTap: () {
                      if (user != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlayerProfileScreen(player: user),
                          ),
                        );
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.primaryOrange, width: 1.5.w),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFEEEEEE),
                            backgroundImage: imgProvider,
                            child: imgProvider == null
                                ? Text(
                                    widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?',
                                    style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold, fontSize: 14.sp),
                                  )
                                : null,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.otherUserName,
                              style: TextStyle(
                                color: Colors.black, // Dark text on white
                                fontWeight: FontWeight.bold,
                                fontSize: 16.sp,
                                letterSpacing: 0.5,
                              ),
                            ),
                            StreamBuilder<bool>(
                              stream: _userPresenceStream,
                              builder: (context, snapshot) {
                                final isOnline = snapshot.data ?? false;
                                return Text(
                                  isOnline ? 'Online' : 'Offline',
                                  style: TextStyle(
                                    color: isOnline ? AppTheme.primaryOrange : Colors.grey,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showChatOptions,
            ),
        ],
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
          // Background Logo Watermark (Shield Style)
          Center(
            child: Opacity(
              opacity: 0.08, // Slightly stronger opacity for detail
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
                        child: Icon(Icons.star, size: 24.sp, color: AppTheme.primaryOrange),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'SCOREPARTNER',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w900, // Extra Bold
                      color: Colors.grey[400],
                      letterSpacing: 4.0, // Wide spacing
                    ),
                  ),
                  Text(
                    'OFFICIAL CHAT',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryOrange,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.sports_cricket, size: 32.sp, color: AppTheme.primaryOrange),
                                  SizedBox(height: 12.h),
                                  Text(
                                    'Start the match with\n${widget.otherUserName}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    var messages = snapshot.data!.docs;

                    if (_searchQuery.isNotEmpty) {
                      messages = messages.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final text = (data['text'] ?? '').toString().toLowerCase();
                        return text.contains(_searchQuery);
                      }).toList();
                    }

                    // Mark messages as read when they are loaded
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _markAsRead();
                    });

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final docId = messages[index].id;
                          final data = messages[index].data() as Map<String, dynamic>;
          final isMe = data['senderId'] == currentUserId;
          final isDeleted = data['isDeleted'] == true;
          final isImage = !isDeleted && data['type'] == 'image';
                          
                          return Dismissible(
                            key: ValueKey(docId),
                            direction: DismissDirection.startToEnd,
                            confirmDismiss: (direction) async {
                              setState(() {
                                _replyMessageId = docId;
                                _replyMessage = data;
                              });
                              HapticFeedback.lightImpact();
                              return false; // Don't actually dismiss
                            },
                            child: GestureDetector(
                              onLongPress: () => _showMessageActions(data, docId, isMe),
                              onDoubleTap: () {
                                if (isDeleted) return;
                                HapticFeedback.heavyImpact();
                                FirebaseDataService.instance.reactToMessage(widget.chatId, docId, currentUserId, '❤️');
                              },
                               child: Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      margin: EdgeInsets.only(bottom: 4.h),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isImage ? 0 : 12.w,
                                        vertical: isImage ? 0 : 8.h,
                                      ),
                                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(20),
                                          topRight: Radius.circular(20),
                                          bottomLeft: isMe ? Radius.circular(20) : Radius.circular(4),
                                          bottomRight: isMe ? Radius.circular(4) : Radius.circular(20),
                                        ),
                                        gradient: isImage || isDeleted
                                            ? null
                                            : (isMe ? LinearGradient(colors: _bubbleGradient, begin: Alignment.topLeft, end: Alignment.bottomRight) : LinearGradient(colors: [Color(0xFFF2F2F2), Color(0xFFE0E0E0)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                                        color: isDeleted
                                            ? Colors.grey[200]
                                            : (isImage ? (isMe ? Colors.white : Color(0xFFF2F2F2)) : null),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 1,
                                            offset: Offset(0, 1),
                                          )
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (data['replyToText'] != null && !isDeleted)
                                            Container(
                                              margin: EdgeInsets.only(bottom: 6.h),
                                              padding: EdgeInsets.all(8.w),
                                              decoration: BoxDecoration(
                                                color: isMe ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.05),
                                                borderRadius: BorderRadius.circular(8.r),
                                                border: Border(left: BorderSide(color: isMe ? Colors.white : AppTheme.primaryOrange, width: 3)),
                                              ),
                                              child: Text(
                                                data['replyToText'],
                                                style: TextStyle(
                                                  fontSize: 11.sp,
                                                  color: isMe ? Colors.white70 : Colors.black54,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          if (isDeleted)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.block, color: Colors.grey, size: 14.sp),
                                                SizedBox(width: 6.w),
                                                Text(
                                                  'Dead ball! (Message deleted)',
                                                  style: TextStyle(
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.grey,
                                                    fontSize: 13.sp,
                                                  ),
                                                ),
                                              ],
                                            )
                                          else if (data['type'] == 'image')
                                            _buildImageMessage(data['imageUrl'], isMe: isMe)
                                          else if (data['type'] == 'audio')
                                            VoiceMessagePlayer(
                                              audioUrl: data['audioUrl'] ?? '',
                                              duration: (data['duration'] as num? ?? 0).toInt(),
                                              isMe: isMe,
                                            )
                                          else
                                            Text(
                                              data['text'] ?? '',
                                              style: TextStyle(
                                                color: isMe ? Colors.white : Colors.black87,
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          SizedBox(height: 2.h),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _formatTime(data['timestamp']),
                                                style: TextStyle(
                                                  color: isMe ? Colors.white70 : Colors.grey[600],
                                                  fontSize: 10.sp,
                                                ),
                                              ),
                                              if (isMe && !isDeleted) ...[
                                                SizedBox(width: 4.w),
                                                Icon(
                                                  (data['isRead'] == true) ? Icons.sports_cricket : Icons.sports_baseball, // Bat for read, Ball for sent
                                                  size: 14.sp,
                                                  color: (data['isRead'] == true) ? Colors.blue : Colors.white70, 
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (data['reactions'] != null && (data['reactions'] as Map).isNotEmpty)
                                      Positioned(
                                        bottom: -4.h,
                                        right: isMe ? null : -8.w,
                                        left: isMe ? -8.w : null,
                                        child: Container(
                                          padding: EdgeInsets.all(4.w),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 4,
                                              )
                                            ],
                                          ),
                                          child: Text(
                                            (data['reactions'] as Map).values.first.toString(),
                                            style: TextStyle(fontSize: 12.sp),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                  },
                ),
              ),
              
              // Typing Indicator Bubble
              StreamBuilder<DocumentSnapshot>(
                stream: _chatStream,
                builder: (context, chatSnapshot) {
                  if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                    final data = chatSnapshot.data!.data() as Map<String, dynamic>?;
                    final typingUsers = List<String>.from(data?['typingUsers'] ?? []);
                    if (typingUsers.contains(widget.otherUserId)) {
                      return Padding(
                        padding: EdgeInsets.only(left: 16.w, bottom: 8.h),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(20.r),
                                topRight: Radius.circular(20.r),
                                bottomRight: Radius.circular(20.r),
                                bottomLeft: Radius.circular(4.r),
                              ),
                            ),
                            child: TypingIndicator(dotColor: Colors.grey[600]!, dotSize: 6.0),
                          ),
                        ),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
              
              // Input Bar
              // Reply Panel (Above Input)
              if (_replyMessage != null)
                Container(
                  color: Colors.grey[50],
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Row(
                    children: [
                      Container(
                        width: 4.w,
                        height: 40.h,
                        color: AppTheme.primaryOrange,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Replying to...', style: TextStyle(color: AppTheme.primaryOrange, fontSize: 12.sp, fontWeight: FontWeight.bold)),
                            Text(
                              _replyMessage?['text'] ?? (_replyMessage?['type'] == 'image' ? '📷 Image' : '🎤 Voice Message'),
                              style: TextStyle(color: Colors.black87, fontSize: 13.sp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 20.sp, color: Colors.grey),
                        onPressed: () => setState(() {
                          _replyMessage = null;
                          _replyMessageId = null;
                        }),
                      )
                    ],
                  ),
                ),


              // Input Bar
              Container(
                margin: EdgeInsets.only(left: 16.w, right: 16.w, top: 8.h, bottom: 24.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.all(12.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Text Field area
                        TextField(
                          controller: _messageController,
                          onChanged: _onTextChanged,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 4,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: 'Message...',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16.sp,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                            isDense: true,
                          ),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        SizedBox(height: 12.h),
                        // Bottom Row Actions
                        Row(
                          children: [
                            // Plus Button
                            GestureDetector(
                              onTap: () => _pickImage(ImageSource.gallery),
                              child: Container(
                                width: 44.w,
                                height: 44.w,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF3F2EE),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.add, color: Colors.black87, size: 24.sp),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            // Pill Button
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F2EE),
                                borderRadius: BorderRadius.circular(24.r),
                              ),
                              child: Text(
                                'ScorePartner Chat',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Send/Action Button
                            GestureDetector(
                              onTap: _messageController.text.trim().isNotEmpty ? _sendMessage : null,
                              child: Container(
                                width: 44.w,
                                height: 44.w,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF3F2EE),
                                  shape: BoxShape.circle,
                                ),
                                child: _messageController.text.trim().isNotEmpty 
                                    ? Padding(
                                        padding: EdgeInsets.only(left: 4.w), // Slight left padding to center the paper airplane visually
                                        child: Icon(
                                          Icons.send_rounded,
                                          color: Colors.black87,
                                          size: 20.sp,
                                        ),
                                      )
                                    : Center(
                                        child: Container(
                                          width: 14.sp,
                                          height: 14.sp,
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.black87, width: 2),
                                            borderRadius: BorderRadius.circular(4.r),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    
    // Format: 10:30 PM
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void _markAsRead() {
    final currentUserId = context.read<AuthProvider>().user?.uid;
    // Only mark if we are viewing the chat
    if (currentUserId != null && mounted) {
      FirebaseDataService.instance.markMessagesAsRead(widget.chatId, currentUserId);
    }
  }
}
