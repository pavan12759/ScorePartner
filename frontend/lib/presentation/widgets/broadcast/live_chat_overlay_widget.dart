import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/chat_message_model.dart';
import '../../../core/broadcast/overlay_theme_data.dart';

/// Live chat overlay panel — semi-transparent chat messages 
/// with pinned message, emoji/GIF support, moderator badges.
class LiveChatOverlayWidget extends StatefulWidget {
  final List<LiveChatMessage> messages;
  final LiveChatMessage? pinnedMessage;
  final bool chatEnabled;
  final bool isSlowMode;
  final Function(String)? onSendMessage;
  final Function(String)? onDeleteMessage;
  final Function(String)? onPinMessage;
  final Function(String)? onMuteUser;
  final bool isModerator;
  final OverlayThemeData theme;

  const LiveChatOverlayWidget({
    super.key,
    required this.messages,
    this.pinnedMessage,
    this.chatEnabled = true,
    this.isSlowMode = false,
    this.onSendMessage,
    this.onDeleteMessage,
    this.onPinMessage,
    this.onMuteUser,
    this.isModerator = false,
    required this.theme,
  });

  @override
  State<LiveChatOverlayWidget> createState() => _LiveChatOverlayWidgetState();
}

class _LiveChatOverlayWidgetState extends State<LiveChatOverlayWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _expanded = false;

  @override
  void didUpdateWidget(LiveChatOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll to bottom when new messages arrive
    if (widget.messages.length > oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      height: _expanded ? 350.h : 200.h,
      decoration: BoxDecoration(
        color: widget.theme.backgroundColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(widget.theme.cornerRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),
          // Pinned message
          if (widget.pinnedMessage != null) _buildPinnedMessage(),
          // Messages
          Expanded(child: _buildMessageList()),
          // Input
          if (widget.chatEnabled) _buildInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.chat_bubble_outline, color: widget.theme.highlightColor, size: 14.sp),
            SizedBox(width: 6.w),
            Text(
              'LIVE CHAT',
              style: TextStyle(
                color: widget.theme.textColor,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: widget.theme.highlightColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${widget.messages.length}',
                style: TextStyle(
                  color: widget.theme.highlightColor,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            if (widget.isSlowMode)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🐌 Slow',
                  style: TextStyle(fontSize: 8.sp, color: const Color(0xFFFF9800)),
                ),
              ),
            SizedBox(width: 4.w),
            Icon(
              _expanded ? Icons.expand_more : Icons.expand_less,
              color: widget.theme.textColor.withOpacity(0.5),
              size: 16.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedMessage() {
    final msg = widget.pinnedMessage!;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: widget.theme.highlightColor.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: widget.theme.highlightColor.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.push_pin, color: widget.theme.highlightColor, size: 12.sp),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              '${msg.userName}: ${msg.message}',
              style: TextStyle(
                color: widget.theme.textColor,
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (widget.messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet. Say hello! 👋',
          style: TextStyle(
            color: widget.theme.textColor.withOpacity(0.4),
            fontSize: 11.sp,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      itemCount: widget.messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(widget.messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(LiveChatMessage msg) {
    return GestureDetector(
      onLongPress: widget.isModerator
          ? () => _showModeratorMenu(msg)
          : null,
      child: Padding(
        padding: EdgeInsets.only(bottom: 4.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 10.r,
              backgroundColor: widget.theme.highlightColor.withOpacity(0.3),
              backgroundImage: msg.userAvatar != null ? NetworkImage(msg.userAvatar!) : null,
              child: msg.userAvatar == null
                  ? Text(
                      msg.userName.isNotEmpty ? msg.userName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: widget.theme.textColor,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 6.w),
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    // Username
                    TextSpan(
                      text: '${msg.userName} ',
                      style: TextStyle(
                        color: msg.isModerator
                            ? widget.theme.highlightColor
                            : widget.theme.textColor.withOpacity(0.7),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    // Moderator badge
                    if (msg.isModerator)
                      WidgetSpan(
                        child: Container(
                          margin: EdgeInsets.only(right: 4.w),
                          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
                          decoration: BoxDecoration(
                            color: widget.theme.highlightColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'MOD',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 7.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    // Message
                    TextSpan(
                      text: msg.message,
                      style: TextStyle(
                        color: widget.theme.textColor.withOpacity(0.9),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 32.h,
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _messageController,
                style: TextStyle(
                  color: widget.theme.textColor,
                  fontSize: 11.sp,
                ),
                decoration: InputDecoration(
                  hintText: 'Say something...',
                  hintStyle: TextStyle(
                    color: widget.theme.textColor.withOpacity(0.3),
                    fontSize: 11.sp,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                  isDense: true,
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          SizedBox(width: 6.w),
          GestureDetector(
            onTap: () => _sendMessage(_messageController.text),
            child: Container(
              width: 32.w,
              height: 32.w,
              decoration: BoxDecoration(
                color: widget.theme.highlightColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.send, color: Colors.white, size: 14.sp),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    widget.onSendMessage?.call(text.trim());
    _messageController.clear();
  }

  void _showModeratorMenu(LiveChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.push_pin, color: Colors.amber),
              title: const Text('Pin Message', style: TextStyle(color: Colors.white)),
              onTap: () {
                widget.onPinMessage?.call(msg.id);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Message', style: TextStyle(color: Colors.white)),
              onTap: () {
                widget.onDeleteMessage?.call(msg.id);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.volume_off, color: Colors.orange),
              title: Text('Mute ${msg.userName}', style: const TextStyle(color: Colors.white)),
              onTap: () {
                widget.onMuteUser?.call(msg.userId);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
