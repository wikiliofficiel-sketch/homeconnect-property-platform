<?php

namespace App\Repository;

use App\Entity\Message;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/** @extends ServiceEntityRepository<Message> */
class MessageRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Message::class);
    }

    /** @return Message[] Messages d'une conversation triés ASC */
    public function findConversation(int $userId1, int $userId2): array
    {
        return $this->createQueryBuilder('m')
            ->where('(m.sender = :u1 AND m.receiver = :u2 AND m.deletedForSender = false)')
            ->orWhere('(m.sender = :u2 AND m.receiver = :u1 AND m.deletedForReceiver = false)')
            ->setParameter('u1', $userId1)
            ->setParameter('u2', $userId2)
            ->orderBy('m.createdAt', 'ASC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Retourne les conversations d'un utilisateur avec le dernier message de chaque.
     * Format : [['partner' => User, 'lastMessage' => Message, 'unreadCount' => int], ...]
     */
    public function findConversationsForUser(int $userId): array
    {
        $messages = $this->createQueryBuilder('m')
            ->addSelect('sender', 'receiver')
            ->innerJoin('m.sender', 'sender')
            ->innerJoin('m.receiver', 'receiver')
            ->where('(m.sender = :uid AND m.deletedForSender = false)')
            ->orWhere('(m.receiver = :uid AND m.deletedForReceiver = false)')
            ->setParameter('uid', $userId)
            ->orderBy('m.createdAt', 'DESC')
            ->getQuery()
            ->getResult();

        $convs = [];
        foreach ($messages as $msg) {
            /** @var Message $msg */
            $isMine  = $msg->getSender()->getId() === $userId;
            $partner = $isMine ? $msg->getReceiver() : $msg->getSender();
            $pid     = $partner->getId();

            if (!isset($convs[$pid])) {
                $convs[$pid] = [
                    'partner'     => $partner,
                    'lastMessage' => $msg,
                    'unreadCount' => 0,
                ];
            }
            if (!$isMine && $msg->getStatus() !== Message::STATUS_READ) {
                $convs[$pid]['unreadCount']++;
            }
        }

        return array_values($convs);
    }

    /** @return Message[] N derniers messages reçus */
    public function findRecentReceived(int $userId, int $limit = 5): array
    {
        return $this->createQueryBuilder('m')
            ->addSelect('sender')
            ->innerJoin('m.sender', 'sender')
            ->andWhere('m.receiver = :uid')
            ->andWhere('m.deletedForReceiver = false')
            ->setParameter('uid', $userId)
            ->orderBy('m.createdAt', 'DESC')
            ->setMaxResults($limit)
            ->getQuery()
            ->getResult();
    }

    public function countUnreadReceived(int $userId): int
    {
        return (int) $this->createQueryBuilder('m')
            ->select('COUNT(m.id)')
            ->andWhere('m.receiver = :uid')
            ->andWhere('m.status != :read')
            ->andWhere('m.deletedForReceiver = false')
            ->setParameter('uid', $userId)
            ->setParameter('read', Message::STATUS_READ)
            ->getQuery()
            ->getSingleScalarResult();
    }

    public function findUserContacts(int $userId): array
    {
        $sent = $this->createQueryBuilder('m')
            ->select('DISTINCT receiver.id')
            ->innerJoin('m.receiver', 'receiver')
            ->andWhere('m.sender = :uid')
            ->setParameter('uid', $userId)
            ->getQuery()->getArrayResult();

        $received = $this->createQueryBuilder('m')
            ->select('DISTINCT sender.id')
            ->innerJoin('m.sender', 'sender')
            ->andWhere('m.receiver = :uid')
            ->setParameter('uid', $userId)
            ->getQuery()->getArrayResult();

        return array_unique(array_merge(
            array_column($sent, 'id'),
            array_column($received, 'id')
        ));
    }

    public function findAllMessageContacts(): array
    {
        $senders   = $this->createQueryBuilder('m')->select('DISTINCT sender.id')->innerJoin('m.sender', 'sender')->getQuery()->getArrayResult();
        $receivers = $this->createQueryBuilder('m')->select('DISTINCT receiver.id')->innerJoin('m.receiver', 'receiver')->getQuery()->getArrayResult();
        return array_unique(array_merge(array_column($senders, 'id'), array_column($receivers, 'id')));
    }
}
