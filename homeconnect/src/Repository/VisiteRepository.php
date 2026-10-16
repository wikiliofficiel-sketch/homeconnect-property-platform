<?php

namespace App\Repository;

use App\Entity\Visite;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<Visite>
 */
class VisiteRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Visite::class);
    }

    public function findByStatut(string $statut): array
    {
        return $this->createQueryBuilder('v')
            ->andWhere('v.statut = :statut')
            ->setParameter('statut', $statut)
            ->orderBy('v.dateHeureDebut', 'ASC')
            ->getQuery()
            ->getResult();
    }

    public function findUpcoming(): array
    {
        $now = new \DateTime();
        return $this->createQueryBuilder('v')
            ->andWhere('v.dateHeureDebut > :now')
            ->andWhere('v.statut = :statut')
            ->setParameter('now', $now)
            ->setParameter('statut', 'planifiee')
            ->orderBy('v.dateHeureDebut', 'ASC')
            ->getQuery()
            ->getResult();
    }

    public function findByApplicationId(int $applicationId): array
    {
        return $this->createQueryBuilder('v')
            ->andWhere('v.application = :applicationId')
            ->setParameter('applicationId', $applicationId)
            ->orderBy('v.dateHeureDebut', 'ASC')
            ->getQuery()
            ->getResult();
    }
}
