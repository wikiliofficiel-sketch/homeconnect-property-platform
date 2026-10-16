<?php

namespace App\Controller\Admin;

use App\Entity\Application;
use App\Entity\Visite;
use App\Repository\ApplicationRepository;
use App\Service\NotificationService;
use App\Service\PdfService;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/admin/applications', name: 'admin_applications_')]
#[IsGranted('ROLE_ADMIN')]
class AdminApplicationsController extends AbstractController
{
    // ────────────────────────────────────────────────────────────────────
    // LISTE DES CANDIDATURES
    // ────────────────────────────────────────────────────────────────────

    #[Route('/', name: 'index', methods: ['GET'])]
    public function index(ApplicationRepository $repo, Request $request): Response
    {
        $statut = $request->query->get('statut', '');

        $qb = $repo->createQueryBuilder('a')
            ->leftJoin('a.locataire', 'l')
            ->leftJoin('a.property', 'p')
            ->addSelect('l', 'p')
            ->orderBy('a.createdAt', 'DESC');

        if ($statut && in_array($statut, ['pending', 'accepted', 'refused', 'cancelled'])) {
            $qb->andWhere('a.statut = :statut')->setParameter('statut', $statut);
        }

        $applications = $qb->getQuery()->getResult();

        $stats = [
            'pending'   => $repo->countPending(),
            'accepted'  => $repo->createQueryBuilder('a')->select('COUNT(a.id)')->where('a.statut = :s')->setParameter('s', 'accepted')->getQuery()->getSingleScalarResult(),
            'refused'   => $repo->createQueryBuilder('a')->select('COUNT(a.id)')->where('a.statut = :s')->setParameter('s', 'refused')->getQuery()->getSingleScalarResult(),
            'total'     => $repo->createQueryBuilder('a')->select('COUNT(a.id)')->getQuery()->getSingleScalarResult(),
        ];

        return $this->render('admin/applications/index.html.twig', [
            'applications' => $applications,
            'statut'       => $statut,
            'stats'        => $stats,
        ]);
    }

    // ────────────────────────────────────────────────────────────────────
    // DÉTAIL D'UNE CANDIDATURE
    // ────────────────────────────────────────────────────────────────────

    #[Route('/{id}', name: 'show', methods: ['GET'])]
    public function show(Application $application): Response
    {
        return $this->render('admin/applications/show.html.twig', [
            'application' => $application,
        ]);
    }

    // ────────────────────────────────────────────────────────────────────
    // ACCEPTER
    // ────────────────────────────────────────────────────────────────────

    #[Route('/{id}/accept', name: 'accept', methods: ['POST'])]
    public function accept(
        Application $application,
        EntityManagerInterface $em,
        NotificationService $notificationService
    ): Response {
        if (!$application->isPending()) {
            $this->addFlash('warning', 'Cette candidature a déjà été traitée.');
            return $this->redirectToRoute('admin_applications_show', ['id' => $application->getId()]);
        }

        $application->setStatut('accepted');
        $application->setRespondedAt(new \DateTime());
        $em->flush();

        // Notifier le locataire
        $notificationService->notifyAndFlush(
            $application->getLocataire(),
            'application_accepted',
            sprintf(
                'Votre candidature pour le bien "%s" a été acceptée. Vous pouvez maintenant planifier votre visite.',
                $application->getProperty()->getTitle()
            ),
            'Candidature acceptée',
            $application->getId(),
            'application'
        );

        $this->addFlash('success', 'Candidature acceptée. Le locataire a été notifié.');
        return $this->redirectToRoute('admin_applications_show', ['id' => $application->getId()]);
    }

    // ────────────────────────────────────────────────────────────────────
    // REFUSER
    // ────────────────────────────────────────────────────────────────────

    #[Route('/{id}/refuse', name: 'refuse', methods: ['POST'])]
    public function refuse(
        Application $application,
        Request $request,
        EntityManagerInterface $em,
        NotificationService $notificationService
    ): Response {
        if (!$application->isPending()) {
            $this->addFlash('warning', 'Cette candidature a déjà été traitée.');
            return $this->redirectToRoute('admin_applications_show', ['id' => $application->getId()]);
        }

        $motif = trim($request->request->get('motif', ''));

        $application->setStatut('refused');
        $application->setRespondedAt(new \DateTime());
        $application->setMotifRefus($motif ?: null);
        $em->flush();

        // Notifier le locataire
        $message = sprintf(
            'Votre candidature pour le bien "%s" a été refusée.',
            $application->getProperty()->getTitle()
        );
        if ($motif) {
            $message .= ' Motif : ' . $motif;
        }

        $notificationService->notifyAndFlush(
            $application->getLocataire(),
            'application_refused',
            $message,
            'Candidature refusée',
            $application->getId(),
            'application'
        );

        $this->addFlash('info', 'Candidature refusée. Le locataire a été notifié.');
        return $this->redirectToRoute('admin_applications_show', ['id' => $application->getId()]);
    }

