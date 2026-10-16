<?php

namespace App\Repository;

use App\Entity\PropertyInteraction;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<PropertyInteraction>
 */
class PropertyInteractionRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, PropertyInteraction::class);
    }

    public function findOneByPropertyAndUser(int $propertyId, int $userId): ?PropertyInteraction
    {
        return $this->createQueryBuilder('pi')
            ->where('pi.property = :propertyId')
            ->andWhere('pi.user = :userId')
            ->setParameter('propertyId', $propertyId)
            ->setParameter('userId', $userId)
            ->getQuery()
            ->getOneOrNullResult();
    }

    public function countByType(int $propertyId, string $type): int
    {
        return (int) $this->createQueryBuilder('pi')
            ->select('COUNT(pi)')
            ->where('pi.property = :propertyId')
            ->andWhere('pi.type = :type')
            ->setParameter('propertyId', $propertyId)
            ->setParameter('type', $type)
            ->getQuery()
            ->getSingleScalarResult();
    }
}
