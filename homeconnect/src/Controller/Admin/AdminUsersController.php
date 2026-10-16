<?php

namespace App\Controller\Admin;

use App\Entity\User;
use App\Repository\UserRepository;
use App\Service\LogService;
use App\Service\NotificationService;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

#[Route('/admin/users', name: 'admin_users_')]
#[IsGranted('ROLE_ADMIN')]
class AdminUsersController extends AbstractController
{
    #[Route('/', name: 'index')]
    public function index(UserRepository $userRepo, Request $request): Response
    {
        $role     = $request->query->get('role', '');
        $verified = $request->query->get('verified', '');
        $search   = trim($request->query->get('search', ''));

        $query = $userRepo->createQueryBuilder('u');

        if ($role && in_array($role, ['ROLE_PROPRIETAIRE', 'ROLE_LOCATAIRE', 'ROLE_ADMIN'])) {
            $query->andWhere('u.roles LIKE :role')
                  ->setParameter('role', '%' . $role . '%');
        }

        if ($verified !== '') {
            $query->andWhere('u.isVerified = :verified')
                  ->setParameter('verified', $verified === '1');
        }

        if ($search !== '') {
            $query->andWhere(
                '(LOWER(CONCAT(u.prenom, \' \', u.nom)) LIKE :search OR LOWER(u.email) LIKE :search)'
            )->setParameter('search', '%' . strtolower($search) . '%');
        }

        $users = $query->orderBy('u.createdAt', 'DESC')->getQuery()->getResult();

        return $this->render('admin/users/index.html.twig', [
            'users'    => $users,
            'role'     => $role,
            'verified' => $verified,
            'search'   => $search,
        ]);
    }

    #[Route('/new', name: 'new', methods: ['POST'])]
    public function new(Request $request, EntityManagerInterface $em, UserPasswordHasherInterface $passwordHasher): Response
    {
        $fullName = $request->request->get('fullName');
        $email = $request->request->get('email');
        $password = $request->request->get('password');
        $role = $request->request->get('role');

        $user = new User();
        $user->setEmail($email);
        
        // Séparer le nom complet
        $parts = explode(' ', $fullName, 2);
        $user->setPrenom($parts[0] ?? 'Inconnu');
        $user->setNom($parts[1] ?? 'Inconnu');
        
        $user->setRoles([$role]);
        $user->setPassword($passwordHasher->hashPassword($user, $password));
        $user->setIsVerified(true);
        $user->setCreatedAt(new \DateTimeImmutable());

        $em->persist($user);
        $em->flush();

        $this->addFlash('success', 'Utilisateur créé avec succès !');
        return $this->redirectToRoute('admin_users_index');
    }

    #[Route('/{id}/detail', name: 'show')]
    public function show(User $user): Response
    {
        return $this->render('admin/users/show.html.twig', [
            'user' => $user,
        ]);
    }

    #[Route('/{id}/toggle-verify', name: 'toggle_verify', methods: ['POST'])]
    public function toggleVerify(User $user, EntityManagerInterface $em): Response
    {
        $user->setIsVerified(!$user->isVerified());
        $em->flush();

        $this->addFlash('success', 'Vérification mise à jour');
        return $this->redirectToRoute('admin_users_show', ['id' => $user->getId()]);
    }

    #[Route('/{id}/add-role', name: 'add_role', methods: ['POST'])]
    public function addRole(User $user, Request $request, EntityManagerInterface $em, LogService $logService): Response
    {
        $role = $request->request->get('role');
        $roles = $user->getRoles();

        if ($role && !in_array($role, $roles)) {
            $roles[] = $role;
            $user->setRoles($roles);
            $em->flush();
            $logService->userRoleChanged($user->getFullName(), $user->getId(), $role);
            $this->addFlash('success', 'Rôle ajouté');
        }

        return $this->redirectToRoute('admin_users_show', ['id' => $user->getId()]);
    }

    #[Route('/{id}/kyc-approve', name: 'kyc_approve', methods: ['POST'])]
    public function kycApprove(int $id, UserRepository $userRepo, EntityManagerInterface $em, LogService $logService): Response
    {
        $user = $userRepo->find($id);
        if (!$user) { $this->addFlash('error', 'Utilisateur introuvable'); return $this->redirectToRoute('admin_users_index'); }

        $user->setKycStatus('approved');
        $user->setKycApprovedAt(new \DateTimeImmutable());
        $user->setVerificationStatus('certifie');
        $user->setIsVerified(true);
        $em->flush();

        $logService->kycApproved($user->getFullName(), $user->getId());

        $this->addFlash('success', 'Compte de ' . $user->getFullName() . ' certifié avec succès.');
        return $this->redirectToRoute('admin_users_show', ['id' => $user->getId()]);
    }

    #[Route('/{id}/kyc-reject', name: 'kyc_reject', methods: ['POST'])]
    public function kycReject(int $id, Request $request, UserRepository $userRepo, EntityManagerInterface $em, LogService $logService): Response
    {
        $user = $userRepo->find($id);
        if (!$user) { $this->addFlash('error', 'Utilisateur introuvable'); return $this->redirectToRoute('admin_users_index'); }

        $reason = $request->request->get('reason', 'Document invalide ou illisible.');
        $user->setKycStatus('rejected');
        $user->setKycRejectionReason($reason);
        $user->setVerificationStatus('rejete');
        $em->flush();

        $logService->kycRejected($user->getFullName(), $user->getId(), $reason);

        $this->addFlash('warning', 'Dossier KYC de ' . $user->getFullName() . ' rejeté.');
        return $this->redirectToRoute('admin_users_show', ['id' => $user->getId()]);
    }