    // ────────────────────────────────────────────────────────────────────
    // PLANIFIER UNE VISITE
    // ────────────────────────────────────────────────────────────────────

    #[Route('/{id}/schedule-visite', name: 'schedule_visite', methods: ['POST'])]
    public function scheduleVisite(
        Application $application,
        Request $request,
        EntityManagerInterface $em,
        NotificationService $notificationService
    ): Response {
        if (!$application->isAccepted()) {
            $this->addFlash('warning', 'Vous ne pouvez planifier une visite que pour une candidature acceptée.');
            return $this->redirectToRoute('admin_applications_show', ['id' => $application->getId()]);
        }

        $dateDebut = $request->request->get('dateHeureDebut');
        $dateFin   = $request->request->get('dateHeureFin');
        $notes     = $request->request->get('notes', '');

        if (!$dateDebut || !$dateFin) {
            $this->addFlash('danger', 'Les dates de début et de fin sont requises.');
            return $this->redirectToRoute('admin_applications_show', ['id' => $application->getId()]);
        }

        try {
            $debut = new \DateTime($dateDebut);
            $fin   = new \DateTime($dateFin);
        } catch (\Exception $e) {
            $this->addFlash('danger', 'Format de date invalide.');
            return $this->redirectToRoute('admin_applications_show', ['id' => $application->getId()]);
        }

        $visite = new Visite();
        $visite->setApplication($application);
        $visite->setDateHeureDebut($debut);
        $visite->setDateHeureFin($fin);
        $visite->setStatut('planifiee');
        $visite->setNotes($notes ?: null);

        $em->persist($visite);
        $em->flush();

        // Notifier le locataire
        $notificationService->notify(
            $application->getLocataire(),
            'visite_planifiee',
            sprintf(
                'Une visite pour le bien "%s" a été planifiée le %s.',
                $application->getProperty()->getTitle(),
                $debut->format('d/m/Y à H:i')
            ),
            'Visite planifiée',
            $visite->getId(),
            'visite'
        );

        // Notifier le propriétaire
        $proprietaire = $application->getProperty()->getProprietaire();
        if ($proprietaire) {
            $notificationService->notify(
                $proprietaire,
                'visite_planifiee',
                sprintf(
                    'Une visite a été planifiée pour votre bien "%s" le %s avec le locataire %s.',
                    $application->getProperty()->getTitle(),
                    $debut->format('d/m/Y à H:i'),
                    $application->getLocataire()->getFullName()
                ),
                'Visite planifiée',
                $visite->getId(),
                'visite'
            );
        }

        $em->flush();

        $this->addFlash('success', 'Visite planifiée. Le locataire et le propriétaire ont été notifiés.');
        return $this->redirectToRoute('admin_applications_show', ['id' => $application->getId()]);
    }

    // ────────────────────────────────────────────────────────────────────
    // GÉNÉRER CONTRAT PDF
    // ────────────────────────────────────────────────────────────────────

    #[Route('/{id}/generate-contract', name: 'generate_contract', methods: ['GET'])]
    public function generateContract(
        Application $application,
        PdfService $pdfService
    ): Response {
        if (!$application->isAccepted()) {
            $this->addFlash('warning', 'Le contrat ne peut être généré que pour une candidature acceptée.');
            return $this->redirectToRoute('admin_applications_show', ['id' => $application->getId()]);
        }

        $pdfContent = $pdfService->generateBinaryPdf(
            'admin/applications/contract_pdf.html.twig',
            ['application' => $application]
        );

        $filename = sprintf(
            'contrat-%s-%s.pdf',
            $application->getId(),
            (new \DateTime())->format('Y-m-d')
        );

        return new Response($pdfContent, 200, [
            'Content-Type'        => 'application/pdf',
            'Content-Disposition' => 'inline; filename="' . $filename . '"',
        ]);
    }
}
