<?php

namespace App\Repository;

use App\Entity\Application;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<Application>
 */
class ApplicationRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Application::class);
    }

    public function findByStatut(string $statut): array
    {
        return $this->createQueryBuilder('a')
            ->andWhere('a.statut = :statut')
            ->setParameter('statut', $statut)
            ->orderBy('a.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    public function findByProperty(int $propertyId): array
    {
        return $this->createQueryBuilder('a')
            ->andWhere('a.property = :propertyId')
            ->setParameter('propertyId', $propertyId)
            ->orderBy('a.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    public function findByLocataire(int $locataireId): array
    {
        return $this->createQueryBuilder('a')
            ->andWhere('a.locataire = :locataireId')
            ->setParameter('locataireId', $locataireId)
            ->orderBy('a.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    public function countPending(): int
    {
        return $this->createQueryBuilder('a')
            ->select('COUNT(a.id)')
            ->andWhere('a.statut = :statut')
            ->setParameter('statut', 'pending')
            ->getQuery()
            ->getSingleScalarResult();
    }
}
