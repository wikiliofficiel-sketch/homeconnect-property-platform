import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/subscription_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _selectedMonths = 1;

  static const _plans = [
    {
      'key':   'free',
      'label': 'Gratuit',
      'price': 0,
      'max':   3,
      'color': Color(0xFF6B7280),
      'features': [
        '3 biens maximum',
        'Tableau de bord standard',
        'Messagerie incluse',
        'Support communauté',
      ],
    },
    {
      'key':   'starter',
      'label': 'Starter',
      'price': 5000,
      'max':   10,
      'color': Color(0xFF3B82F6),
      'features': [
        "Jusqu'à 10 biens",
        'Tableau de bord avancé',
        'Messagerie WhatsApp',
        'Statistiques détaillées',
        'Support email prioritaire',
      ],
      'recommended': true,
    },
    {
      'key':   'pro',
      'label': 'Pro',
      'price': 10000,
      'max':   null,
      'color': Color(0xFF8B5CF6),
      'features': [
        'Biens illimités',
        'Tableau de bord premium',
        'Messagerie + Appels vidéo',
        'Statistiques & exports PDF',
        'Support téléphonique dédié',
        'Badge "Propriétaire Pro" ✨',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().loadCurrentSubscription();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Abonnement',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6D28D9),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, sub, _) {
          if (sub.isLoading && sub.current == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Statut actuel
                _buildCurrentStatus(sub),
                const SizedBox(height: 24),

                // Durée sélecteur
                if (sub.planKey != 'pro') ...[
                  _buildMonthSelector(),
                  const SizedBox(height: 24),
                ],

                // Plans
                const Text('Choisir un plan',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937))),
                const SizedBox(height: 12),
                ..._plans.map((plan) => _buildPlanCard(plan, sub)),

                const SizedBox(height: 16),
                // Note bas
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Chaque fois que vous atteignez la limite, le système vous propose de passer au palier supérieur.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentStatus(SubscriptionProvider sub) {
    final planColor = sub.isPro
        ? const Color(0xFF8B5CF6)
        : sub.isStarter
            ? const Color(0xFF3B82F6)
            : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [planColor, planColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: planColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Votre plan actuel',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(sub.planLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  sub.isFree ? '0 FCFA/mois' : '${_fmtPrice(sub.current?['planPrice'] as int? ?? 0)}/mois',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barre de progression des biens
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${sub.publishedCount} bien(s) publiés',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    sub.maxProperties == null
                        ? 'Illimité'
                        : '${sub.remainingSlots} restant(s)',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: sub.maxProperties == null
                      ? 1.0
                      : (sub.publishedCount /
                          (sub.maxProperties ?? 1)).clamp(0.0, 1.0),
                  backgroundColor:
                      Colors.white.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    sub.canPublishMore
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          ),
          if (!sub.canPublishMore && sub.nextPlan != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Limite atteinte ! Passez au plan ${sub.nextPlanLabel} pour continuer.',
                      style: const TextStyle(
                          color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Durée d\'abonnement',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
        const SizedBox(height: 8),
        Row(
          children: [1, 3, 6, 12].map((m) {
            final selected = m == _selectedMonths;
            final discount = m == 12 ? '–20%' : m == 6 ? '–10%' : null;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedMonths = m),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF6D28D9)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selected
                            ? const Color(0xFF6D28D9)
                            : Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Text('$m mois',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: selected
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 13)),
                      if (discount != null)
                        Text(discount,
                            style: TextStyle(
                                fontSize: 10,
                                color: selected
                                    ? Colors.greenAccent
                                    : Colors.green)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, SubscriptionProvider sub) {
    final key       = plan['key'] as String;
    final label     = plan['label'] as String;
    final price     = plan['price'] as int;
    final maxP      = plan['max'] as int?;
    final color     = plan['color'] as Color;
    final features  = plan['features'] as List;
    final recommended = plan['recommended'] as bool? ?? false;
    final isCurrent = sub.planKey == key;
    final canUpgrade = !isCurrent && _canUpgradeTo(sub.planKey, key);
    final total = price * _selectedMonths;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? color
              : recommended
                  ? color.withValues(alpha: 0.4)
                  : Colors.grey.shade200,
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle),
                  child: Center(
                    child: Text(label[0],
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(label,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: color)),
                          if (recommended) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: color,
                                  borderRadius:
                                      BorderRadius.circular(4)),
                              child: const Text('RECOMMANDÉ',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius:
                                      BorderRadius.circular(4)),
                              child: const Text('ACTUEL',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        maxP == null
                            ? 'Biens illimités'
                            : '$maxP biens max',
                        style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price == 0
                          ? 'GRATUIT'
                          : _fmtPrice(price),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color),
                    ),
                    if (price > 0)
                      Text('/mois',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
          ),

          // Features
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: color, size: 16),
                          const SizedBox(width: 8),
                          Text(f as String,
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
                // Bouton
                if (isCurrent)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200),
                      child: Text('Plan actuel',
                          style: TextStyle(
                              color: Colors.grey.shade600)),
                    ),
                  )
                else if (canUpgrade)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: sub.isLoading
                          ? null
                          : () => _upgrade(key, total),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: sub.isLoading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : Text(
                              price == 0
                                  ? 'Utiliser gratuitement'
                                  : 'Passer à $label — ${_fmtPrice(total)} FCFA',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300)),
                      child: const Text('Non disponible',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canUpgradeTo(String current, String target) {
    const order = {'free': 0, 'starter': 1, 'pro': 2};
    return (order[target] ?? 0) > (order[current] ?? 0);
  }

  Future<void> _upgrade(String plan, int totalPrice) async {
    final sub = context.read<SubscriptionProvider>();
    final result = await sub.upgrade(
        plan: plan, months: _selectedMonths);

    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(sub.error.isNotEmpty ? sub.error : 'Erreur')));
      return;
    }

    if (result['paymentRequired'] == true) {
      final url = result['paymentUrl'] as String?;
      if (url != null) {
        final canLaunch = await canLaunchUrl(Uri.parse(url));
        if (!mounted) return;
        if (canLaunch) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Redirection vers le paiement...')));
        }
      }
      return;
    }

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.green,
          content: Text(result['message'] as String? ??
              'Abonnement activé !')));
      sub.loadCurrentSubscription();
    }
  }

  String _fmtPrice(int price) {
    if (price == 0) return 'GRATUIT';
    final s = price.toString();
    if (s.length > 3) {
      return '${s.substring(0, s.length - 3)} ${s.substring(s.length - 3)} FCFA';
    }
    return '$s FCFA';
  }
}
