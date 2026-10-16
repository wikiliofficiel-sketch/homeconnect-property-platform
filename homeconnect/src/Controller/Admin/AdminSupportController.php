<?php

namespace App\Controller\Admin;

use App\Entity\SupportTicket;
use App\Repository\SupportTicketRepository;
use App\Service\NotificationService;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/admin/support', name: 'admin_support_')]
#[IsGranted('ROLE_ADMIN')]
class AdminSupportController extends AbstractController
{
    #[Route('/', name: 'index')]
    public function index(SupportTicketRepository $repo, Request $request): Response
    {
        $status = $request->query->get('status', '');

        $qb = $repo->createQueryBuilder('t')
            ->leftJoin('t.user', 'u')
            ->addSelect('u')
            ->orderBy('t.createdAt', 'DESC');

        if ($status && in_array($status, ['ouvert', 'en_cours', 'ferme'])) {
            $qb->andWhere('t.status = :status')->setParameter('status', $status);
        }

        $tickets = $qb->getQuery()->getResult();

        $stats = [
            'ouvert'   => $repo->count(['status' => 'ouvert']),
            'en_cours' => $repo->count(['status' => 'en_cours']),
            'ferme'    => $repo->count(['status' => 'ferme']),
        ];

        return $this->render('admin/support/index.html.twig', [
            'tickets' => $tickets,
            'status'  => $status,
            'stats'   => $stats,
        ]);
    }

    #[Route('/{id}', name: 'show')]
    public function show(SupportTicket $ticket): Response
    {
        return $this->render('admin/support/show.html.twig', [
            'ticket' => $ticket,
        ]);
    }

    #[Route('/{id}/respond', name: 'respond', methods: ['POST'])]
    public function respond(
        SupportTicket $ticket,
        Request $request,
        EntityManagerInterface $em,
        NotificationService $notificationService
    ): Response {
        $response = trim($request->request->get('response', ''));

        if (!$response) {
            $this->addFlash('danger', 'La réponse ne peut pas être vide.');
            return $this->redirectToRoute('admin_support_show', ['id' => $ticket->getId()]);
        }

        $ticket->setAdminResponse($response);
        $ticket->setRespondedAt(new \DateTimeImmutable());
        $ticket->setStatus('ferme');
        $em->flush();

        $notificationService->notifyAndFlush(
            $ticket->getUser(),
            'support_response',
            sprintf('Votre ticket de support "%s" a reçu une réponse de l\'administration.', $ticket->getSubject()),
            'Réponse à votre demande',
            $ticket->getId(),
            'support'
        );

        $this->addFlash('success', 'Réponse envoyée et ticket fermé.');
        return $this->redirectToRoute('admin_support_show', ['id' => $ticket->getId()]);
    }

    #[Route('/{id}/in-progress', name: 'in_progress', methods: ['POST'])]
    public function inProgress(SupportTicket $ticket, EntityManagerInterface $em): Response
    {
        $ticket->setStatus('en_cours');
        $em->flush();

        $this->addFlash('success', 'Ticket marqué "En cours".');
        return $this->redirectToRoute('admin_support_show', ['id' => $ticket->getId()]);
    }
}
