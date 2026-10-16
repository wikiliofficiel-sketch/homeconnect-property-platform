<?php

namespace App\Repository;

use App\Entity\Review;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<Review>
 */
class ReviewRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Review::class);
    }

    public function findByTargetUser(int $userId): array
    {
        return $this->createQueryBuilder('r')
            ->andWhere('r.targetUser = :userId')
            ->setParameter('userId', $userId)
            ->orderBy('r.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    public function findByAuthor(int $authorId): array
    {
        return $this->createQueryBuilder('r')
            ->andWhere('r.author = :authorId')
            ->setParameter('authorId', $authorId)
            ->orderBy('r.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    public function findByRental(int $rentalId): array
    {
        return $this->createQueryBuilder('r')
            ->andWhere('r.rental = :rentalId')
            ->setParameter('rentalId', $rentalId)
            ->getQuery()
            ->getResult();
    }

    public function calculateAverageRating(int $userId): float
    {
        $result = $this->createQueryBuilder('r')
            ->select('AVG(r.rating) as avg_rating')
            ->andWhere('r.targetUser = :userId')
            ->setParameter('userId', $userId)
            ->getQuery()
            ->getOneOrNullResult();

        return $result['avg_rating'] ? round($result['avg_rating'], 1) : 0;
    }

    public function countReviews(int $userId): int
    {
        return $this->createQueryBuilder('r')
            ->select('COUNT(r.id)')
            ->andWhere('r.targetUser = :userId')
            ->setParameter('userId', $userId)
            ->getQuery()
            ->getSingleScalarResult();
    }

    public function getRatingDistribution(int $userId): array
    {
        $distribution = [];
        for ($i = 5; $i >= 1; $i--) {
            $count = $this->createQueryBuilder('r')
                ->select('COUNT(r.id)')
                ->andWhere('r.targetUser = :userId')
                ->andWhere('r.rating = :rating')
                ->setParameter('userId', $userId)
                ->setParameter('rating', $i)
                ->getQuery()
                ->getSingleScalarResult();
            $distribution[$i] = $count;
        }
        return $distribution;
    }
}
