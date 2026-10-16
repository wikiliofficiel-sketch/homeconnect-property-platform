<?php

namespace App\Controller\Api;

use App\Entity\Message;
use App\Entity\User;
use App\Repository\MessageRepository;

use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

#[Route('/api/messages', name: 'api_messages_')]
class MessageController extends AbstractController
{
    // ── Conversations ────────────────────────────────────────────────────────

    #[Route('/conversations', name: 'conversations', methods: ['GET'])]
    public function conversations(MessageRepository $repo): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $messages = $repo->createQueryBuilder('m')
            ->where('(m.sender = :user AND m.deletedForSender = false)')
            ->orWhere('(m.receiver = :user AND m.deletedForReceiver = false)')
            ->setParameter('user', $user)
            ->orderBy('m.createdAt', 'DESC')
            ->getQuery()
            ->getResult();

        $convs = [];
        foreach ($messages as $msg) {
            /** @var Message $msg */
            $isMine  = $msg->getSender()->getId() === $user->getId();
            $partner = $isMine ? $msg->getReceiver() : $msg->getSender();
            $pid     = $partner->getId();

            if (!isset($convs[$pid])) {
                $convs[$pid] = [
                    'partnerId'    => $pid,
                    'partnerName'  => $partner->getFullName(),
                    'partnerEmail' => $partner->getEmail(),
                    'lastMessage'  => $msg->toApiArray($user->getId()),
                    'unreadCount'  => 0,
                ];
            }
            if (!$isMine && $msg->getStatus() !== Message::STATUS_READ) {
                $convs[$pid]['unreadCount']++;
            }
        }

