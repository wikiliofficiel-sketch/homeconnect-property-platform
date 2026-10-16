<?php

namespace App\Service;

use App\Entity\Notification;
use App\Entity\User;
use App\Repository\UserRepository;
use Doctrine\ORM\EntityManagerInterface;

class NotificationService
{
    public function __construct(
        private EntityManagerInterface $em,
        private UserRepository $userRepository
    ) {}

    public function notify(User $destinataire, string $type, string $message, string $title = '', ?int $relatedId = null, ?string $relatedType = null): void
    {
        $notif = new Notification();
        $notif->setDestinataire($destinataire);
        $notif->setType($type);
        $notif->setMessage($message);
        $notif->setTitle($title ?: $this->defaultTitle($type));
        $notif->setRelatedEntityId($relatedId);
        $notif->setRelatedEntityType($relatedType);
        $notif->setLue(false);

        $this->em->persist($notif);
    }

    public function notifyAdmins(string $type, string $message, string $title = '', ?int $relatedId = null, ?string $relatedType = null): void
    {
        $admins = $this->userRepository->findAdmins();
        foreach ($admins as $admin) {
            $this->notify($admin, $type, $message, $title, $relatedId, $relatedType);
        }
        $this->em->flush();
    }

    public function notifyAndFlush(User $destinataire, string $type, string $message, string $title = '', ?int $relatedId = null, ?string $relatedType = null): void
    {
        $this->notify($destinataire, $type, $message, $title, $relatedId, $relatedType);
        $this->em->flush();
    }

    private function defaultTitle(string $type): string
    {
        return match($type) {
            'application_received'   => 'Nouvelle candidature',
            'application_accepted'   => 'Candidature acceptée',
            'application_refused'    => 'Candidature refusée',
            'property_submitted'     => 'Nouveau bien soumis',
            'property_validated'     => 'Bien validé',
            'property_suspended'     => 'Bien suspendu',
            'report_created'         => 'Nouveau signalement',
            'report_resolved'        => 'Signalement traité',
            'message_received'       => 'Nouveau message',
            default                  => 'Notification',
        };
    }
}
