<?php

namespace App\Repository;

use App\Entity\Subscription;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<Subscription>
 */
class SubscriptionRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Subscription::class);
    }

    public function findActivePremiumPlus()
    {
        return $this->createQueryBuilder('s')
            ->andWhere('s.plan = :plan')
            ->andWhere('s.statut = :statut')
            ->andWhere('s.dateExpiration > :now')
            ->setParameter('plan', Subscription::PLAN_PREMIUM_PLUS)
            ->setParameter('statut', Subscription::STATUS_ACTIVE)
            ->setParameter('now', new \DateTimeImmutable())
            ->getQuery()
            ->getResult();
    }

    public function countActivePremiumPlus(): int
    {
        return count($this->findActivePremiumPlus());
    }
}
