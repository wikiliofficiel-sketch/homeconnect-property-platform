<?php

namespace App\Service;

use App\Entity\Log;
use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\SecurityBundle\Security;

class LogService
{
    public function __construct(
        private EntityManagerInterface $em,
        private Security $security
    ) {}

    public function log(string $action, string $details, ?User $targetUser = null): void
    {
        /** @var User|null $admin */
        $admin = $this->security->getUser();

        $log = new Log();
        $log->setAction($action);
        $log->setDetails($details);
        $log->setUser($admin instanceof User ? $admin : null);

        $this->em->persist($log);
        $this->em->flush();
    }

    // ── Helpers sémantiques ──────────────────────────────────────

    public function propertyApproved(string $title, int $propertyId): void
    {
        $this->log('property_approved', sprintf('Bien "%s" (ID %d) approuvé et publié.', $title, $propertyId));
    }

    public function propertySuspended(string $title, int $propertyId, string $reason = ''): void
    {
        $this->log('property_suspended', sprintf('Bien "%s" (ID %d) suspendu. Motif : %s', $title, $propertyId, $reason ?: 'Non précisé'));
    }

    public function propertyDeleted(string $title, int $propertyId): void
    {
        $this->log('property_deleted', sprintf('Bien "%s" (ID %d) supprimé définitivement.', $title, $propertyId));
    }

    public function kycApproved(string $userName, int $userId): void
    {
        $this->log('kyc_approved', sprintf('KYC de %s (ID %d) certifié.', $userName, $userId));
    }

    public function kycRejected(string $userName, int $userId, string $reason = ''): void
    {
        $this->log('kyc_rejected', sprintf('KYC de %s (ID %d) rejeté. Motif : %s', $userName, $userId, $reason ?: 'Non précisé'));
    }

    public function userDeleted(string $userName, int $userId): void
    {
        $this->log('user_deleted', sprintf('Utilisateur %s (ID %d) supprimé.', $userName, $userId));
    }

    public function userRoleChanged(string $userName, int $userId, string $role): void
    {
        $this->log('user_role_changed', sprintf('Rôle "%s" ajouté à %s (ID %d).', $role, $userName, $userId));
    }

    public function subscriptionUpgraded(string $userName, int $subId, string $plan): void
    {
        $this->log('subscription_upgraded', sprintf('Abonnement de %s (ID %d) passé en %s par l\'admin.', $userName, $subId, strtoupper($plan)));
    }

    public function subscriptionRenewed(string $userName, int $subId, int $months): void
    {
        $this->log('subscription_renewed', sprintf('Abonnement de %s (ID %d) prolongé de %d mois.', $userName, $subId, $months));
    }

    public function reportHandled(int $reportId, string $decision): void
    {
        $this->log('report_handled', sprintf('Signalement #%d traité. Décision : %s.', $reportId, $decision));
    }

    public function commissionGenerated(string $propertyTitle, float $amount, float $rate): void
    {
        $this->log('commission_generated', sprintf('Commission de %.0f FCFA (%.1f%%) générée pour le bien "%s".', $amount, $rate, $propertyTitle));
    }
}
