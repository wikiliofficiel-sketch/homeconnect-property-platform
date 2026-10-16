<?php

namespace App\Repository;

use App\Entity\User;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;
use Symfony\Component\Security\Core\Exception\UnsupportedUserException;
use Symfony\Component\Security\Core\User\PasswordAuthenticatedUserInterface;
use Symfony\Component\Security\Core\User\PasswordUpgraderInterface;

/**
 * @extends ServiceEntityRepository<User>
 */
class UserRepository extends ServiceEntityRepository implements PasswordUpgraderInterface
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, User::class);
    }

    /**
     * Mise à jour automatique du mot de passe hashé
     */
    public function upgradePassword(PasswordAuthenticatedUserInterface $user, string $newHashedPassword): void
    {
        if (!$user instanceof User) {
            throw new UnsupportedUserException(sprintf('Instances of "%s" are not supported.', $user::class));
        }

        $user->setPassword($newHashedPassword);
        $this->getEntityManager()->persist($user);
        $this->getEntityManager()->flush();
    }

    /**
     * Trouver un utilisateur par email
     */
    public function findByEmail(string $email): ?User
    {
        return $this->findOneBy(['email' => $email]);
    }

    /**
     * Trouver tous les propriétaires
     */
    public function findProprietaires(): array
    {
        return $this->createQueryBuilder('u')
            ->where('u.roles LIKE :role')
            ->setParameter('role', '%ROLE_PROPRIETAIRE%')
            ->orderBy('u.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Trouver tous les locataires
     */
    public function findLocataires(): array
    {
        return $this->createQueryBuilder('u')
            ->where('u.roles LIKE :role')
            ->setParameter('role', '%ROLE_LOCATAIRE%')
            ->orderBy('u.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Trouver les utilisateurs vérifiés
     */
    public function findVerified(): array
    {
        return $this->findBy(['isVerified' => true]);
    }

    /**
     * Trouver les utilisateurs par rôle
     */
    public function findWithRole(string $role): array
    {
        return $this->createQueryBuilder('u')
            ->where('u.roles LIKE :role')
            ->setParameter('role', '%' . $role . '%')
            ->orderBy('u.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Trouver les admins
     */
    public function findAdmins(): array
    {
        return $this->findWithRole('ROLE_ADMIN');
    }

    /**
     * Trouver les KYC en attente
     */
    public function findPendingKyc(): array
    {
        return $this->createQueryBuilder('u')
            ->where('u.kyc_status = :status')
            ->setParameter('status', 'pending')
            ->orderBy('u.kyc_submitted_at', 'ASC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Trouver les KYC approuvés
     */
    public function findApprovedKyc(): array
    {
        return $this->createQueryBuilder('u')
            ->where('u.kyc_status = :status')
            ->setParameter('status', 'approved')
            ->getQuery()
            ->getResult();
    }

    /**
     * Compter les utilisateurs non vérifiés
     */
    public function countUnverified(): int
    {
        return $this->createQueryBuilder('u')
            ->select('COUNT(u.id)')
            ->where('u.isVerified = :verified')
            ->setParameter('verified', false)
            ->getQuery()
            ->getSingleScalarResult();
    }
}
