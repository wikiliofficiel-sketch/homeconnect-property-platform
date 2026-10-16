<?php

namespace App\Controller\Api;

use App\Entity\Notification;
use App\Entity\User;
use App\Repository\NotificationRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

#[Route('/api/notifications', name: 'api_notifications_')]
class NotificationController extends AbstractController
{
    #[Route('', name: 'list', methods: ['GET'])]
    public function list(NotificationRepository $repository): JsonResponse
    {
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $notifications = $repository->findBy(
            ['destinataire' => $user],
            ['createdAt' => 'DESC']
        );

        $data = [];
        foreach ($notifications as $notif) {
            $data[] = [
                'id' => $notif->getId(),
                'type' => $notif->getType(),
                'message' => $notif->getMessage(),
                'lue' => $notif->isLue(),
                'createdAt' => $notif->getCreatedAt()->format('c'),
                'relatedEntityId' => $notif->getRelatedEntityId(),
                'relatedEntityType' => $notif->getRelatedEntityType(),
            ];
        }

        return new JsonResponse($data);
    }

    #[Route('/{id}/read', name: 'mark_as_read', methods: ['PATCH'])]
    public function markAsRead(Notification $notif, EntityManagerInterface $em): JsonResponse
    {
        $user = $this->getUser();
        if ($notif->getDestinataire() !== $user) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        $notif->setLue(true);
        $em->flush();

        return new JsonResponse(['message' => 'Notification marked as read']);
    }
}
