<?php

namespace App\Security\Voter;

use App\Entity\CommunityReport;
use App\Entity\User;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Core\Authorization\Voter\Voter;

class CommunityReportVoter extends Voter
{
    public const VIEW = 'VIEW';
    public const EDIT = 'EDIT';

    protected function supports(string $attribute, mixed $subject): bool
    {
        return in_array($attribute, [self::VIEW, self::EDIT])
            && $subject instanceof CommunityReport;
    }

    protected function voteOnAttribute(string $attribute, mixed $subject, TokenInterface $token): bool
    {
        /** @var User $user */
        $user = $token->getUser();

        if (!$user instanceof User) {
            return false;
        }

        /** @var CommunityReport $report */
        $report = $subject;

        switch ($attribute) {
            case self::VIEW:
                return $this->canView($report, $user);
            case self::EDIT:
                return $this->canEdit($report, $user);
        }

        return false;
    }

    private function canView(CommunityReport $report, User $user): bool
    {
        // Only reporter can view their own report
        return $report->getReporter() === $user;
    }

    private function canEdit(CommunityReport $report, User $user): bool
    {
        // Only admin can edit/review reports
        return in_array('ROLE_ADMIN', $user->getRoles());
    }
}
