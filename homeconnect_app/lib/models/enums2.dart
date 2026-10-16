// ============================================================
// lib/models/enums.dart - Énumérations
// ============================================================

enum UserRole { locataire, proprietaire, partenaire, admin }

enum VerificationStatus { enAttente, verifiee, rejetee, suspendue }

enum AbonnementType { gratuit, starter, pro, premium }

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