        return new JsonResponse(array_values($convs));
    }

    // ── Messages d'une conversation ──────────────────────────────────────────

    #[Route('/conversation/{partnerId}', name: 'conversation', methods: ['GET'])]
    public function conversation(int $partnerId, MessageRepository $repo, EntityManagerInterface $em): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $partner = $em->getRepository(User::class)->find($partnerId);
        if (!$partner) {
            return new JsonResponse(['error' => 'Utilisateur introuvable'], Response::HTTP_NOT_FOUND);
        }

        $messages = $repo->createQueryBuilder('m')
            ->where('(m.sender = :user AND m.receiver = :partner AND m.deletedForSender = false)')
            ->orWhere('(m.sender = :partner AND m.receiver = :user AND m.deletedForReceiver = false)')
            ->setParameter('user', $user)
            ->setParameter('partner', $partner)
            ->orderBy('m.createdAt', 'ASC')
            ->getQuery()
            ->getResult();

        $uid = $user->getId();
        foreach ($messages as $msg) {
            if ($msg->getReceiver()->getId() === $uid && $msg->getStatus() !== Message::STATUS_READ) {
                $msg->setStatus(Message::STATUS_READ);
                $msg->setReadAt(new \DateTimeImmutable());
            }
        }
        $em->flush();

        return new JsonResponse(array_map(fn(Message $m) => $m->toApiArray($uid), $messages));
    }

    // ── Envoyer ──────────────────────────────────────────────────────────────

    #[Route('/send', name: 'send', methods: ['POST'])]
    public function send(Request $request, EntityManagerInterface $em): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $data = json_decode($request->getContent(), true) ?? [];
        if (empty($data['receiverId'])) {
            return new JsonResponse(['error' => 'receiverId requis'], Response::HTTP_BAD_REQUEST);
        }

        $receiver = $em->getRepository(User::class)->find($data['receiverId']);
        if (!$receiver) {
            return new JsonResponse(['error' => 'Destinataire introuvable'], Response::HTTP_NOT_FOUND);
        }

        $msg = new Message();
        $msg->setSender($user);
        $msg->setReceiver($receiver);
        $msg->setContent($data['content'] ?? $data['text'] ?? null);
        $msg->setType($data['type'] ?? Message::TYPE_TEXT);
        $msg->setStatus(Message::STATUS_SENT);
        $msg->setAttachmentUrl($data['attachmentUrl'] ?? null);
        $msg->setAttachmentName($data['attachmentName'] ?? null);
        $msg->setAttachmentSize(isset($data['attachmentSize']) ? (int)$data['attachmentSize'] : null);
        $msg->setVoiceDuration(isset($data['voiceDuration']) ? (int)$data['voiceDuration'] : null);
        $msg->setCallType($data['callType'] ?? null);
        $msg->setCallDuration(isset($data['callDuration']) ? (int)$data['callDuration'] : null);
        $msg->setCallStatus($data['callStatus'] ?? null);

        if (!empty($data['replyToId'])) {
            $replyTo = $em->getRepository(Message::class)->find($data['replyToId']);
            if ($replyTo) $msg->setReplyTo($replyTo);
        }

        $em->persist($msg);
        $em->flush();

        return new JsonResponse($msg->toApiArray($user->getId()), Response::HTTP_CREATED);
    }

    // ── Transférer ───────────────────────────────────────────────────────────

    #[Route('/{id}/forward', name: 'forward_msg', methods: ['POST'])]
    public function forwardMessage(Message $original, Request $request, EntityManagerInterface $em): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $data = json_decode($request->getContent(), true) ?? [];
        if (empty($data['receiverIds']) || !is_array($data['receiverIds'])) {
            return new JsonResponse(['error' => 'receiverIds (tableau) requis'], Response::HTTP_BAD_REQUEST);
        }

        $sent = [];
        foreach ($data['receiverIds'] as $rid) {
            $receiver = $em->getRepository(User::class)->find($rid);
            if (!$receiver) continue;
            $fwd = new Message();
            $fwd->setSender($user);
            $fwd->setReceiver($receiver);
            $fwd->setContent($original->getContent());
            $fwd->setType($original->getType());
            $fwd->setAttachmentUrl($original->getAttachmentUrl());
            $fwd->setForwardedFrom($original);
            $fwd->setStatus(Message::STATUS_SENT);
            $em->persist($fwd);
            $sent[] = $fwd->toApiArray($user->getId());
        }
        $em->flush();

        return new JsonResponse(['forwarded' => $sent], Response::HTTP_CREATED);
    }

    // ── Marquer comme lu ────────────────────────────────────────────────────

    #[Route('/{id}/read', name: 'mark_read', methods: ['PATCH'])]
    public function markAsRead(Message $message, EntityManagerInterface $em): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        if ($message->getReceiver()?->getId() !== $user?->getId()) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }
        $message->setStatus(Message::STATUS_READ);
        $message->setReadAt(new \DateTimeImmutable());
        $em->flush();
        return new JsonResponse(['ok' => true]);
    }

    // ── Éditer ───────────────────────────────────────────────────────────────

    #[Route('/{id}/edit', name: 'edit', methods: ['PATCH'])]
    public function edit(Message $message, Request $request, EntityManagerInterface $em): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        if ($message->getSender()?->getId() !== $user?->getId()) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }
        if ($message->getType() !== Message::TYPE_TEXT) {
            return new JsonResponse(['error' => 'Seuls les textes sont éditables'], Response::HTTP_BAD_REQUEST);
        }
        $data = json_decode($request->getContent(), true) ?? [];
        $message->setContent($data['content'] ?? $message->getContent());
        $message->setIsEdited(true);
        $message->setUpdatedAt(new \DateTimeImmutable());
        $em->flush();
        return new JsonResponse($message->toApiArray($user->getId()));
    }

    // ── Supprimer ────────────────────────────────────────────────────────────

    #[Route('/{id}/delete', name: 'delete', methods: ['DELETE'])]
    public function delete(Message $message, Request $request, EntityManagerInterface $em): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        $uid  = $user?->getId();
        $data = json_decode($request->getContent(), true) ?? [];
        $forAll = (bool)($data['forAll'] ?? false);

        if ($message->getSender()?->getId() === $uid) {
            $message->setDeletedForSender(true);
            if ($forAll) $message->setDeletedForReceiver(true);
        } elseif ($message->getReceiver()?->getId() === $uid) {
            $message->setDeletedForReceiver(true);
        } else {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        $em->flush();
        return new JsonResponse(['ok' => true]);
    }

    // ── Réactions emoji ──────────────────────────────────────────────────────

    #[Route('/{id}/react', name: 'react', methods: ['POST'])]
    public function react(Message $message, Request $request, EntityManagerInterface $em): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $data      = json_decode($request->getContent(), true) ?? [];
        $emoji     = $data['emoji'] ?? null;
        $uid       = $user->getId();
        $reactions = $message->getReactionsArray();

        if (!$emoji) {
            return new JsonResponse(['error' => 'emoji requis'], Response::HTTP_BAD_REQUEST);
        }

        // Toggle
        if (isset($reactions[$emoji]) && in_array($uid, $reactions[$emoji])) {
            $reactions[$emoji] = array_values(array_filter($reactions[$emoji], fn($id) => $id !== $uid));
            if (empty($reactions[$emoji])) unset($reactions[$emoji]);
        } else {
            foreach ($reactions as $e => $uids) {
                $reactions[$e] = array_values(array_filter($uids, fn($id) => $id !== $uid));
                if (empty($reactions[$e])) unset($reactions[$e]);
            }
            $reactions[$emoji][] = $uid;
        }

        $message->setReactions($reactions ? json_encode($reactions) : null);
        $em->flush();
        return new JsonResponse(['reactions' => $reactions]);
    }

    // ── Log d'appel ──────────────────────────────────────────────────────────

    #[Route('/call-log', name: 'call_log', methods: ['POST'])]
    public function callLog(Request $request, EntityManagerInterface $em): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $data     = json_decode($request->getContent(), true) ?? [];
        $receiver = $em->getRepository(User::class)->find($data['receiverId'] ?? 0);
        if (!$receiver) {
            return new JsonResponse(['error' => 'Destinataire introuvable'], Response::HTTP_NOT_FOUND);
        }

        $msg = new Message();
        $msg->setSender($user);
        $msg->setReceiver($receiver);
        $msg->setType(Message::TYPE_CALL);
        $msg->setCallType($data['callType'] ?? 'audio');
        $msg->setCallDuration(isset($data['duration']) ? (int)$data['duration'] : null);
        $msg->setCallStatus($data['status'] ?? Message::CALL_MISSED);
        $msg->setStatus(Message::STATUS_DELIVERED);
        $em->persist($msg);
        $em->flush();

        return new JsonResponse($msg->toApiArray($user->getId()), Response::HTTP_CREATED);
    }

    // ── Statut en ligne (stub — utiliser Mercure en production) ─────────────

    #[Route('/online-status', name: 'online_status', methods: ['GET'])]
    public function onlineStatus(): JsonResponse
    {
        return new JsonResponse(['online' => []]);
    }

    // ── Compat mobile : GET /api/messages/{email} ────────────────────────────

    #[Route('/{userEmail}', name: 'list_by_email', methods: ['GET'])]
    public function listByEmail(MessageRepository $repository): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $uid = $user->getId();
        $messages = $repository->createQueryBuilder('m')
            ->where('(m.sender = :user AND m.deletedForSender = false)')
            ->orWhere('(m.receiver = :user AND m.deletedForReceiver = false)')
            ->setParameter('user', $user)
            ->orderBy('m.createdAt', 'ASC')
            ->getQuery()
            ->getResult();

        return new JsonResponse(array_map(fn(Message $m) => $m->toApiArray($uid), $messages));
    }
}
