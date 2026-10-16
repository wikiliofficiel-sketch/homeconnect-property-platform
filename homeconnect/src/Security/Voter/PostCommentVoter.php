<?php

namespace App\Security\Voter;

use App\Entity\PostComment;
use App\Entity\User;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Core\Authorization\Voter\Voter;

class PostCommentVoter extends Voter
{
    public const VIEW = 'VIEW';
    public const EDIT = 'EDIT';
    public const DELETE = 'DELETE';

    protected function supports(string $attribute, mixed $subject): bool
    {
        return in_array($attribute, [self::VIEW, self::EDIT, self::DELETE])
            && $subject instanceof PostComment;
    }

    protected function voteOnAttribute(string $attribute, mixed $subject, TokenInterface $token): bool
    {
        /** @var User $user */
        $user = $token->getUser();

        if (!$user instanceof User) {
            return false;
        }

        /** @var PostComment $comment */
        $comment = $subject;

        switch ($attribute) {
            case self::VIEW:
                return $this->canView($comment, $user);
            case self::EDIT:
                return $this->canEdit($comment, $user);
            case self::DELETE:
                return $this->canDelete($comment, $user);
        }

        return false;
    }

    private function canView(PostComment $comment, User $user): bool
    {
        // Anyone can view published comments
        return true;
    }

    private function canEdit(PostComment $comment, User $user): bool
    {
        // Only author can edit own comment
        return $comment->getAuthor() === $user;
    }

    private function canDelete(PostComment $comment, User $user): bool
    {
        // Only author can delete own comment
        return $comment->getAuthor() === $user;
    }
}
