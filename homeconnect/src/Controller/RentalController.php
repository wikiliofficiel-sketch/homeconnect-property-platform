<?php

namespace App\Controller;

use App\Entity\Rental;
use App\Entity\Property;
use App\Form\RentalFormType;
use App\Repository\RentalRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/rental')]
class RentalController extends AbstractController
{
    #[Route('', name: 'app_rental_index')]
    public function index(RentalRepository $rentalRepository): Response
    {
        $rentals = $rentalRepository->findActive();

        return $this->render('rental/index.html.twig', [
            'rentals' => $rentals,
        ]);
    }

    #[Route('/{id}', name: 'app_rental_show')]
    public function show(Rental $rental): Response
    {
        return $this->render('rental/show.html.twig', [
            'rental' => $rental,
        ]);
    }

    #[Route('/property/{propertyId}/book', name: 'app_rental_create')]
    #[IsGranted('ROLE_LOCATAIRE')]
    public function create(Request $request, Property $propertyId, EntityManagerInterface $entityManager): Response
    {
        $rental = new Rental();
        $rental->setProperty($propertyId);

        $form = $this->createForm(RentalFormType::class, $rental);
        $form->handleRequest($request);

        if ($form->isSubmitted() && $form->isValid()) {
            $rental->setLocataire($this->getUser());
            $rental->setStatus('pending');
            $rental->setCreatedAt(new \DateTimeImmutable());
            $rental->setMonthlyPrice($propertyId->getPricePerMonth());
            $rental->setTotalPrice($rental->calculateTotalPrice());

            $entityManager->persist($rental);
            $entityManager->flush();

            $this->addFlash('success', 'Demande de location créée ! Le propriétaire examinera votre demande.');
            return $this->redirectToRoute('app_rental_show', ['id' => $rental->getId()]);
        }

        return $this->render('rental/create.html.twig', [
            'property' => $propertyId,
            'form' => $form,
        ]);
    }

    #[Route('/{id}/edit', name: 'app_rental_edit')]
    #[IsGranted('ROLE_LOCATAIRE')]
    public function edit(Request $request, Rental $rental, EntityManagerInterface $entityManager): Response
    {
        if ($rental->getLocataire() !== $this->getUser()) {
            throw $this->createAccessDeniedException();
        }

        $form = $this->createForm(RentalFormType::class, $rental);
        $form->handleRequest($request);

        if ($form->isSubmitted() && $form->isValid()) {
            $rental->setUpdatedAt(new \DateTimeImmutable());
            $entityManager->flush();

            $this->addFlash('success', 'Demande mise à jour avec succès !');
            return $this->redirectToRoute('app_rental_show', ['id' => $rental->getId()]);
        }

        return $this->render('rental/edit.html.twig', [
            'rental' => $rental,
            'form' => $form,
        ]);
    }

    #[Route('/{id}/cancel', name: 'app_rental_cancel', methods: ['POST'])]
    public function cancel(Request $request, Rental $rental, EntityManagerInterface $entityManager): Response
    {
        if ($rental->getLocataire() !== $this->getUser() && $rental->getProperty()->getProprietaire() !== $this->getUser()) {
            throw $this->createAccessDeniedException();
        }

        if ($this->isCsrfTokenValid('cancel' . $rental->getId(), $request->request->get('_token'))) {
            $rental->setStatus('cancelled');
            $rental->setUpdatedAt(new \DateTimeImmutable());
            $entityManager->flush();

            $this->addFlash('success', 'Location annulée.');
        }

        return $this->redirectToRoute('app_rental_show', ['id' => $rental->getId()]);
    }

    #[Route('/{id}/approve', name: 'app_rental_approve', methods: ['POST'])]
    #[IsGranted('ROLE_PROPRIETAIRE')]
    public function approve(Request $request, Rental $rental, EntityManagerInterface $entityManager): Response
    {
        if ($rental->getProperty()->getProprietaire() !== $this->getUser()) {
            throw $this->createAccessDeniedException();
        }

        if ($this->isCsrfTokenValid('approve' . $rental->getId(), $request->request->get('_token'))) {
            $rental->setStatus('active');
            $rental->setUpdatedAt(new \DateTimeImmutable());
            $rental->getProperty()->setIsAvailable(false);
            $entityManager->flush();

            $this->addFlash('success', 'Demande approuvée !');
        }

        return $this->redirectToRoute('app_rental_show', ['id' => $rental->getId()]);
    }

    #[Route('/{id}/reject', name: 'app_rental_reject', methods: ['POST'])]
    #[IsGranted('ROLE_PROPRIETAIRE')]
    public function reject(Request $request, Rental $rental, EntityManagerInterface $entityManager): Response
    {
        if ($rental->getProperty()->getProprietaire() !== $this->getUser()) {
            throw $this->createAccessDeniedException();
        }

        if ($this->isCsrfTokenValid('reject' . $rental->getId(), $request->request->get('_token'))) {
            $rental->setStatus('cancelled');
            $rental->setUpdatedAt(new \DateTimeImmutable());
            $entityManager->flush();

            $this->addFlash('info', 'Demande rejetée.');
        }

        return $this->redirectToRoute('app_rental_show', ['id' => $rental->getId()]);
    }

    #[Route('/my-rentals', name: 'app_my_rentals')]
    #[IsGranted('ROLE_LOCATAIRE')]
    public function myRentals(RentalRepository $rentalRepository): Response
    {
        $rentals = $rentalRepository->findByLocataire($this->getUser());

        return $this->render('rental/my_rentals.html.twig', [
            'rentals' => $rentals,
        ]);
    }

    #[Route('/my-bookings', name: 'app_my_bookings')]
    #[IsGranted('ROLE_PROPRIETAIRE')]
    public function myBookings(RentalRepository $rentalRepository): Response
    {
        $rentals = $rentalRepository->findByProprietaire($this->getUser());

        return $this->render('rental/my_bookings.html.twig', [
            'rentals' => $rentals,
        ]);
    }
    #[Route('/{id}/contract', name: 'app_owner_contract_generate')]
    public function downloadContract(Rental $rental, \Dompdf\Dompdf $dompdf): Response
    {
        // Sécurité : Seuls le locataire, le propriétaire ou l'admin peuvent télécharger
        if ($this->getUser() !== $rental->getLocataire() && 
            $this->getUser() !== $rental->getProperty()->getProprietaire() && 
            !$this->isGranted('ROLE_ADMIN')) {
            throw $this->createAccessDeniedException('Accès refusé au contrat.');
        }

        $html = $this->renderView('pdf/contract.html.twig', [
            'rental' => $rental,
        ]);

        $dompdf->loadHtml($html);
        $dompdf->setPaper('A4', 'portrait');
        $dompdf->render();

        $pdfOutput = $dompdf->output();

        return new Response($pdfOutput, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'attachment; filename="Contrat_Bail_HC_' . $rental->getId() . '.pdf"',
        ]);
    }
}
