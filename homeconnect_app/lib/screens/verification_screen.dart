// lib/screens/verification_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_colors.dart';
import '../services/database_helper.dart';
import '../models/user.dart';
import '../widgets/design_widgets.dart';

class VerificationScreen extends StatefulWidget {
  final User? user;

  const VerificationScreen({super.key, this.user});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  late User _user;
  String _verificationStatus = 'en_attente';
  bool _isLoading = false;

  // ── Pièce d'identité ─────────────────────────────────────────
  File? _identityDoc;
  String _identiteType = 'CNI';
  final _cniController = TextEditingController();
  DateTime? _expiryDate;

  // ── Justificatif de domicile ─────────────────────────────────
  File? _addressDoc;
  String _domicileType = 'electricite';

  // ── Justificatif de propriété ─────────────────────────────────
  File? _propertyDoc;
  String _proprieteType = 'titre_foncier';

  // ── Cas particulier ───────────────────────────────────────────
  String? _casParticulier; // null | 'copropriete' | 'sci'
  File? _casParticulierDoc;

  // ── Documents optionnels ──────────────────────────────────────
  File? _ribDoc;
  File? _assuranceDoc;
  File? _avisImpositionDoc;

  // Expand/collapse optional section
  bool _showOptional = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _user = widget.user ??
        context.read<AppProvider>().user ??
        User(
            id: 0,
            nom: '',
            prenom: '',
            email: '',
            password: '',
            telephone: '',
            role: 'locataire');
    _loadVerificationStatus();
  }

  @override
  void dispose() {
    _cniController.dispose();
    super.dispose();
  }

  Future<void> _loadVerificationStatus() async {
    setState(() => _isLoading = true);
    final user = await DatabaseHelper().getUserById(_user.id);
    if (user != null) {
      setState(() {
        _user = user;
        _verificationStatus = user.verificationStatus ?? 'en_attente';
        if (user.verificationDocumentType != null) {
          _identiteType = user.verificationDocumentType!;
        }
        if (user.verificationDocument != null &&
            user.verificationDocument!.isNotEmpty) {
          _identityDoc = File(user.verificationDocument!);
        }
        if (user.verificationDocumentAddress != null &&
            user.verificationDocumentAddress!.isNotEmpty) {
          _addressDoc = File(user.verificationDocumentAddress!);
        }
        if (user.verificationDocumentProperty != null &&
            user.verificationDocumentProperty!.isNotEmpty) {
          _propertyDoc = File(user.verificationDocumentProperty!);
        }
      });
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getScaffoldBackground(context),
      body: Container(
        decoration:
            BoxDecoration(gradient: AppColors.getBackgroundGradient(context)),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _isLoading
                    ? LoadingWidget(
                        message: context
                            .read<AppProvider>()
                            .translate('checking_status'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatusBanner(),
                            const SizedBox(height: 24),
                            SectionHeaderWidget(
                                title: context
                                    .read<AppProvider>()
                                    .translate('your_info'),
                                icon: Icons.person_outline),
                            const SizedBox(height: 12),
                            _buildInfoCard(
                                context
                                    .read<AppProvider>()
                                    .translate('full_name'),
                                '${_user.nom} ${_user.prenom}'),
                            _buildInfoCard(
                                context
                                    .read<AppProvider>()
                                    .translate('email_address'),
                                _user.email),
                            _buildInfoCard(
                                context.read<AppProvider>().translate('phone'),
                                _user.telephone ?? ''),
                            const SizedBox(height: 28),

                            if (_verificationStatus != 'certifie')
                              _buildFormSection()
                            else
                              _buildCertifiedBanner(),

                            const SizedBox(height: 40),
                            _buildAdvantagesSection(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Formulaire complet ────────────────────────────────────────────────
  Widget _buildFormSection() {
    final bool isLocked = _verificationStatus == 'en_attente' ||
        _verificationStatus == 'en_cours_verification';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ══ 1. PIÈCE D'IDENTITÉ ══════════════════════════════════════
        _sectionTitle('1', 'Pièce d\'identité', Colors.red, required: true),
        const SizedBox(height: 12),
        _buildDropdown(
          label: 'Type de pièce *',
          value: _identiteType,
          items: const {
            'CNI': 'CNI (Carte Nationale d\'Identité)',
            'passeport': 'Passeport',
          },
          onChanged: isLocked ? null : (v) => setState(() => _identiteType = v!),
        ),
        const SizedBox(height: 12),
        ModernTextField(
          controller: _cniController,
          label: 'Numéro de la pièce *',
          icon: Icons.numbers_rounded,
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 12),
        _buildDatePicker(
            'Date d\'expiration *',
            _expiryDate,
            isLocked ? null : (date) => setState(() => _expiryDate = date)),
        const SizedBox(height: 12),
        _buildModernUploadCard(
          context.read<AppProvider>().translate('identity_card'),
          context.read<AppProvider>().translate('id_card_subtitle'),
          _identityDoc,
          isLocked ? null : () => _pickImage('identity'),
        ),

        const SizedBox(height: 24),

        // ══ 2. JUSTIFICATIF DE DOMICILE ══════════════════════════════
        _sectionTitle('2', 'Justificatif de domicile (< 3 mois)', Colors.blue,
            required: true),
        const SizedBox(height: 12),
        _buildDropdown(
          label: 'Type de justificatif *',
          value: _domicileType,
          items: const {
            'electricite': 'Facture d\'électricité',
            'eau': 'Facture d\'eau',
            'telephone': 'Facture de téléphone',
            'taxe_fonciere': 'Taxe foncière',
            'quittance': 'Quittance de loyer',
          },
          onChanged:
              isLocked ? null : (v) => setState(() => _domicileType = v!),
        ),
        const SizedBox(height: 12),
        _buildModernUploadCard(
          context.read<AppProvider>().translate('address_proof'),
          context.read<AppProvider>().translate('address_proof_subtitle'),
          _addressDoc,
          isLocked ? null : () => _pickImage('address'),
        ),

        if (_user.role == 'proprietaire') ...[
          const SizedBox(height: 24),

          // ══ 3. JUSTIFICATIF DE PROPRIÉTÉ ═════════════════════════
          _sectionTitle('3', 'Justificatif de propriété', Colors.purple,
              required: true),
          const SizedBox(height: 12),
          _buildDropdown(
            label: 'Type de document *',
            value: _proprieteType,
            items: const {
              'titre_foncier': 'Titre foncier',
              'attestation_notaire': 'Attestation notariée',
              'acte_vente': 'Acte de vente',
              'donation_succession': 'Acte de donation / succession',
            },
            onChanged:
                isLocked ? null : (v) => setState(() => _proprieteType = v!),
          ),
          const SizedBox(height: 12),
          _buildModernUploadCard(
            context.read<AppProvider>().translate('property_title'),
            context.read<AppProvider>().translate('property_title_subtitle'),
            _propertyDoc,
            isLocked ? null : () => _pickImage('property'),
          ),

          const SizedBox(height: 24),

          // ══ 4. CAS PARTICULIER ════════════════════════════════════
          _sectionTitle('4', 'Cas particulier', Colors.orange),
          const SizedBox(height: 8),
          _buildDropdown(
            label: 'Type (optionnel)',
            value: _casParticulier ?? '',
            items: const {
              '': 'Aucun',
              'copropriete': 'Copropriété',
              'sci': 'SCI (Société Civile Immobilière)',
            },
            onChanged: isLocked
                ? null
                : (v) => setState(() => _casParticulier = v!.isEmpty ? null : v),
          ),
          if (_casParticulier != null) ...[
            const SizedBox(height: 12),
            _buildModernUploadCard(
              _casParticulier == 'sci'
                  ? 'Statuts SCI + justificatif de pouvoirs'
                  : 'Extrait règlement de copropriété',
              'Télécharger le document',
              _casParticulierDoc,
              isLocked ? null : () => _pickImage('cas_particulier'),
            ),
          ],

          const SizedBox(height: 24),

          // ══ 5. DOCUMENTS OPTIONNELS ═══════════════════════════════
          GestureDetector(
            onTap: () => setState(() => _showOptional = !_showOptional),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline,
                      color: AppColors.accentBlue, size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Documents complémentaires (facultatifs)',
                      style: TextStyle(
                          color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    _showOptional
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ),
          if (_showOptional) ...[
            const SizedBox(height: 12),
            _buildModernUploadCard('RIB (Relevé d\'identité bancaire)',
                'Optionnel', _ribDoc,
                isLocked ? null : () => _pickImage('rib')),
            const SizedBox(height: 12),
            _buildModernUploadCard('Attestation assurance PNO',
                'Propriétaire Non Occupant — Optionnel', _assuranceDoc,
                isLocked ? null : () => _pickImage('assurance')),
            const SizedBox(height: 12),
            _buildModernUploadCard('Avis d\'imposition',
                'Dernier avis d\'imposition — Optionnel', _avisImpositionDoc,
                isLocked ? null : () => _pickImage('avis_imposition')),
          ],
        ],

        const SizedBox(height: 40),

        // ══ BOUTON SOUMETTRE / STATUT ══════════════════════════════
        if (isLocked)
          _buildPendingBanner()
        else
          ModernButton(
            text: context.read<AppProvider>().translate('submit_dossier'),
            onPressed: _submitForVerification,
            icon: Icons.send_rounded,
          ),
      ],
    );
  }

  // ── Widgets utilitaires ───────────────────────────────────────────────

  Widget _sectionTitle(String number, String title, Color color,
      {bool required = false}) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(number,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ),
        if (required)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: const Text('Obligatoire',
                style: TextStyle(color: Colors.redAccent, fontSize: 10)),
          ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required Function(String?)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: AppColors.backgroundDark,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              onChanged: onChanged,
              items: items.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accentOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.hourglass_top_rounded,
              color: AppColors.accentOrange, size: 40),
          const SizedBox(height: 12),
          Text(
            context.read<AppProvider>().translate('processing_dossier'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            context.read<AppProvider>().translate('admins_verifying'),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              context.watch<AppProvider>().translate('kyc_certification'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildCertifiedBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.accentGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified_rounded,
              size: 64, color: AppColors.accentGreen),
          const SizedBox(height: 16),
          Text(
            context.read<AppProvider>().translate('certified_account'),
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            context.read<AppProvider>().translate('identity_verified_success'),
            textAlign: TextAlign.center,
            style: TextStyle(
                color:
                    AppColors.getTextColor(context).withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildModernUploadCard(
      String title, String subtitle, File? file, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: file != null
                ? AppColors.accentGreen
                : Colors.white.withValues(alpha: 0.1),
            width: file != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (file != null
                        ? AppColors.accentGreen
                        : (onTap == null
                            ? Colors.grey
                            : AppColors.accentOrange))
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                file != null
                    ? Icons.check_circle_rounded
                    : (onTap == null
                        ? Icons.lock_outline
                        : Icons.add_a_photo_rounded),
                color: file != null
                    ? AppColors.accentGreen
                    : (onTap == null ? Colors.grey : AppColors.accentOrange),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(
                    file != null
                        ? context
                            .read<AppProvider>()
                            .translate('file_selected')
                        : subtitle,
                    style: TextStyle(
                        color: file != null
                            ? AppColors.accentGreen
                            : Colors.white54,
                        fontSize: 12),
                  ),
                ],
              ),
            ),
            if (file != null && onTap != null)
              const Icon(Icons.refresh_rounded,
                  color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvantagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.read<AppProvider>().translate('exclusive_advantages'),
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 16),
        _buildBenefitItem(
            context.read<AppProvider>().translate('certified_badge_benefit')),
        _buildBenefitItem(context
            .read<AppProvider>()
            .translate('priority_highlight_benefit')),
        _buildBenefitItem(context
            .read<AppProvider>()
            .translate('secure_payment_access_benefit')),
        _buildBenefitItem(
            context.read<AppProvider>().translate('community_trust_benefit')),
      ],
    );
  }

  Widget _buildStatusBanner() {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (_verificationStatus == 'certifie') {
      statusColor = AppColors.accentGreen;
      statusText = context.read<AppProvider>().translate('certified');
      statusIcon = Icons.verified_user_rounded;
    } else if (_verificationStatus == 'en_attente' ||
        _verificationStatus == 'en_cours_verification') {
      statusColor = AppColors.accentOrange;
      statusText = context.read<AppProvider>().translate('under_review');
      statusIcon = Icons.query_builder_rounded;
    } else if (_verificationStatus == 'rejete') {
      statusColor = AppColors.accentRed;
      statusText = context.read<AppProvider>().translate('docs_rejected');
      statusIcon = Icons.error_outline_rounded;
    } else {
      statusColor = Colors.grey;
      statusText = 'Non soumis';
      statusIcon = Icons.upload_file_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    context
                        .read<AppProvider>()
                        .translate('current_status'),
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
                Text(statusText,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded,
              color: AppColors.accentYellow, size: 18),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _pickImage(String type) async {
    try {
      final XFile? image =
          await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          final file = File(image.path);
          switch (type) {
            case 'identity':
              _identityDoc = file;
              break;
            case 'address':
              _addressDoc = file;
              break;
            case 'property':
              _propertyDoc = file;
              break;
            case 'cas_particulier':
              _casParticulierDoc = file;
              break;
            case 'rib':
              _ribDoc = file;
              break;
            case 'assurance':
              _assuranceDoc = file;
              break;
            case 'avis_imposition':
              _avisImpositionDoc = file;
              break;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Accès refusé ou erreur technique.')));
    }
  }

  Future<void> _submitForVerification() async {
    if (_identityDoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pièce d\'identité manquante'),
          backgroundColor: AppColors.accentRed));
      return;
    }
    if (_addressDoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Justificatif de domicile manquant'),
          backgroundColor: AppColors.accentRed));
      return;
    }
    if (_user.role == 'proprietaire' && _propertyDoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Justificatif de propriété manquant'),
          backgroundColor: AppColors.accentRed));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getScaffoldBackground(context),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
            context.read<AppProvider>().translate('submit_dossier_confirm'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          context.read<AppProvider>().translate('dossier_analysis_desc'),
          style: TextStyle(
              color: AppColors.getTextColor(context).withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.read<AppProvider>().translate('cancel'),
                  style: TextStyle(
                      color: AppColors.getTextColor(context)
                          .withValues(alpha: 0.5)))),
          ModernButton(
            text: context.read<AppProvider>().translate('confirm'),
            onPressed: () async {
              await DatabaseHelper().submitKYCDocument(
                userId: _user.id,
                identityPath: _identityDoc?.path,
                addressPath: _addressDoc?.path,
                propertyPath: _propertyDoc?.path,
                documentType: _identiteType,
                cniNumber: _cniController.text,
                expiryDate: _expiryDate,
              );
              if (!context.mounted) return;
              setState(() => _verificationStatus = 'en_attente');
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(context
                      .read<AppProvider>()
                      .translate('dossier_sent_success')),
                  backgroundColor: AppColors.accentGreen));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(
      String label, DateTime? value, Function(DateTime)? onSelected) {
    return InkWell(
      onTap: onSelected == null
          ? null
          : () async {
              final d = await showDatePicker(
                context: context,
                initialDate:
                    value ?? DateTime.now().add(const Duration(days: 365)),
                firstDate: DateTime.now(),
                lastDate:
                    DateTime.now().add(const Duration(days: 3650)),
              );
              if (d != null) onSelected(d);
            },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: value != null
                  ? AppColors.accentBlue
                  : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                color:
                    value != null ? AppColors.accentBlue : Colors.white54,
                size: 20),
            const SizedBox(width: 16),
            Expanded(
                child: Text(
                    value == null
                        ? label
                        : '${value.day}/${value.month}/${value.year}',
                    style: TextStyle(
                        color: value != null
                            ? Colors.white
                            : Colors.white70))),
            if (onSelected == null)
              const Icon(Icons.lock_outline,
                  color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}
