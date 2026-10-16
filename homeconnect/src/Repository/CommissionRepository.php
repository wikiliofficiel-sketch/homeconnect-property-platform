<?php

namespace App\Repository;

use App\Entity\Commission;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<Commission>
 */
class CommissionRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Commission::class);
    }

    public function getTotalCommissions(): float
    {
        $result = $this->createQueryBuilder('c')
            ->select('SUM(c.montantCommission)')
            ->getQuery()
            ->getSingleScalarResult();
        
        return $result ?? 0;
    }

    public function getCommissionsBetween(\DateTimeImmutable $start, \DateTimeImmutable $end): float
    {
        $result = $this->createQueryBuilder('c')
            ->select('SUM(c.montantCommission)')
            ->andWhere('c.createdAt >= :start')
            ->andWhere('c.createdAt <= :end')
            ->setParameter('start', $start)
            ->setParameter('end', $end)
            ->getQuery()
            ->getSingleScalarResult();
        
        return $result ?? 0;
    }
}
