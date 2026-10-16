import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final int? receiverId;
  final String? receiverName;

  const ChatScreen({super.key, this.receiverId, this.receiverName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading  = true;
  bool _isSending = false;
  int? _replyToId;
  String? _replyToText;
  String? _replyToName;
  Timer? _pollTimer;
  late int _myId;

  static const _green    = Color(0xFF00a884);
  static const _bubbleMe = Color(0xFF005c4b);
  static const _bubbleYou = Color(0xFF1f2c33);

  @override
  void initState() {
    super.initState();
    _myId = context.read<AppProvider>().user?.id ?? 0;
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _pollMessages());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (widget.receiverId == null) return;
    setState(() => _loading = true);
    final msgs = await ApiService.getConversationMessages(widget.receiverId!);
    if (!mounted) return;
    setState(() {
      _messages = msgs.cast<Map<String, dynamic>>();
      _loading = false;
    });
    _scrollToBottom();
  }

  Future<void> _pollMessages() async {
    if (widget.receiverId == null || !mounted) return;
    final msgs = await ApiService.getConversationMessages(widget.receiverId!);
    if (!mounted) return;
    final newList = msgs.cast<Map<String, dynamic>>();
    if (newList.length != _messages.length) {
      setState(() => _messages = newList);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Envoyer texte ────────────────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || widget.receiverId == null || _isSending) return;

    setState(() => _isSending = true);
    _msgCtrl.clear();

    final result = await ApiService.sendMessage(
      receiverId: widget.receiverId!,
      content: text,
      replyToId: _replyToId,
    );

    if (!mounted) return;
    if (result != null) {
      setState(() {
        _messages.add(result);
        _replyToId   = null;
        _replyToText = null;
        _replyToName = null;
        _isSending   = false;
      });
      _scrollToBottom();
    } else {
      setState(() => _isSending = false);
    }
  }

  // ── Actions sur un message ───────────────────────────────────────────────
  void _showMsgOptions(Map<String, dynamic> msg) {
    final isMine = (msg['senderId'] as int?) == _myId;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1f2c33),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '👏']
                    .map((e) => GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _reactToMessage(msg['id'] as int, e);
                          },
                          child: Text(e, style: const TextStyle(fontSize: 28)),
                        ))
                    .toList(),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            _optionTile(Icons.reply, 'Répondre', () {
              Navigator.pop(context);
              _setReply(msg);
            }),
            _optionTile(Icons.copy, 'Copier', () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: msg['content'] as String? ?? ''));
            }),
            _optionTile(Icons.forward, 'Transférer', () {
              Navigator.pop(context);
              _forwardMsg(msg['id'] as int);
            }),
            if (isMine)
              _optionTile(Icons.edit, 'Modifier', () {
                Navigator.pop(context);
                _editMsg(msg);
              }),
            _optionTile(Icons.delete_outline, 'Supprimer', () {
              Navigator.pop(context);
              _deleteMsg(msg['id'] as int, isMine);
            }, color: Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white70, size: 20),
      title: Text(label,
          style: TextStyle(color: color ?? Colors.white, fontSize: 15)),
      onTap: onTap,
    );
  }

  void _setReply(Map<String, dynamic> msg) {
    setState(() {
      _replyToId   = msg['id'] as int?;
      _replyToText = (msg['content'] ?? msg['text'] ?? '') as String;
      _replyToName = (msg['senderId'] as int?) == _myId
          ? 'Vous'
          : (widget.receiverName ?? '');
    });
  }

  Future<void> _reactToMessage(int msgId, String emoji) async {
    await ApiService.reactToMessage(msgId, emoji);
    _loadMessages();
  }

  Future<void> _deleteMsg(int msgId, bool isMine) async {
    bool forAll = false;
    if (isMine) {
      forAll = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF1f2c33),
              title: const Text('Supprimer le message',
                  style: TextStyle(color: Colors.white)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Pour moi',
                        style: TextStyle(color: Colors.white70))),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Pour tous',
                        style: TextStyle(color: Colors.redAccent))),
              ],
            ),
          ) ??
          false;
    }
    await ApiService.deleteMessage(msgId, forAll: forAll);
    if (mounted) {
      setState(() => _messages.removeWhere((m) => m['id'] == msgId));
    }
  }

  void _editMsg(Map<String, dynamic> msg) {
    final ctrl =
        TextEditingController(text: msg['content'] as String? ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1f2c33),
        title:
            const Text('Modifier', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white38))),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await ApiService.editMessage(
                  msg['id'] as int, ctrl.text);
              if (ok && mounted) _loadMessages();
            },
            child:
                const Text('Sauvegarder', style: TextStyle(color: _green)),
          ),
        ],
      ),
    );
  }

  void _forwardMsg(int msgId) {
    showDialog(
      context: context,
      builder: (_) {
        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1f2c33),
          title: const Text('Transférer à',
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'ID utilisateur',
              hintStyle: TextStyle(color: Colors.white38),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white38)),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler',
                    style: TextStyle(color: Colors.white54))),
            TextButton(
              onPressed: () async {
                final id = int.tryParse(ctrl.text);
                Navigator.pop(context);
                if (id != null) {
                  final ok =
                      await ApiService.forwardMessage(msgId, [id]);
                  if (ok && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Message transféré !')));
                  }
                }
              },
              child: const Text('Transférer',
                  style: TextStyle(color: _green)),
            ),
          ],
        );
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final name = widget.receiverName ?? 'Discussion';
    final hasText = _msgCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0b1014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF202c33),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _green,
              radius: 20,
              child: Text(name[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const Text('en ligne',
                    style: TextStyle(color: _green, fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.phone, color: Colors.white),
              onPressed: () => _startCall('audio')),
          IconButton(
              icon: const Icon(Icons.videocam, color: Colors.white),
              onPressed: () => _startCall('video')),
          IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _green))
                : _messages.isEmpty
                    ? const Center(
                        child: Text('Démarrez la conversation',
                            style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) =>
                            _buildBubble(_messages[i]),
                      ),
          ),

          // Reply preview
          if (_replyToId != null)
            Container(
              color: const Color(0xFF1f2c33),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                      width: 3, height: 40, color: _green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_replyToName ?? '',
                            style: const TextStyle(
                                color: _green,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        Text(_replyToText ?? '',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _replyToId   = null;
                      _replyToText = null;
                      _replyToName = null;
                    }),
                    child: const Icon(Icons.close,
                        color: Colors.white38, size: 20),
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            color: const Color(0xFF1f2c33),
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 6),
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined,
                          color: Colors.white54),
                      onPressed: () {}),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                          color: const Color(0xFF2a3942),
                          borderRadius: BorderRadius.circular(24)),
                      child: TextField(
                        controller: _msgCtrl,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 5,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'Message...',
                          hintStyle:
                              TextStyle(color: Colors.white38),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          border: InputBorder.none,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: hasText
                        ? (_isSending ? null : _sendMessage)
                        : null,
                    child: CircleAvatar(
                      backgroundColor: _green,
                      radius: 24,
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : Icon(
                              hasText ? Icons.send : Icons.mic,
                              color: Colors.white,
                              size: 22),
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

  // ── Bubble builder ───────────────────────────────────────────────────────
  Widget _buildBubble(Map<String, dynamic> msg) {
    final isMine    = (msg['senderId'] as int?) == _myId;
    final content   = (msg['content'] ?? msg['text'] ?? '') as String;
    final type      = (msg['type'] ?? 'text') as String;
    final isDeleted = msg['deleted'] == true;
    final isEdited  = msg['isEdited'] == true;
    final status    = (msg['status'] ?? 'sent') as String;
    final reactions = (msg['reactions'] as Map<String, dynamic>?) ?? {};
    final replyTo   = msg['replyTo'] as Map<String, dynamic>?;
    final ts        = _formatTs(msg['createdAt'] as String?);

    return GestureDetector(
      onLongPress: () => _showMsgOptions(msg),
      child: Align(
        alignment:
            isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isMine ? _bubbleMe : _bubbleYou,
                  borderRadius: BorderRadius.only(
                    topLeft:
                        Radius.circular(isMine ? 12 : 0),
                    topRight:
                        Radius.circular(isMine ? 0 : 12),
                    bottomLeft: const Radius.circular(12),
                    bottomRight: const Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reply snippet
                    if (replyTo != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(6),
                          border: const Border(
                              left: BorderSide(
                                  color: _green, width: 3)),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                                replyTo['senderName']
                                        as String? ??
                                    '',
                                style: const TextStyle(
                                    color: _green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            Text(
                                _replyPreview(replyTo),
                                style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),

                    // Content
                    if (isDeleted)
                      const Text('🚫 Message supprimé',
                          style: TextStyle(
                              color: Colors.white38,
                              fontStyle: FontStyle.italic,
                              fontSize: 13))
                    else if (type == 'call')
                      _callWidget(msg)
                    else if (type == 'image' || type == 'video')
                      _mediaWidget(msg)
                    else if (type == 'voice' || type == 'audio')
                      _voiceWidget(msg)
                    else if (type == 'file')
                      _fileWidget(msg)
                    else
                      SelectableText(content,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15)),

                    if (isEdited && !isDeleted)
                      const Text(' modifié',
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontStyle: FontStyle.italic)),

                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(ts,
                            style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11)),
                        if (isMine) ...[
                          const SizedBox(width: 4),
                          _statusIcon(status),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Reactions
              if (reactions.isNotEmpty)
                Wrap(
                  children: reactions.entries.map((e) {
                    final count =
                        (e.value as List?)?.length ?? 0;
                    return GestureDetector(
                      onTap: () => _reactToMessage(
                          msg['id'] as int, e.key),
                      child: Container(
                        margin: const EdgeInsets.only(
                            top: 2, right: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius:
                                BorderRadius.circular(99)),
                        child: Text('${e.key} $count',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70)),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'read':
        return const Icon(Icons.done_all, size: 14,
            color: Color(0xFF53bdeb));
      case 'delivered':
        return const Icon(Icons.done_all, size: 14,
            color: Colors.white38);
      default:
        return const Icon(Icons.done, size: 14,
            color: Colors.white38);
    }
  }

  Widget _callWidget(Map<String, dynamic> msg) {
    final callType   = msg['callType'] as String? ?? 'audio';
    final callStatus = msg['callStatus'] as String? ?? 'missed';
    final dur        = msg['callDuration'] as int?;
    final missed     = callStatus == 'missed';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          missed
              ? Icons.phone_missed
              : (callType == 'video'
                  ? Icons.videocam
                  : Icons.phone),
          color: missed ? Colors.redAccent : Colors.greenAccent,
          size: 20,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              callType == 'video' ? 'Appel vidéo' : 'Appel audio',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            if (missed)
              const Text('Manqué',
                  style: TextStyle(
                      color: Colors.redAccent, fontSize: 12))
            else if (dur != null)
              Text(_durStr(dur),
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _mediaWidget(Map<String, dynamic> msg) {
    final url = msg['attachmentUrl'] as String? ?? '';
    if (url.isEmpty) {
      return const Text('📷 Image',
          style: TextStyle(color: Colors.white70));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(url,
          width: 240,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Text('📷 Image',
              style: TextStyle(color: Colors.white70))),
    );
  }

  Widget _voiceWidget(Map<String, dynamic> msg) {
    final dur = msg['voiceDuration'] as int?;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mic, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Container(
            width: 80, height: 3, color: Colors.white24),
        const SizedBox(width: 8),
        Text(
          dur != null ? _durStr(dur) : '0:00',
          style: const TextStyle(
              color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }

  Widget _fileWidget(Map<String, dynamic> msg) {
    final name = msg['attachmentName'] as String? ?? 'Fichier';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.insert_drive_file,
            color: Colors.white70),
        const SizedBox(width: 8),
        Flexible(
          child: Text(name,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  String _replyPreview(Map<String, dynamic> r) {
    final t = r['type'] as String? ?? 'text';
    if (t == 'image') return '📷 Photo';
    if (t == 'voice') return '🎤 Message vocal';
    return (r['content'] ?? '') as String;
  }

  String _formatTs(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _durStr(int sec) {
    final m = sec ~/ 60, s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _startCall(String type) async {
    if (widget.receiverId == null) return;
    await ApiService.logCall(
        receiverId: widget.receiverId!,
        callType: type,
        status: 'missed');

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CallOverlay(
        name: widget.receiverName ?? '',
        type: type,
        onEnd: () {
          Navigator.pop(context);
          _loadMessages();
        },
      ),
    );
  }
}

// ── Overlay appel ──────────────────────────────────────────────────────────
class _CallOverlay extends StatefulWidget {
  final String name;
  final String type;
  final VoidCallback onEnd;

  const _CallOverlay(
      {required this.name,
      required this.type,
      required this.onEnd});

  @override
  State<_CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<_CallOverlay> {
  Timer? _timer;
  int _sec = 0;
  bool _connected = false;
  bool _isMuted   = false;

  static const _green = Color(0xFF00a884);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _connected = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _sec++);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timerText {
    final m = _sec ~/ 60, s = _sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0b1014),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: _green,
              radius: 55,
              child: Text(
                widget.name.isNotEmpty
                    ? widget.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    fontSize: 40,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            Text(widget.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _connected
                  ? _timerText
                  : (widget.type == 'video'
                      ? 'Appel vidéo…'
                      : 'Appel audio…'),
              style: TextStyle(
                  color: _connected ? _green : Colors.white54,
                  fontSize: 16),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _btn(
                  _isMuted ? Icons.mic : Icons.mic_off,
                  'Muet',
                  Colors.grey.shade800,
                  () => setState(() => _isMuted = !_isMuted),
                ),
                const SizedBox(width: 24),
                _btn(Icons.call_end, '', Colors.red, widget.onEnd,
                    radius: 35),
                const SizedBox(width: 24),
                _btn(Icons.volume_up, 'Haut-p.',
                    Colors.grey.shade800, () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(IconData icon, String label, Color color,
      VoidCallback onTap,
      {double radius = 28}) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
              backgroundColor: color,
              radius: radius,
              child: Icon(icon,
                  color: Colors.white, size: radius * 0.8)),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 11)),
        ],
      ],
    );
  }
}
