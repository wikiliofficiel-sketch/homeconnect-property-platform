<?php

namespace App\Repository;

use App\Entity\Notification;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<Notification>
 */
class NotificationRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Notification::class);
    }

    public function findByDestinataire(int $destinataireId): array
    {
        return $this->createQueryBuilder('n')
            ->andWhere('n.destinataire = :destinataireId')
            ->setParameter('destinataireId', $destinataireId)
            ->orderBy('n.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    public function findUnread(int $destinataireId): array
    {
        return $this->createQueryBuilder('n')
            ->andWhere('n.destinataire = :destinataireId')
            ->andWhere('n.lue = false')
            ->setParameter('destinataireId', $destinataireId)
            ->orderBy('n.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    public function countUnread(int $destinataireId): int
    {
        return $this->createQueryBuilder('n')
            ->select('COUNT(n.id)')
            ->andWhere('n.destinataire = :destinataireId')
            ->andWhere('n.lue = false')
            ->setParameter('destinataireId', $destinataireId)
            ->getQuery()
            ->getSingleScalarResult();
    }

    public function findByType(int $destinataireId, string $type): array
    {
        return $this->createQueryBuilder('n')
            ->andWhere('n.destinataire = :destinataireId')
            ->andWhere('n.type = :type')
            ->setParameter('destinataireId', $destinataireId)
            ->setParameter('type', $type)
            ->orderBy('n.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }
}
