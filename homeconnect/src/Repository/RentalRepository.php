<?php

namespace App\Repository;

use App\Entity\Rental;
use App\Entity\User;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<Rental>
 *
 * @method Rental|null find($id, $lockMode = null, $lockVersion = null)
 * @method Rental|null findOneBy(array $criteria, array $orderBy = null)
 * @method Rental[]    findAll()
 * @method Rental[]    findBy(array $criteria, array $orderBy = null, $limit = null, $offset = null)
 */
class RentalRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Rental::class);
    }

    /**
     * Trouve les locations actives
     */
    public function findActive(): array
    {
        return $this->createQueryBuilder('r')
            ->andWhere('r.status = :status')
            ->andWhere('r.startDate <= :now')
            ->andWhere('r.endDate >= :now')
            ->setParameter('status', 'active')
            ->setParameter('now', new \DateTimeImmutable())
            ->orderBy('r.startDate', 'ASC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Trouve les locations en attente
     */
    public function findPending(): array
    {
        return $this->createQueryBuilder('r')
            ->andWhere('r.status = :status')
            ->setParameter('status', 'pending')
            ->orderBy('r.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Trouve les locations d'un locataire
     */
    public function findByLocataire(User $locataire): array
    {
        return $this->createQueryBuilder('r')
            ->andWhere('r.locataire = :locataire')
            ->setParameter('locataire', $locataire)
            ->orderBy('r.startDate', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Trouve les locations pour les propriétés d'un propriétaire
     */
    public function findByProprietaire(User $proprietaire): array
    {
        return $this->createQueryBuilder('r')
            ->innerJoin('r.property', 'p')
            ->andWhere('p.proprietaire = :proprietaire')
            ->setParameter('proprietaire', $proprietaire)
            ->orderBy('r.startDate', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Compte les locations actives pour une propriété
     */
    public function countActiveForProperty(int $propertyId): int
    {
        return $this->createQueryBuilder('r')
            ->select('COUNT(r.id)')
            ->andWhere('r.property = :propertyId')
            ->andWhere('r.status = :status')
            ->andWhere('r.startDate <= :now')
            ->andWhere('r.endDate >= :now')
            ->setParameter('propertyId', $propertyId)
            ->setParameter('status', 'active')
            ->setParameter('now', new \DateTimeImmutable())
            ->getQuery()
            ->getSingleScalarResult();
    }

    /**
     * Trouve les locations par statut
     */
    public function findByStatus(string $status): array
    {
        return $this->createQueryBuilder('r')
            ->andWhere('r.status = :status')
            ->setParameter('status', $status)
            ->orderBy('r.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Trouve les locations terminées d'un locataire
     */
    public function findCompletedByLocataire(User $locataire): array
    {
        return $this->createQueryBuilder('r')
            ->andWhere('r.locataire = :locataire')
            ->andWhere('r.status = :status')
            ->setParameter('locataire', $locataire)
            ->setParameter('status', 'completed')
            ->orderBy('r.endDate', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Vérifie si un locataire a une location active
     */
    public function hasActiveRental(User $locataire): bool
    {
        $count = $this->createQueryBuilder('r')
            ->select('COUNT(r.id)')
            ->andWhere('r.locataire = :locataire')
            ->andWhere('r.status = :status')
            ->andWhere('r.startDate <= :now')
            ->andWhere('r.endDate >= :now')
            ->setParameter('locataire', $locataire)
            ->setParameter('status', 'active')
            ->setParameter('now', new \DateTimeImmutable())
            ->getQuery()
            ->getSingleScalarResult();

        return $count > 0;
    }

    public function countByStatus(string $status): int
    {
        return $this->createQueryBuilder('r')
            ->select('COUNT(r.id)')
            ->andWhere('r.status = :status')
            ->setParameter('status', $status)
            ->getQuery()
            ->getSingleScalarResult();
    }
}
