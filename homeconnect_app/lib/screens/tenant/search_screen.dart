import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/location_service.dart';
import '../../utils/app_colors.dart';
import 'chat_screen.dart';

class TenantSearchScreen extends StatefulWidget {
  const TenantSearchScreen({super.key});
  @override
  State<TenantSearchScreen> createState() => _TenantSearchScreenState();
}

class _TenantSearchScreenState extends State<TenantSearchScreen> {
  double? _userLat, _userLng;
  bool _locating = false;

  Future<void> _initLocation() async {
    setState(() => _locating = true);
    final pos = await LocationService.getCurrentPosition();
    if (pos != null) {
      _userLat = pos.latitude; _userLng = pos.longitude;
    }
    setState(() => _locating = false);
  }

  @override
  void initState() { super.initState(); _initLocation(); }

  @override
  Widget build(BuildContext context) {
    final props = context.watch<AppProvider>().properties;
    final filtered = _userLat != null
        ? props.where((p) {
            if (p.latitude == null || p.longitude == null) return true;
            return LocationService.distance(_userLat!, _userLng!, p.latitude!, p.longitude!) < 5000; // 5km
          }).toList()
        : props;

    return Scaffold(
      backgroundColor: AppColors.getScaffoldBackground(context),
      appBar: AppBar(title: const Text('Recherche (📍 5km)'), backgroundColor: Colors.transparent,
        actions: [IconButton(icon: const Icon(Icons.message), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())))]),
      body: _locating
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final p = filtered[i];
                return Card(
                  color: AppColors.primaryMedium,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(p.titre, style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${p.lieu} • ${p.prix} FCFA'),
                    trailing: IconButton(icon: const Icon(Icons.chat_bubble, color: AppColors.accentOrange),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(receiverId: p.proprietaireId)))),
                  ),
                );
              },
            ),
    );
  }
}