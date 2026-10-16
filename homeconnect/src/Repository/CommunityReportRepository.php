<?php

namespace App\Repository;

use App\Entity\CommunityReport;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

class CommunityReportRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, CommunityReport::class);
    }

    public function findByStatus(string $status): array
    {
        return $this->createQueryBuilder('r')
            ->andWhere('r.status = :status')
            ->setParameter('status', $status)
            ->orderBy('r.priority', 'DESC')
            ->addOrderBy('r.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    public function findByReporter(int $reporterId): array
    {
        return $this->createQueryBuilder('r')
            ->andWhere('r.reporter = :reporterId')
            ->setParameter('reporterId', $reporterId)
            ->orderBy('r.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    public function findByReason(string $reason): array
    {
        return $this->createQueryBuilder('r')
            ->andWhere('r.reason = :reason')
            ->setParameter('reason', $reason)
            ->orderBy('r.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
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

    public function findPending(): array
    {
        return $this->findByStatus(CommunityReport::STATUS_PENDING);
    }

    public function findCriticalPending(): array
    {
        return $this->createQueryBuilder('r')
            ->andWhere('r.status = :status')
            ->andWhere('r.priority = :priority')
            ->setParameter('status', CommunityReport::STATUS_PENDING)
            ->setParameter('priority', CommunityReport::PRIORITY_CRITICAL)
            ->orderBy('r.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }
}
