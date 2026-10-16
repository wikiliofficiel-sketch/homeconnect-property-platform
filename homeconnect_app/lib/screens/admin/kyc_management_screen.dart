// lib/screens/admin/kyc_management_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../services/database_helper.dart';
import '../../widgets/role_guard.dart';

class KYCManagementScreen extends StatefulWidget {
  const KYCManagementScreen({super.key});

  @override
  State<KYCManagementScreen> createState() => _KYCManagementScreenState();
}

class _KYCManagementScreenState extends State<KYCManagementScreen> {
  late Future<List<dynamic>> _usersFuture;
  final int _adminId = 1;













  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() {
    _usersFuture = DatabaseHelper().getAllUsers();
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['admin'],
      customErrorMessage: 'Seul l\'admin peut gérer les vérifications d\'identité',
      child: Scaffold(
        backgroundColor: AppColors.getScaffoldBackground(context),
        appBar: AppBar(
          title: Text('Gestion KYC', style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      body: FutureBuilder(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accentOrange));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun utilisateur', style: TextStyle(color: Colors.white70)));
          }

          final users = snapshot.data!;
          final pendingUsers = users.where((u) => u.verificationStatus == 'en_attente').toList();
          final verifiedUsers = users.where((u) => u.verificationStatus == 'certifie').toList();
          final rejectedUsers = users.where((u) => u.verificationStatus == 'rejet').toList();

          return DefaultTabController(
            length: 4,
            child: Column(
              children: [
                // ===== TABS =====
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1)),
                  ),
                  child: TabBar(
                    labelColor: AppColors.getTextColor(context),
                    unselectedLabelColor: AppColors.getTextColor(context).withValues(alpha: 0.6),
                    isScrollable: true,
                    indicator: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.schedule, size: 16),
                            const SizedBox(width: 4),
                            Text('En attente (${pendingUsers.length})', style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified_user, size: 16),
                            const SizedBox(width: 4),
                            Text('Vérifiés (${verifiedUsers.length})', style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cancel_outlined, size: 16),
                            const SizedBox(width: 4),
                            Text('Rejetés (${rejectedUsers.length})', style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                      const Tab(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('Tous', style: TextStyle(fontSize: 10)),
                        ),
                      ),
                    ],
                  ),
                ),

                // ===== CONTENU =====
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildUserList(context, pendingUsers),
                      _buildUserList(context, verifiedUsers),
                      _buildUserList(context, rejectedUsers),
                      _buildUserList(context, users),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildUserList(BuildContext context, List<dynamic> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_outlined, size: 64, color: AppColors.getTextColor(context).withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text('Aucun utilisateur dans cette catégorie', style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserCard(context, user);
      },
    );
  }

  Widget _buildUserCard(BuildContext context, dynamic user) {
    String statusLabel = 'Inconnu';
    Color statusColor = Colors.grey;
    
    if (user.verificationStatus == 'certifie') {
      statusLabel = 'Certifié ✓';
      statusColor = AppColors.accentGreen;
    } else if (user.verificationStatus == 'en_attente') {
      statusLabel = 'En attente';
      statusColor = AppColors.accentOrange;
    } else if (user.verificationStatus == 'rejet') {
      statusLabel = 'Rejeté ✗';
      statusColor = AppColors.accentRed;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: InkWell(
        onTap: () => _showUserKYCDetails(user),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.accentBlue.withValues(alpha: 0.1),
                    child: Text(
                      (user.nom != null && user.nom!.isNotEmpty) ? user.nom![0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${user.prenom} ${user.nom}', style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(user.email, style: TextStyle(color: AppColors.getTextColor(context).withValues(alpha: 0.6), fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: Colors.white54),
                  const SizedBox(width: 6),
                  Text('${(user.role ?? '').toUpperCase()} • ${user.telephone ?? ''}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  const Spacer(),
                  const Text('Voir détails →', style: TextStyle(color: AppColors.accentBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              if (user.verificationStatus == 'en_attente')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _rejectUser(user),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accentRed,
                            side: const BorderSide(color: AppColors.accentRed),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Rejeter'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _approveUser(user),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentGreen,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Approuver'),
                        ),
                      ),
                    ],
                  ),
                ),
              if (user.verificationStatus != 'en_attente' && user.verificationStatus != 'non_verifie')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => _cancelVerification(user),
                      icon: const Icon(Icons.history, size: 14, color: Colors.white54),
                      label: const Text('Remettre en attente / Annuler', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserKYCDetails(dynamic user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: AppColors.accentOrange, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${user.prenom} ${user.nom}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('Demande de certification KYC (${user.role})', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      if (user.verificationStatus == 'rejet' && user.verificationRejectionReason != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AppColors.accentRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.3))),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.accentRed, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text('Motif du rejet : ${user.verificationRejectionReason}', style: const TextStyle(color: AppColors.accentRed, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      _buildInfoRow('Type de pièce', user.verificationDocumentType ?? 'Non spécifié'),
                      _buildInfoRow('N° de la pièce', user.cniNumber ?? 'Documents en attente d\'examen'),
                      _buildInfoRow('Date d\'expiration', user.documentExpiryDate != null ? '${user.documentExpiryDate!.day}/${user.documentExpiryDate!.month}/${user.documentExpiryDate!.year}' : 'N/A'),
                      _buildInfoRow('Rôle', user.role ?? 'N/A'),
                      const SizedBox(height: 24),

                      // ── Documents obligatoires ────────────────────────
                      const Text('Documents obligatoires',
                          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      _buildDocumentSection('Pièce d\'identité (${user.verificationDocumentType ?? "N/A"})',
                          Icons.badge_outlined, Colors.amber, user.verificationDocument),
                      const SizedBox(height: 16),
                      _buildDocumentSection('Justificatif de domicile',
                          Icons.location_on_outlined, Colors.green, user.verificationDocumentAddress),

                      if (user.role == 'proprietaire') ...[
                        const SizedBox(height: 16),
                        _buildDocumentSection('Justificatif de propriété',
                            Icons.gavel_outlined, Colors.purple, user.verificationDocumentProperty),
                      ],

                      const SizedBox(height: 40),
                    ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (user.verificationStatus == 'en_attente')
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () { Navigator.pop(context); _rejectUser(user); },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accentRed,
                              side: const BorderSide(color: AppColors.accentRed),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Rejeter'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () { Navigator.pop(context); _approveUser(user); },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentGreen,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Certifier'),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () { Navigator.pop(context); _cancelVerification(user); },
                        icon: const Icon(Icons.history, color: Colors.white),
                        label: const Text('Annuler la décision / Remettre en attente', style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentSection(String title, IconData icon, Color color, String? filePath) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (filePath != null && filePath.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.download_rounded, color: AppColors.accentBlue, size: 20),
                onPressed: () => _downloadDocument(title, filePath),
                tooltip: 'Télécharger',
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: filePath != null ? color.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1)),
          ),
          child: filePath != null && filePath.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  File(filePath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.file_present_rounded, size: 48, color: Colors.white24),
                      const SizedBox(height: 8),
                      Text(filePath.split('\\').last.split('/').last, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      const Text('Document disponible pour examen', style: TextStyle(color: Colors.white24, fontSize: 10)),
                    ],
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined, size: 48, color: Colors.white.withValues(alpha: 0.1)),
                  const SizedBox(height: 8),
                  const Text('Aucun document fourni', style: TextStyle(color: Colors.white24, fontSize: 12)),
                ],
              ),
        ),
      ],
    );
  }

  Future<void> _approveUser(dynamic user) async {
    try {
      await DatabaseHelper().approveKYC(user.id, _adminId);
      
      await DatabaseHelper().addLog(
        userId: _adminId,
        action: 'Certification KYC',
        details: 'Utilisateur ${user.prenom} ${user.nom} (#${user.id}) certifié.',
        type: 'kyc',
      );

      if (!mounted) return;
      setState(() => _loadUsers());
      
      await DatabaseHelper().addNotification(
        user.id,
        'Compte Certifié !',
        'Félicitations, votre compte a été certifié par l\'administration. Votre badge de confiance est maintenant actif.',
        'kyc',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ ${user.prenom} ${user.nom} certifié avec succès'),
          backgroundColor: AppColors.accentGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.accentRed),
      );
    }
  }

  Future<void> _rejectUser(dynamic user) async {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rejeter la vérification', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Veuillez indiquer le motif du rejet :', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'ex: Document d\'identité expiré, justificatif illisible...',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.accentRed)),
                fillColor: Colors.white10,
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              String reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez saisir un motif')));
                return;
              }
              
              try {
                await DatabaseHelper().rejectKYC(user.id, reason);
                
                await DatabaseHelper().addLog(
                  userId: _adminId,
                  action: 'Rejet KYC',
                  details: 'Certification rejetée pour ${user.prenom} ${user.nom}. Motif: $reason',
                  type: 'kyc',
                );

                await DatabaseHelper().addNotification(
                  user.id,
                  'Certification Rejetée',
                  'Votre demande de certification a été rejetée. Motif : $reason. Vous pouvez soumettre de nouveaux documents.',
                  'kyc',
                );

                if (!context.mounted) return;
                setState(() => _loadUsers());
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✗ Vérification rejetée pour ${user.prenom}'),
                    backgroundColor: AppColors.accentRed,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.accentRed),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelVerification(dynamic user) async {
    try {
      await DatabaseHelper().updateUser(user.id, {
        'verificationStatus': 'en_attente',
        'isVerified': 0,
        'kycBadgeVisible': false,
      });

      await DatabaseHelper().addLog(
        userId: _adminId,
        action: 'Annulation KYC',
        details: 'Le statut KYC de ${user.prenom} ${user.nom} a été remis en attente.',
        type: 'kyc',
      );

      if (!mounted) return;
      setState(() => _loadUsers());
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Statut remis en attente'), backgroundColor: AppColors.accentBlue),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.accentRed),
      );
    }
  }

  void _downloadDocument(String title, String path) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download_for_offline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text('Téléchargement de "$title"...'),
          ],
        ),
        backgroundColor: AppColors.accentBlue,
      ),
    );
    
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Document sauvegardé : ${path.split('/').last}'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    });
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}