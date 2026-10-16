<?php

namespace App\Controller\Admin;

use App\Entity\User;
use App\Repository\UserRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/admin/kyc', name: 'admin_kyc_')]
#[IsGranted('ROLE_ADMIN')]
class AdminKycController extends AbstractController
{
    #[Route('/', name: 'index')]
    public function index(UserRepository $userRepo): Response
    {
        // Propriétaires en attente de validation KYC
        $pendingUsers = $userRepo->createQueryBuilder('u')
            ->where('u.kyc_status = :status')
            ->setParameter('status', 'pending')
            ->andWhere('u.roles LIKE :role')
            ->setParameter('role', '%ROLE_PROPRIETAIRE%')
            ->orderBy('u.kyc_submitted_at', 'ASC')
            ->getQuery()
            ->getResult();

        // Propriétaires déjà traités (certifiés ou rejetés)
        $processedUsers = $userRepo->createQueryBuilder('u')
            ->where('u.kyc_status IN (:statuses)')
            ->setParameter('statuses', ['approved', 'rejected'])
            ->andWhere('u.roles LIKE :role')
            ->setParameter('role', '%ROLE_PROPRIETAIRE%')
            ->orderBy('u.kyc_approved_at', 'DESC')
            ->getQuery()
            ->getResult();

        return $this->render('admin/users/kyc_dashboard.html.twig', [
            'pendingUsers'   => $pendingUsers,
            'processedUsers' => $processedUsers,
        ]);
    }

    #[Route('/{id}/approve', name: 'approve', methods: ['POST'])]
    public function approve(User $user, EntityManagerInterface $em): Response
    {
        $user->setKycStatus('approved');
        $user->setKycApprovedAt(new \DateTimeImmutable());
        $user->setVerificationStatus('certifie');
        $user->setIsVerified(true);
        $em->flush();

        $this->addFlash('success', 'Propriétaire ' . $user->getFullName() . ' certifié avec succès.');
        return $this->redirectToRoute('admin_kyc_index');
    }

    #[Route('/{id}/reject', name: 'reject', methods: ['POST'])]
    public function reject(User $user, Request $request, EntityManagerInterface $em): Response
    {
        $reason = $request->request->get('reason', 'Documents non conformes.');
        $user->setKycStatus('rejected');
        $user->setKycRejectionReason($reason);
        $user->setVerificationStatus('rejete');
        $user->setIsVerified(false);
        $em->flush();

        $this->addFlash('warning', 'Dossier KYC de ' . $user->getFullName() . ' rejeté.');
        return $this->redirectToRoute('admin_kyc_index');
    }

    /**
     * API endpoint for mobile admin: POST /admin/kyc/{id}/approve
     */
    #[Route('/{id}/approve-api', name: 'approve_api', methods: ['POST'])]
    public function approveApi(User $user, EntityManagerInterface $em): JsonResponse
    {
        $user->setKycStatus('approved');
        $user->setKycApprovedAt(new \DateTimeImmutable());
        $user->setVerificationStatus('certifie');
        $user->setIsVerified(true);
        $em->flush();

        return new JsonResponse(['success' => true, 'verificationStatus' => 'certifie']);
    }

    /**
     * API endpoint for mobile admin: POST /admin/kyc/{id}/reject-api
     */
    #[Route('/{id}/reject-api', name: 'reject_api', methods: ['POST'])]
    public function rejectApi(User $user, Request $request, EntityManagerInterface $em): JsonResponse
    {
        $data   = json_decode($request->getContent(), true) ?? [];
        $reason = $data['reason'] ?? $request->request->get('reason', 'Documents non conformes.');
        $user->setKycStatus('rejected');
        $user->setKycRejectionReason($reason);
        $user->setVerificationStatus('rejete');
        $user->setIsVerified(false);
        $em->flush();

        return new JsonResponse(['success' => true, 'verificationStatus' => 'rejete']);
    }
}
