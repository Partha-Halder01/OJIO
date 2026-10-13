import '../widgets/app_notice.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../core/chat_suggestions.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/chat_unread_service.dart';
import 'login_screen.dart';

class ChatScreen extends StatefulWidget {
  final bool active;
  const ChatScreen({super.key, this.active = true});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  List<ChatThreadModel> _threads = [];
  bool _isLoading = true;
  bool _fetchingThreads = false;
  Timer? _pollingTimer;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchThreads();
    // Poll for new messages/seen status every 3 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchThreads(silent: true);
    });
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _fetchThreads(silent: true);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchThreads({bool silent = false}) async {
    if (!mounted || !widget.active || _fetchingThreads) return;
    if (silent &&
        (!(ModalRoute.of(context)?.isCurrent ?? false) ||
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused))
      return;
    if (!mounted || !AuthService().isAuthenticated) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (!silent) setState(() => _isLoading = true);
    _fetchingThreads = true;
    List<ChatThreadModel> threads;
    try {
      threads = await _api.fetchChatThreads(throwOnError: true);
    } catch (_) {
      _fetchingThreads = false;
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _fetchingThreads = false;
    if (mounted) {
      ChatUnreadService.instance.setThreads(threads);
      setState(() {
        _threads = threads;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService().currentUserId;

    // Separate chats into Buying (user is buyer) and Selling (user is seller)
    final buyingThreads = _threads.where((t) {
      final isBuyer =
          t.buyerId == currentUserId ||
          (t.sellerId != currentUserId &&
              (t.listing == null || t.listing!.userId != currentUserId));
      return isBuyer;
    }).toList();

    final sellingThreads = _threads.where((t) {
      final isSeller =
          t.sellerId == currentUserId ||
          (t.listing != null && t.listing!.userId == currentUserId);
      return isSeller;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF03172D),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF03172D),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: Text(
          'Chats',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF087CF5),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          dividerColor: Colors.white12,
          labelStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: [
            Tab(text: 'Buying (${buyingThreads.length})'),
            Tab(text: 'Selling (${sellingThreads.length})'),
          ],
        ),
      ),
      body: !AuthService().isAuthenticated
          ? Center(
              child: FilledButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Log in to chat'),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(returnToPrevious: true),
                    ),
                  );
                  if (mounted) await _fetchThreads();
                },
              ),
            )
          : _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF087CF5)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildThreadList(buyingThreads, isBuying: true),
                _buildThreadList(sellingThreads, isBuying: false),
              ],
            ),
    );
  }

  Widget _buildThreadList(
    List<ChatThreadModel> threads, {
    required bool isBuying,
  }) {
    if (threads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF087CF5).withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBuying
                      ? Icons.shopping_bag_outlined
                      : Icons.storefront_outlined,
                  size: 32,
                  color: const Color(0xFF087CF5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isBuying ? 'No Buying Chats Yet' : 'No Selling Inquiries Yet',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: const Color(0xFF071A2F),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isBuying
                    ? "When you start a chat on another user's listing, it will appear here."
                    : 'When buyers message you about your listed items, they will appear here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFF6B7785),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchThreads(),
      color: const Color(0xFF087CF5),
      child: ListView.separated(
        itemCount: threads.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 76, color: Color(0xFFE2E8F0)),
        itemBuilder: (context, index) {
          final thread = threads[index];
          final currentUserId = AuthService().currentUserId;
          final isBuyer = thread.buyerId == currentUserId;
          final otherUser = isBuyer ? thread.seller : thread.buyer;
          final otherName =
              otherUser?['name'] ?? (isBuyer ? 'Seller' : 'Buyer');
          final otherAvatar = otherUser?['avatar'];

          final itemTitle = thread.listing?.title ?? 'Listing';
          final lastMsg = thread.messages.isNotEmpty
              ? thread.messages.first
              : null;
          final lastMsgText = lastMsg?.message ?? 'No messages yet';

          String timeStr = '';
          if (lastMsg != null) {
            final now = DateTime.now();
            if (lastMsg.createdAt.day == now.day &&
                lastMsg.createdAt.month == now.month &&
                lastMsg.createdAt.year == now.year) {
              timeStr = DateFormat.jm().format(lastMsg.createdAt);
            } else {
              timeStr = DateFormat('MMM d').format(lastMsg.createdAt);
            }
          }

          final hasUnread = thread.unreadCount > 0;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.grey[200],
              backgroundImage: otherAvatar != null
                  ? NetworkImage(otherAvatar)
                  : null,
              child: otherAvatar == null
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    otherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  timeStr,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF6B7785),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: isBuying
                            ? Colors.blue.shade50
                            : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isBuying ? 'BUY' : 'SELL',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: isBuying
                              ? Colors.blue.shade700
                              : const Color(0xFF047857),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        itemTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF087CF5),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (lastMsg != null &&
                        lastMsg.senderId == currentUserId) ...[
                      Icon(
                        lastMsg.isRead ? Icons.done_all : Icons.check,
                        size: 14,
                        color: lastMsg.isRead ? Colors.blue : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        lastMsgText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: hasUnread
                              ? const Color(0xFF071A2F)
                              : const Color(0xFF6B7785),
                          fontSize: 12,
                          fontWeight: hasUnread
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: hasUnread
                ? Badge(label: Text('${thread.unreadCount}'))
                : null,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatConversationScreen(
                    threadId: thread.id,
                    listingId: thread.listingId,
                    otherUserName: otherName,
                    itemTitle: itemTitle,
                    initialThread: thread,
                  ),
                ),
              ).then((_) => _fetchThreads(silent: true));
            },
          );
        },
      ),
    );
  }
}

