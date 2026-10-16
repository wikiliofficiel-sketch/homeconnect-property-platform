<?php

namespace App\Security;

use App\Entity\Property;
use App\Entity\Application;
use App\Entity\User;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Core\Authorization\Voter\Voter;
use Symfony\Component\Security\Core\User\UserInterface;

class PropertyVoter extends Voter
{
    public const VIEW = 'view';
    public const EDIT = 'edit';
    public const DELETE = 'delete';

    protected function supports(string $attribute, mixed $subject): bool
    {
        return in_array($attribute, [self::VIEW, self::EDIT, self::DELETE])
            && ($subject instanceof Property || $subject instanceof Application);
    }

    protected function voteOnAttribute(string $attribute, mixed $subject, TokenInterface $token): bool
    {
        /** @var User $user */
        $user = $token->getUser();

        if (!$user instanceof User) {
            return false;
        }

        // Admin can do anything
        if (in_array('ROLE_ADMIN', $user->getRoles())) {
            return true;
        }

        if ($subject instanceof Property) {
            return $this->voteOnProperty($attribute, $subject, $user);
        }

        if ($subject instanceof Application) {
            return $this->voteOnApplication($attribute, $subject, $user);
        }

        return false;
    }

    private function voteOnProperty(string $attribute, Property $property, User $user): bool
    {
        // Only proprietaire can edit/delete their own property
        if ($property->getProprietaire()->getId() !== $user->getId()) {
            return false;
        }

        return in_array($attribute, [self::VIEW, self::EDIT, self::DELETE]);
    }

    private function voteOnApplication(string $attribute, Application $application, User $user): bool
    {
        // Proprietaire can manage applications for their properties
        if ($application->getProperty()->getProprietaire()->getId() === $user->getId()) {
            return in_array($attribute, [self::VIEW, self::EDIT]);
        }

        // Locataire can view their own applications
        if ($application->getLocataire()->getId() === $user->getId() && $attribute === self::VIEW) {
            return true;
        }

        return false;
    }
}
