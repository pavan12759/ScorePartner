import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ai_action_handler.dart';
import '../../../data/models/ai_models.dart';
import '../../providers/ai_provider.dart';
import '../../widgets/ai/ai_message_bubble.dart';
import '../../widgets/ai/ai_quick_prompts.dart';
import '../../widgets/ai/ai_match_card.dart';
import '../../widgets/ai/ai_player_card.dart';
import '../../widgets/ai/ai_team_card.dart';
import '../../widgets/ai/ai_tournament_card.dart';
import '../../widgets/ai/ai_news_card.dart';

/// ScorePartner AI Chat Screen
/// Full-featured AI assistant for cricket knowledge, ScorePartner data search,
/// and app navigation.
class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage(AIProvider provider) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    provider.sendMessage(text);

    // Scroll to bottom after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onQuickPrompt(AIProvider provider, String prompt) {
    _textController.text = prompt;
    _sendMessage(provider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider(
      create: (_) => AIProvider(),
      child: Consumer<AIProvider>(
        builder: (context, aiProvider, _) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.grey.shade50,
            appBar: _buildAppBar(context, aiProvider, isDark),
            body: Column(
              children: [
                // Chat messages
                Expanded(
                  child: aiProvider.hasMessages
                      ? _buildMessageList(aiProvider, isDark)
                      : SingleChildScrollView(
                          child: AIQuickPrompts(
                            onPromptTap: (prompt) =>
                                _onQuickPrompt(aiProvider, prompt),
                          ),
                        ),
                ),

                // Input area
                _buildInputArea(context, aiProvider, isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, AIProvider aiProvider, bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new,
            color: isDark ? Colors.white : Colors.black87, size: 20.sp),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryOrange,
                  AppTheme.primaryOrange.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(Icons.sports_cricket, color: Colors.white, size: 18.sp),
          ),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ScorePartner AI',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                'Your cricket assistant',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (aiProvider.hasMessages)
          IconButton(
            icon: Icon(Icons.refresh,
                color: isDark ? Colors.white54 : Colors.grey, size: 22.sp),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('New Conversation'),
                  content: const Text(
                      'Start a fresh conversation? Current chat will be cleared.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        aiProvider.clearConversation();
                        Navigator.pop(ctx);
                      },
                      child: Text('Clear',
                          style: TextStyle(color: AppTheme.primaryOrange)),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'New conversation',
          ),
        SizedBox(width: 4.w),
      ],
    );
  }

  Widget _buildMessageList(AIProvider aiProvider, bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
      itemCount: aiProvider.messages.length,
      itemBuilder: (context, index) {
        final message = aiProvider.messages[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message bubble
            AIMessageBubble(message: message),

            // Entity cards (only for assistant messages with entities)
            if (message.isAssistant && message.hasEntities)
              Padding(
                padding: EdgeInsets.only(left: 36.w),
                child: Column(
                  children: message.entities.map((entity) {
                    return _buildEntityCard(context, entity);
                  }).toList(),
                ),
              ),

            // Retry button for errors
            if (message.error != null)
              Padding(
                padding: EdgeInsets.only(left: 36.w, bottom: 8.h),
                child: TextButton.icon(
                  onPressed: () => aiProvider.retryLast(),
                  icon: Icon(Icons.refresh, size: 16.sp),
                  label: Text('Retry', style: TextStyle(fontSize: 12.sp)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryOrange,
                    padding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 6.h),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEntityCard(BuildContext context, AIEntity entity) {
    final action = AIAction(
      type: 'open_${entity.type}',
      entityId: entity.id,
      label: '',
    );

    switch (entity.type) {
      case 'match':
        return AIMatchCard(
          entity: entity,
          onTap: () => AIActionHandler.handleAction(context, action),
        );
      case 'player':
        return AIPlayerCard(
          entity: entity,
          onTap: () => AIActionHandler.handleAction(context, action),
        );
      case 'team':
        return AITeamCard(
          entity: entity,
          onTap: () => AIActionHandler.handleAction(context, action),
        );
      case 'tournament':
        return AITournamentCard(
          entity: entity,
          onTap: () => AIActionHandler.handleAction(context, action),
        );
      case 'news':
        return AINewsCard(
          entity: entity,
          onTap: () => AIActionHandler.handleAction(context, action),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInputArea(
      BuildContext context, AIProvider aiProvider, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 
          MediaQuery.of(context).padding.bottom + 8.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Text input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      maxLines: 4,
                      minLines: 1,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ask about cricket, matches, players...',
                        hintStyle: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey.shade400,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 10.h,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(aiProvider),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8.w),
          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: aiProvider.isLoading
                  ? Colors.grey.shade300
                  : AppTheme.primaryOrange,
              borderRadius: BorderRadius.circular(24.r),
              child: InkWell(
                onTap: aiProvider.isLoading
                    ? null
                    : () => _sendMessage(aiProvider),
                borderRadius: BorderRadius.circular(24.r),
                child: Container(
                  width: 44.w,
                  height: 44.w,
                  alignment: Alignment.center,
                  child: aiProvider.isLoading
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22.sp,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