class ChatConversationScreen extends StatefulWidget {
  final int threadId;
  final int listingId;
  final String otherUserName;
  final String itemTitle;
  final ChatThreadModel? initialThread;
  final ApiService? api;

  const ChatConversationScreen({
    super.key,
    required this.threadId,
    required this.listingId,
    required this.otherUserName,
    required this.itemTitle,
    this.initialThread,
    this.api,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  late final ApiService _api;
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessageModel> _messages = [];
  ChatThreadModel? _thread;
  Timer? _pollingTimer;
  bool _isSending = false;
  bool _fetching = false;
  late int _threadId;
  String? _loadError;
  bool _loadingMessages = true;
  static String? _cacheSession;
  static final Map<int, ChatThreadModel> _recentThreads = {};

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiService();
    _threadId = widget.threadId;
    final session = AuthService().token;
    if (_cacheSession != session) {
      _recentThreads.clear();
      _cacheSession = session;
    }
    final initial = _recentThreads[_threadId] ?? widget.initialThread;
    final userId = AuthService().currentUserId;
    if (initial != null &&
        initial.id == _threadId &&
        userId > 0 &&
        (initial.buyerId == userId || initial.sellerId == userId)) {
      _thread = initial;
      _messages = {
        for (final message in initial.messages) message.id: message,
        if (widget.initialThread?.id == _threadId)
          for (final message in widget.initialThread!.messages)
            message.id: message,
      }.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    }
    // ModalRoute depends on inherited widgets and must not be read in initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchMessages();
    });
    // Refresh read receipts while this conversation is visible.
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _fetchMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!mounted || _fetching || _isSending || !AuthService().isAuthenticated) {
      return;
    }
    if (!(ModalRoute.of(context)?.isCurrent ?? true) ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused)
      return;
    _fetching = true;
    final session = AuthService().token;
    try {
      if (_threadId == 0) _threadId = await _api.openChat(widget.listingId);
      if (!mounted || session != AuthService().token) return;
      final thread = await _api.fetchChatMessages(_threadId);
      if (thread == null) {
        throw Exception('Unable to load messages. Please retry.');
      }
      if (mounted && session == AuthService().token) {
        final userId = AuthService().currentUserId;
        if (thread.id != _threadId ||
            (thread.buyerId != userId && thread.sellerId != userId)) {
          throw Exception('Unable to load this conversation.');
        }
        if (_cacheSession == session) {
          _recentThreads.remove(_threadId);
          _recentThreads[_threadId] = thread;
          if (_recentThreads.length > 20) {
            _recentThreads.remove(_recentThreads.keys.first);
          }
        }
        ChatUnreadService.instance.clearThread(_threadId);
        final bool shouldScrollDown =
            _messages.length != thread.messages.length;
        setState(() {
          _thread = thread;
          final messages = {
            for (final message in _messages) message.id: message,
            for (final message in thread.messages) message.id: message,
          };
          _messages = messages.values.toList()
            ..sort((a, b) => a.id.compareTo(b.id));
          _loadError = null;
          _loadingMessages = false;
        });
        if (shouldScrollDown) {
          _scrollToBottom();
        }
      }
    } catch (error) {
      if (mounted && session == AuthService().token && !silent) {
        setState(() {
          _loadError = error.toString().replaceFirst('Exception: ', '');
          _loadingMessages = false;
        });
      }
    } finally {
      _fetching = false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? suggested]) async {
    final text = (suggested ?? _msgController.text).trim();
    if (text.isEmpty || _isSending) return;
    if (text.length > 1000) {
      AppNotice.show(
        context,
        const SnackBar(
          content: Text('Messages can contain up to 1,000 characters.'),
        ),
      );
      return;
    }
    if (!AuthService().isAuthenticated) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(returnToPrevious: true),
        ),
      );
      if (!mounted || !AuthService().isAuthenticated) return;
    }

    setState(() => _isSending = true);
    final sent = await _api.sendMessage(
      widget.listingId,
      text,
      threadId: _threadId,
    );
    if (!mounted) return;
    if (sent != null && mounted) {
      setState(() {
        _threadId = sent.chatThreadId;
        if (!_messages.any((message) => message.id == sent.id)) {
          _messages.add(sent);
        }
        _isSending = false;
      });
      if (suggested == null && _msgController.text.trim() == text) {
        _msgController.clear();
      }
      _scrollToBottom();
    } else {
      setState(() => _isSending = false);
      AppNotice.show(
        context,
        const SnackBar(content: Text('Message was not sent. Please retry.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService().currentUserId;
    final suggestions = chatSuggestions(
      thread: _thread,
      currentUserId: currentUserId,
      messages: _messages,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF071A2F)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherUserName,
              style: GoogleFonts.outfit(
                color: const Color(0xFF071A2F),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              widget.itemTitle,
              style: GoogleFonts.outfit(
                color: const Color(0xFF087CF5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_loadError != null)
            MaterialBanner(
              content: Text(_loadError!),
              actions: [
                TextButton(
                  onPressed: _fetchMessages,
                  child: const Text('Retry'),
                ),
              ],
            ),
          Expanded(
            child: _messages.isEmpty && _loadingMessages
                ? const Center(
                    child: CircularProgressIndicator(
                      key: Key('chat-messages-loading'),
                    ),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Text(
                      _loadError != null
                          ? 'Messages could not be loaded. Please retry.'
                          : 'Say hello! Start the negotiation.',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF6B7785),
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.senderId == currentUserId;

                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? const Color(0xFF087CF5)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isMe
                                  ? const Radius.circular(0)
                                  : const Radius.circular(16),
                              bottomLeft: !isMe
                                  ? const Radius.circular(0)
                                  : const Radius.circular(16),
                            ),
                            border: isMe
                                ? null
                                : Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(5),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.message,
                                style: GoogleFonts.outfit(
                                  color: isMe
                                      ? Colors.white
                                      : const Color(0xFF071A2F),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat.jm().format(msg.createdAt),
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white.withAlpha(180)
                                          : const Color(0xFF94A3B8),
                                      fontSize: 10,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      msg.isRead ? Icons.done_all : Icons.check,
                                      size: 12,
                                      color: msg.isRead
                                          ? Colors.white
                                          : Colors.white.withAlpha(180),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: suggestions
                    .map(
                      (text) => ActionChip(
                        label: Text(text, style: const TextStyle(fontSize: 12)),
                        onPressed: _isSending ? null : () => _sendMessage(text),
                      ),
                    )
                    .toList(),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: InputDecoration(
                        hintText: 'Write a message...',
                        hintStyle: GoogleFonts.outfit(
                          color: const Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFF087CF5),
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _sendMessage,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(0xFF087CF5),
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
