// ============================================================
// lib/models/enums.dart
// ============================================================

enum UserRole { locataire, proprietaire, partenaire, admin }

enum VerificationStatus { enAttente, verifiee, rejetee, suspendue }

/// Plans synchronisés avec le backend Symfony (Subscription::PLAN_*)
/// free=0 FCFA/3 biens | starter=5000 FCFA/10 biens | pro=10000 FCFA/illimité
enum AbonnementType { free, starter, pro }

/// Compatibilité anciens codes — mappe vers les nouveaux plans
extension AbonnementTypeExt on AbonnementType {
  static AbonnementType fromString(String s) {
    switch (s.toLowerCase()) {
      case 'starter': return AbonnementType.starter;
      case 'pro':
      case 'premium':
      case 'premium_plus': return AbonnementType.pro;
      default: return AbonnementType.free;
    }
  }

  String get apiValue {
    switch (this) {
      case AbonnementType.starter: return 'starter';
      case AbonnementType.pro: return 'pro';
      default: return 'free';
    }
  }

  String get label {
    switch (this) {
      case AbonnementType.starter: return 'Starter';
      case AbonnementType.pro: return 'Pro';
      default: return 'Gratuit';
    }
  }

  int get maxProperties {
    switch (this) {
      case AbonnementType.starter: return 10;
      case AbonnementType.pro: return 999999;
      default: return 3;
    }
  }

  int get pricePerMonth {
    switch (this) {
      case AbonnementType.starter: return 5000;
      case AbonnementType.pro: return 10000;
      default: return 0;
    }
  }

  double get commissionRate {
    switch (this) {
      case AbonnementType.starter:
      case AbonnementType.pro: return 3.0;
      default: return 5.0;
    }
  }
}

enum BienStatut { disponible, loue, enAttente, archive, suspendu }

enum CandidatureStatut { soumise, acceptee, rejetee, annulee }

enum RdvStatut { planifiee, realisee, annulee, reportee }

enum PaiementStatut { enAttente, paye, retard, rembourse }

enum ServiceType { demenagement, nettoyage, renovation, plomberie, electricite, peinture, autre }

enum NotificationType { candidature, rdv, paiement, message, systeme, evaluation }

enum ChampServicePartenaire {
  demenagement,
  nettoyage,
  plomberie,
  electricite,
  menuiserie,
  peinture,
  renovation,
  securite,
  gardiennage,
  autre
}
