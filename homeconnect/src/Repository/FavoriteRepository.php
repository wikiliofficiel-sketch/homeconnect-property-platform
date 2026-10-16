<?php

namespace App\Repository;

use App\Entity\Favorite;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

class FavoriteRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Favorite::class);
    }

    public function findByLocataire(int $locataireId): array
    {
        return $this->createQueryBuilder('f')
            ->andWhere('f.locataire = :locataireId')
            ->setParameter('locataireId', $locataireId)
            ->orderBy('f.addedAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    public function isFavorite(int $locataireId, int $propertyId): bool
    {
        return null !== $this->createQueryBuilder('f')
            ->andWhere('f.locataire = :locataireId')
            ->andWhere('f.property = :propertyId')
            ->setParameter('locataireId', $locataireId)
            ->setParameter('propertyId', $propertyId)
            ->setMaxResults(1)
            ->getQuery()
            ->getOneOrNullResult();
    }

    public function countByLocataire(int $locataireId): int
    {
        return $this->createQueryBuilder('f')
            ->select('COUNT(f.id)')
            ->andWhere('f.locataire = :locataireId')
            ->setParameter('locataireId', $locataireId)
            ->getQuery()
            ->getSingleScalarResult();
    }
}
