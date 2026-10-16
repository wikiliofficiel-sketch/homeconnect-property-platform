import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_colors.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../tenant/chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late Future<List<dynamic>> _convsFuture;

  @override
  void initState() {
    super.initState();
    _convsFuture = _loadConversations();
  }

  Future<List<dynamic>> _loadConversations() async {
    final authUser = context.read<AppProvider>().user;
    if (authUser == null) return [];

    final all = await ApiService.getConversations();

    // Restriction messagerie : proprio↔admin seulement, locataire↔admin seulement
    // Seul l'admin peut voir toutes les conversations
    final myRole = (authUser.role ?? '').toLowerCase();
    if (myRole.contains('admin')) return all;

    return all.where((c) {
      final roles = (c['partner']?['roles'] as List?)?.cast<String>() ?? [];
      return roles.any((r) => r.contains('ADMIN'));
    }).toList();
  }

  void _refresh() => setState(() { _convsFuture = _loadConversations(); });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const green = Color(0xFF00a884);

    return Scaffold(
      backgroundColor: isDark ? AppColors.whatsappDarkBg : Colors.white,
      appBar: AppBar(
        title: const Text('HomeConnect Chat',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppColors.whatsappDarkBubbleOther : AppColors.whatsappDark,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _refresh),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _convsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: green));
          }
          if (!snap.hasData || snap.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  const Text('Aucune discussion', style: TextStyle(color: Colors.grey, fontSize: 18)),
                  const SizedBox(height: 8),
                  TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Actualiser')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: green,
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              itemCount: snap.data!.length,
              separatorBuilder: (_, __) => Divider(height: 1, indent: 80, color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.15)),
              itemBuilder: (context, i) {
                final conv        = snap.data![i] as Map<String, dynamic>;
                final partnerId   = conv['partnerId'] as int? ?? 0;
                final partnerName = conv['partnerName'] as String? ?? '?';
                final unread      = conv['unreadCount'] as int? ?? 0;
                final last        = conv['lastMessage'] as Map<String, dynamic>?;
                final lastContent = _msgPreview(last);
                final lastTime    = _formatTime(last?['createdAt']);
                final initials    = partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '?';

                final avatarColors = [const Color(0xFF00a884), Colors.orange, Colors.blue, Colors.purple, Colors.teal];
                final avatarColor  = avatarColors[partnerName.codeUnitAt(0) % avatarColors.length];

                return InkWell(
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ChatScreen(receiverId: partnerId, receiverName: partnerName))
                  ).then((_) => _refresh()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(backgroundColor: avatarColor, radius: 27, child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(child: Text(partnerName, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600, fontSize: 16, color: isDark ? Colors.white : Colors.black87))),
                                  Text(lastTime, style: TextStyle(fontSize: 12, color: unread > 0 ? green : Colors.grey, fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal)),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Expanded(child: Text(lastContent, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: unread > 0 ? (isDark ? Colors.white70 : Colors.black54) : Colors.grey, fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal))),
                                  if (unread > 0) ...[
                                    const SizedBox(width: 8),
                                    CircleAvatar(backgroundColor: green, radius: 10, child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: green,
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }

  String _msgPreview(Map<String, dynamic>? msg) {
    if (msg == null) return '';
    switch (msg['type'] as String? ?? 'text') {
      case 'image': return '📷 Photo';
      case 'voice': return '🎤 Message vocal';
      case 'audio': return '🎵 Audio';
      case 'call':  return '📞 Appel';
      case 'file':  return '📎 Fichier';
      default:      return (msg['content'] ?? msg['text'] ?? '') as String;
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}';
    } catch (_) { return ''; }
  }
}
