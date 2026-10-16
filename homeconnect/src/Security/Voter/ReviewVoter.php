<?php

namespace App\Security\Voter;

use App\Entity\Review;
use App\Entity\User;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Core\Authorization\Voter\Voter;

class ReviewVoter extends Voter
{
    public const VIEW = 'VIEW';
    public const EDIT = 'EDIT';
    public const DELETE = 'DELETE';

    protected function supports(string $attribute, mixed $subject): bool
    {
        return in_array($attribute, [self::VIEW, self::EDIT, self::DELETE])
            && $subject instanceof Review;
    }

    protected function voteOnAttribute(string $attribute, mixed $subject, TokenInterface $token): bool
    {
        /** @var User $user */
        $user = $token->getUser();

        if (!$user instanceof User) {
            return false;
        }

        /** @var Review $review */
        $review = $subject;

        switch ($attribute) {
            case self::VIEW:
                return $this->canView($review, $user);
            case self::EDIT:
                return $this->canEdit($review, $user);
            case self::DELETE:
                return $this->canDelete($review, $user);
        }

        return false;
    }

    private function canView(Review $review, User $user): bool
    {
        // Target user or author can view
        return $review->getTargetUser() === $user || $review->getAuthor() === $user;
    }

    private function canEdit(Review $review, User $user): bool
    {
        // Only author can edit own review
        return $review->getAuthor() === $user;
    }

    private function canDelete(Review $review, User $user): bool
    {
        // Only author can delete own review
        return $review->getAuthor() === $user;
    }
}