    #[Route('/{id}/delete', name: 'delete', methods: ['POST'])]
    public function delete(int $id, UserRepository $userRepo, EntityManagerInterface $em, LogService $logService): Response
    {
        $user = $userRepo->find($id);
        if (!$user) {
            $this->addFlash('warning', 'Utilisateur introuvable (déjà supprimé ?)');
            return $this->redirectToRoute('admin_users_index');
        }

        if ($user === $this->getUser()) {
            $this->addFlash('error', 'Vous ne pouvez pas supprimer votre propre compte.');
            return $this->redirectToRoute('admin_users_index');
        }

        $name = $user->getFullName();
        $uid  = $user->getId();
        $em->remove($user);
        $em->flush();

        $logService->userDeleted($name, $uid);

        $this->addFlash('success', 'Utilisateur supprimé avec succès.');
        return $this->redirectToRoute('admin_users_index');
    }

    // ── SANCTIONS ─────────────────────────────────────────────────────────

    #[Route('/{id}/warn', name: 'warn', methods: ['POST'])]
    public function warn(User $user, Request $request, EntityManagerInterface $em, NotificationService $notificationService): Response
    {
        if ($user === $this->getUser()) {
            $this->addFlash('error', 'Action impossible sur votre propre compte.');
            return $this->redirectToRoute('admin_users_show', ['id' => $user->getId()]);
        }

        $motif = trim($request->request->get('motif', 'Comportement contraire aux règles de la plateforme.'));
        $user->setWarningsCount($user->getWarningsCount() + 1);
        $em->flush();

        $notificationService->notifyAndFlush(
            $user,
            'report_warning',
            sprintf('⚠️ Avertissement #%d : %s', $user->getWarningsCount(), $motif),
            'Avertissement administratif',
            $user->getId(),
            'user'
        );

        $this->addFlash('success', sprintf('Avertissement envoyé à %s (total : %d).', $user->getFullName(), $user->getWarningsCount()));
        return $this->redirectToRoute('admin_users_show', ['id' => $user->getId()]);
    }

    #[Route('/{id}/suspend', name: 'suspend', methods: ['POST'])]
    public function suspend(User $user, Request $request, EntityManagerInterface $em, NotificationService $notificationService): Response
    {
        if ($user === $this->getUser()) {
            $this->addFlash('error', 'Action impossible sur votre propre compte.');
            return $this->redirectToRoute('admin_users_show', ['id' => $user->getId()]);
        }

        $days  = max(1, (int) $request->request->get('days', 7));
        $motif = trim($request->request->get('motif', 'Non-respect des règles de la plateforme.'));
        $until = (new \DateTimeImmutable())->modify("+{$days} days");

        $user->setIsSuspended(true);
        $user->setSuspendedUntil($until);
        $em->flush();

        $notificationService->notifyAndFlush(
            $user,
            'security_alert',
            sprintf('Votre compte a été suspendu pour %d jour(s) (jusqu\'au %s). Motif : %s', $days, $until->format('d/m/Y'), $motif),
            'Compte suspendu',
            $user->getId(),
            'user'
        );

        $this->addFlash('success', sprintf('%s suspendu(e) pour %d jour(s).', $user->getFullName(), $days));
        return $this->redirectToRoute('admin_users_show', ['id' => $user->getId()]);
    }

    #[Route('/{id}/unsuspend', name: 'unsuspend', methods: ['POST'])]
    public function unsuspend(User $user, EntityManagerInterface $em, NotificationService $notificationService): Response
    {
        $user->setIsSuspended(false);
        $user->setSuspendedUntil(null);
        $em->flush();

        $notificationService->notifyAndFlush(
            $user,
            'security_alert',
            'Votre suspension a été levée. Vous pouvez à nouveau accéder à la plateforme normalement.',
            'Suspension levée',
            $user->getId(),
            'user'
        );

        $this->addFlash('success', sprintf('Suspension de %s levée.', $user->getFullName()));
        return $this->redirectToRoute('admin_users_show', ['id' => $user->getId()]);
    }

    #[Route('/{id}/ban', name: 'ban', methods: ['POST'])]
    public function ban(User $user, Request $request, EntityManagerInterface $em, NotificationService $notificationService): Response
    {
        if ($user === $this->getUser()) {
            $this->addFlash('error', 'Action impossible sur votre propre compte.');
            return $this->redirectToRoute('admin_users_show', ['id' => $user->getId()]);
        }

        $motif = trim($request->request->get('motif', 'Violation grave des conditions d\'utilisation.'));

        $user->setIsBanned(true);
        $user->setIsSuspended(false);
        $user->setSuspendedUntil(null);
        $em->flush();

        $notificationService->notifyAndFlush(
            $user,
            'security_alert',
            sprintf('Votre compte a été définitivement banni. Motif : %s', $motif),
            'Compte banni',
            $user->getId(),
            'user'
        );

        $this->addFlash('success', sprintf('%s banni(e) définitivement.', $user->getFullName()));
        return $this->redirectToRoute('admin_users_show', ['id' => $user->getId()]);
    }

    #[Route('/{id}/unban', name: 'unban', methods: ['POST'])]
    public function unban(User $user, EntityManagerInterface $em, NotificationService $notificationService): Response
    {
        $user->setIsBanned(false);
        $em->flush();

        $notificationService->notifyAndFlush(
            $user,
            'security_alert',
            'Votre bannissement a été levé. Vous pouvez à nouveau accéder à la plateforme.',
            'Bannissement levé',
            $user->getId(),
            'user'
        );

        $this->addFlash('success', sprintf('Bannissement de %s levé.', $user->getFullName()));
        return $this->redirectToRoute('admin_users_show', ['id' => $user->getId()]);
    }
}
