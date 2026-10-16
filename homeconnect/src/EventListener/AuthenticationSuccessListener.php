<?php

namespace App\EventListener;

use Lexik\Bundle\JWTAuthenticationBundle\Event\AuthenticationSuccessEvent;
use App\Entity\User;

class AuthenticationSuccessListener
{
    public function onAuthenticationSuccessResponse(AuthenticationSuccessEvent $event)
    {
        $data = $event->getData();
        $user = $event->getUser();

        if (!$user instanceof User) {
            return;
        }

        $roles = $user->getRoles();
        $role = 'locataire'; // Par défaut

        if (in_array('ROLE_ADMIN', $roles)) {
            $role = 'admin';
        } elseif (in_array('ROLE_PROPRIETAIRE', $roles)) {
            $role = 'proprietaire';
        } elseif (in_array('ROLE_LOCATAIRE', $roles)) {
            $role = 'locataire';
        }


        $data['user'] = [
            'id' => $user->getId(),
            'email' => $user->getEmail(),
            'nom' => $user->getNom() ?? '',
            'prenom' => $user->getPrenom() ?? '',
            'telephone' => $user->getTelephone() ?? '',
            'role' => $role,
            'isVerified' => $user->isVerified() ? 1 : 0,
            'verificationStatus' => $user->getVerificationStatus() ?? 'en_attente',
            'subscriptionType' => $user->getSubscriptionType(),
            'subscriptionExpiry' => $user->getSubscriptionExpiry() ? $user->getSubscriptionExpiry()->format(\DateTime::ATOM) : null,
            'rating' => $user->getRating(),
            'reviewCount' => $user->getReviewCount(),
        ];

        // LOGGING TEMPORAIRE POUR DEBUG
        error_log("[AuthSuccess] Sending response for user: " . $user->getEmail() . " with role: " . $role);
        error_log("[AuthSuccess] Data: " . json_encode($data['user']));

        $event->setData($data);
    }
}
