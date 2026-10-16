import 'package:flutter/material.dart';
import '../../services/database_helper.dart';
import '../../services/api_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSyncScreen extends StatefulWidget {
  const AdminSyncScreen({super.key});

  @override
  State<AdminSyncScreen> createState() => _AdminSyncScreenState();
}

class _AdminSyncScreenState extends State<AdminSyncScreen> {
  bool _isChecking = false;
  bool _isConnected = false;
  bool _isSyncing = false;
  String _statusMessage = 'Prêt pour la synchronisation';
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    setState(() {
      _isChecking = true;
      _statusMessage = 'Vérification de la connexion...';
    });

    final connected = await ApiService.checkConnectivity();

    setState(() {
      _isConnected = connected;
      _isChecking = false;
      _statusMessage = connected 
          ? 'Connecté au serveur Symfony' 
          : 'Erreur : Impossible de contacter le serveur Symfony';
    });
  }

  Future<void> _startSync() async {
    if (!_isConnected) return;

    setState(() {
      _isSyncing = true;
      _logs.add('Démarrage de la synchronisation...');
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Récupération des données locales
      final users = jsonDecode(prefs.getString('users') ?? '[]');
      final properties = jsonDecode(prefs.getString('properties') ?? '[]');

      setState(() {
        _logs.add('Extraction de ${users.length} utilisateurs et ${properties.length} biens...');
      });

      final syncData = {
        'users': users,
        'properties': properties,
      };

      // Envoi au backend
      final success = await ApiService.importBulk(syncData);

      setState(() {
        if (success) {
          _logs.add('✅ Synchronisation réussie ! Les données sont maintenant sur Symfony.');
          _statusMessage = 'Dernière synchro : ${DateTime.now().hour}:${DateTime.now().minute}';
        } else {
          _logs.add('❌ Échec de la synchronisation. Vérifiez les logs serveur.');
        }
        _isSyncing = false;
      });
    } catch (e) {
      setState(() {
        _logs.add('❌ Erreur critique : $e');
        _isSyncing = false;
      });
    }
  }

  Future<void> _downloadFromBackend() async {
    if (!_isConnected) return;

    setState(() {
      _isSyncing = true;
      _logs.add('Récupération des données depuis Symfony...');
    });

    try {
      final data = await ApiService.exportBulk();

      if (data != null) {
        final success = await DatabaseHelper().saveBulkData(data);
        setState(() {
          if (success) {
            final userCount = (data['users'] as List).length;
            final propCount = (data['properties'] as List).length;
            _logs.add('✅ $userCount utilisateurs et $propCount biens récupérés et enregistrés localement.');
            _statusMessage = 'Dernière récup : ${DateTime.now().hour}:${DateTime.now().minute}';
          } else {
            _logs.add('❌ Erreur lors de l\'enregistrement local.');
          }
        });
      } else {
        setState(() {
          _logs.add('❌ Échec de la récupération depuis le serveur.');
        });
      }
    } catch (e) {
      setState(() {
        _logs.add('❌ Erreur critique : $e');
      });
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Synchronisation Symfony'),
        backgroundColor: const Color(0xFF0A0F1D),
        foregroundColor: Colors.white,
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        color: const Color(0xFF0F172A),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: const Color(0xFF1E293B),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Icon(
                      _isConnected ? Icons.check_circle : Icons.error,
                      color: _isConnected ? Colors.green : Colors.red,
                      size: 40,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _statusMessage,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            ApiService.baseUrl,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _isChecking ? null : _checkConnectivity,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            const Text(
              'Actions de Migration',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            
            ElevatedButton.icon(
              onPressed: (_isConnected && !_isSyncing) ? _startSync : null,
              icon: _isSyncing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync),
              label: Text(_isSyncing ? 'Synchronisation en cours...' : 'Envoyer les données vers Symfony'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                disabledBackgroundColor: Colors.grey.withValues(alpha: 0.2),
              ),
            ),

            const SizedBox(height: 15),

            ElevatedButton.icon(
              onPressed: (_isConnected && !_isSyncing) ? _downloadFromBackend : null,
              icon: _isSyncing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download),
              label: Text(_isSyncing ? 'Synchronisation en cours...' : 'Récupérer les données depuis Symfony'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                disabledBackgroundColor: Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            
            const SizedBox(height: 30),
            
            const Text(
              'Journal (Logs)',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        _logs[index],
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'monospace'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
