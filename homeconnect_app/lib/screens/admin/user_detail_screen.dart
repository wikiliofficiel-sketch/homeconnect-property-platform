import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/database_helper.dart';
import '../../utils/app_colors.dart';
import '../../widgets/design_widgets.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../tenant/chat_screen.dart';

class UserDetailScreen extends StatefulWidget {
  final User user;
  final VoidCallback onRefresh;

  const UserDetailScreen({super.key, required this.user, required this.onRefresh});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  bool _isUpdating = false;

  Future<void> _updateVerificationStatus(String status, bool isVerified) async {
    setState(() => _isUpdating = true);
    try {
      if (isVerified) {
        // Appeler l'API de certification → même BDD que le web
        final adminId = Provider.of<AppProvider>(context, listen: false).user?.id ?? 1;
        final result = await ApiService.post('/api/admin/kyc/${widget.user.id}/approve', {});
        if (result == null) {
          await DatabaseHelper().approveKYC(widget.user.id, adminId);
        }
      } else {
        await ApiService.post('/api/admin/kyc/${widget.user.id}/suspend', {});
        await DatabaseHelper().updateUser(widget.user.id, {
          'verificationStatus': status,
          'isVerified': 0,
        });
      }

      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isVerified
                ? '✅ Compte certifié — accès propriétaire accordé'
                : 'Statut mis à jour : $status'),
            backgroundColor: isVerified ? Colors.green : Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final roleColors = {
      'locataire': AppColors.accentBlue,
      'proprietaire': AppColors.accentOrange,
      'admin': AppColors.accentPurple,
    };
    final color = roleColors[user.role] ?? Colors.white70;

    return Scaffold(
      backgroundColor: AppColors.getScaffoldBackground(context),
      appBar: AppBar(
        title: Text('Détails de l\'utilisateur', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextColor(context))),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // User Header Info
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: color.withValues(alpha: 0.2),
                    child: Text(
                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
                  const SizedBox(height: 16),
                    Text(
                      user.displayName,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)),
                    ),
                  const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(fontSize: 14, color: AppColors.getTextColor(context).withValues(alpha: 0.6)),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (user.role ?? '').toUpperCase(),
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            receiverId: user.id,
                            receiverName: user.displayName,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Envoyer un message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Verification Status Card
            _buildInfoCard(
              title: 'Statut de Vérification',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          user.isVerified ? Icons.verified_rounded : Icons.pending_actions_rounded,
                          color: user.isVerified ? AppColors.accentGreen : AppColors.accentOrange,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            user.isVerified ? 'Certifié ✅' : 'En attente de certification',
                            style: TextStyle(
                              color: user.isVerified ? AppColors.accentGreen : AppColors.accentOrange,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!user.isVerified)
                    ElevatedButton(
                      onPressed: _isUpdating ? null : () => _updateVerificationStatus('verifie', true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      child: const Text('Certifier', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // User Details Card
            _buildInfoCard(
              title: 'Informations personnelles',
              child: Column(
                children: [
                  _buildDetailRowIcon(Icons.phone_iphone_rounded, 'Téléphone', user.telephone ?? 'Non renseigné'),
                  const Divider(color: Colors.white10, height: 24),
                  _buildDetailRowIcon(Icons.calendar_today_rounded, 'Membre depuis', 'Non disponible'),
                  const Divider(color: Colors.white10, height: 24),
                  _buildDetailRowIcon(Icons.credit_card_rounded, 'Abonnement', user.subscriptionType ?? 'Gratuit'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // KYC Documents Card
            if (user.role == 'proprietaire') ...[
              _buildInfoCard(
                title: 'Documents de Vérification (KYC)',
                child: Column(
                  children: [
                    _buildDetailRowIcon(
                        Icons.badge_rounded, 'Pièce d\'identité', user.verificationDocument ?? 'Non fourni'),
                    const Divider(color: Colors.white10, height: 24),
                    _buildDetailRowIcon(Icons.home_work_rounded, 'Justificatif de domicile',
                        user.verificationDocumentAddress ?? 'Non fourni'),
                    const Divider(color: Colors.white10, height: 24),
                    _buildDetailRowIcon(Icons.description_rounded, 'Titre de propriété',
                        user.verificationDocumentProperty ?? 'Non fourni'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Actions
            if (user.role != 'admin')
              Row(
                children: [
                  Expanded(
                    child: ActionButtonWidget(
                      label: 'Suspendre',
                      icon: Icons.block_rounded,
                      variant: ButtonVariant.warning,
                      onPressed: () => _updateVerificationStatus('suspendu', false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionButtonWidget(
                      label: 'Supprimer',
                      icon: Icons.delete_forever_rounded,
                      variant: ButtonVariant.danger,
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.primaryDark,
                            title: const Text('Confirmer la suppression', style: TextStyle(color: Colors.white)),
                            content: Text('Voulez-vous vraiment supprimer ${user.displayName} ?', style: const TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler', style: TextStyle(color: Colors.white70))),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer', style: TextStyle(color: AppColors.accentRed))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await DatabaseHelper().deleteUser(user.id);
                          widget.onRefresh();
                          nav.pop();
                        }
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accentOrange)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRowIcon(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.white54),
        const SizedBox(width: 12),
        Expanded(                          // ← fix overflow
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: AppColors.getTextColor(context).withValues(alpha: 0.4))),
              Text(
                value.isEmpty ? 'Non renseigné' : value,
                style: TextStyle(fontSize: 14, color: AppColors.getTextColor(context), fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
