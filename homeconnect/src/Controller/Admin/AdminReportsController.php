<?php

namespace App\Controller\Admin;

use App\Entity\Report;
use App\Entity\PropertyComment;
use App\Repository\ReportRepository;
use App\Repository\PropertyInteractionRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/admin/reports', name: 'admin_reports_')]
#[IsGranted('ROLE_ADMIN')]
class AdminReportsController extends AbstractController
{
    #[Route('/', name: 'index')]
    public function index(ReportRepository $reportRepo, Request $request): Response
    {
        $statut = $request->query->get('status', Report::STATUS_OPEN);
        $priorite = $request->query->get('priority', '');

        $query = $reportRepo->createQueryBuilder('r');

        if ($statut && in_array($statut, [Report::STATUS_OPEN, Report::STATUS_IN_REVIEW, Report::STATUS_RESOLVED, Report::STATUS_DISMISSED])) {
            $query->andWhere('r.statut = :statut')
                  ->setParameter('statut', $statut);
        }

        if ($priorite && in_array($priorite, [Report::PRIORITY_LOW, Report::PRIORITY_MEDIUM, Report::PRIORITY_HIGH, Report::PRIORITY_CRITICAL])) {
            $query->andWhere('r.priorite = :priorite')
                  ->setParameter('priorite', $priorite);
        }

        $reports = $query->orderBy('r.priorite', 'DESC')
                        ->addOrderBy('r.createdAt', 'DESC')
                        ->getQuery()
                        ->getResult();

        $stats = [
            'open' => count($reportRepo->findByStatut(Report::STATUS_OPEN)),
            'critical' => count($reportRepo->findByPriorite(Report::PRIORITY_CRITICAL)),
        ];

        return $this->render('admin/reports/index.html.twig', [
            'reports' => $reports,
            'statut' => $statut,
            'priorite' => $priorite,
            'stats' => $stats,
        ]);
    }

    #[Route('/{id}/detail', name: 'show')]
    public function show(Report $report): Response
    {
        return $this->render('admin/reports/show.html.twig', [
            'report' => $report,
        ]);
    }

    #[Route('/{id}/resolve', name: 'resolve', methods: ['POST'])]
    public function resolve(Report $report, Request $request, EntityManagerInterface $em): Response
    {
        $sanction = $request->request->get('sanction');
        $noteAdmin = $request->request->get('note', '');

        $report->setStatut(Report::STATUS_RESOLVED);
        $report->setSanction($sanction);
        $report->setNoteAdmin($noteAdmin);
        $report->setResolvedAt(new \DateTimeImmutable());

        // Notification au signataire
        $notifReporter = new \App\Entity\Notification();
        $notifReporter->setDestinataire($report->getSignataire());
        $notifReporter->setType('report_resolved');
        $notifReporter->setTitle('Signalement traité');
        $notifReporter->setMessage('Votre signalement #' . $report->getId() . ' a été traité par l\'administration.');
        $em->persist($notifReporter);

        // Si sanction = bannissement, on bannit l'utilisateur
        if ($sanction === 'ban' && $report->getUtilisateur()) {
            $report->getUtilisateur()->setRoles(['ROLE_USER']); // Reset roles
            
            $notifBanned = new \App\Entity\Notification();
            $notifBanned->setDestinataire($report->getUtilisateur());
            $notifBanned->setType('security_alert');
            $notifBanned->setTitle('Compte suspendu');
            $notifBanned->setMessage('Votre compte a été suspendu suite à un signalement non conforme.');
            $em->persist($notifBanned);
        } elseif ($sanction && $report->getUtilisateur()) {
            // Autres sanctions (avertissement, suspension)
            $notifUser = new \App\Entity\Notification();
            $notifUser->setDestinataire($report->getUtilisateur());
            $notifUser->setType('report_warning');
            $notifUser->setTitle('Avertissement administratif');
            $notifUser->setMessage('Vous avez reçu un(e) ' . $sanction . ' suite à un signalement : ' . $noteAdmin);
            $em->persist($notifUser);
        }

        $em->flush();

        $this->addFlash('success', 'Signalement résolu et notifications envoyées');
        return $this->redirectToRoute('admin_reports_show', ['id' => $report->getId()]);
    }

    #[Route('/{id}/dismiss', name: 'dismiss', methods: ['POST'])]
    public function dismiss(Report $report, EntityManagerInterface $em): Response
    {
        $report->setStatut(Report::STATUS_DISMISSED);
        $report->setResolvedAt(new \DateTimeImmutable());

        $notifReporter = new \App\Entity\Notification();
        $notifReporter->setDestinataire($report->getSignataire());
        $notifReporter->setType('report_dismissed');
        $notifReporter->setTitle('Signalement classé');
        $notifReporter->setMessage('Votre signalement #' . $report->getId() . ' a été examiné et classé sans suite.');
        $em->persist($notifReporter);

        $em->flush();

        $this->addFlash('success', 'Signalement rejeté');
        return $this->redirectToRoute('admin_reports_show', ['id' => $report->getId()]);
    }

    #[Route('/comment/{id}/delete', name: 'comment_delete', methods: ['POST'])]
    public function deleteComment(PropertyComment $comment, EntityManagerInterface $em): Response
    {
        $propertyId = $comment->getProperty()->getId();
        $authorName = $comment->getAuthor()->getFullName();
        $em->remove($comment);
        $em->flush();

        $this->addFlash('success', sprintf('Commentaire de %s supprimé.', $authorName));
        return $this->redirectToRoute('admin_properties_show', ['id' => $propertyId]);
    }

    #[Route('/property/{id}/reset-interactions', name: 'reset_interactions', methods: ['POST'])]
    public function resetInteractions(int $id, EntityManagerInterface $em, PropertyInteractionRepository $interactionRepo): Response
    {
        $interactions = $interactionRepo->findBy(['property' => $id]);
        foreach ($interactions as $interaction) {
            $em->remove($interaction);
        }
        $em->flush();

        $this->addFlash('success', 'Likes et dislikes réinitialisés pour ce bien.');
        return $this->redirectToRoute('admin_properties_show', ['id' => $id]);
    }
}
