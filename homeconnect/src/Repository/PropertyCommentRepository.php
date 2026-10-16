<?php

namespace App\Repository;

use App\Entity\PropertyComment;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<PropertyComment>
 */
class PropertyCommentRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, PropertyComment::class);
    }

    public function findByProperty(int $propertyId): array
    {
        return $this->createQueryBuilder('c')
            ->where('c.property = :propertyId')
            ->setParameter('propertyId', $propertyId)
            ->orderBy('c.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }
}
