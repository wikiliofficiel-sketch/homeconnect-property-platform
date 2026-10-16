<?php

namespace App\Controller\Api;

use App\Entity\Rental;
use App\Entity\Payment;
use App\Entity\User;
use App\Repository\PaymentRepository;
use App\Service\FedaPayService;
use App\Repository\RentalRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/api/payments')]
#[IsGranted('IS_AUTHENTICATED_FULLY')]
class ApiPaymentController extends AbstractController
{
    /** GET /api/payments — liste des paiements de l'utilisateur connecté */
    #[Route('', name: 'api_payments_list', methods: ['GET'])]
    public function list(PaymentRepository $paymentRepository): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        $payments = $paymentRepository->findBy(['user' => $user], ['createdAt' => 'DESC']);
        $data = [];
        foreach ($payments as $payment) {
            $rental = $payment->getRental();
            $data[] = [
                'id'           => $payment->getId(),
                'amount'       => (float) $payment->getAmount(),
                'status'       => $payment->getStatus(),
                'fedaPayRef'   => $payment->getFedaPayRef(),
                'createdAt'    => $payment->getCreatedAt()?->format('c'),
                'rentalId'     => $rental?->getId(),
                'propertyTitle'=> $rental?->getProperty()?->getTitle(),
            ];
        }
        return $this->json($data);
    }

    #[Route('/pending', name: 'api_payments_pending', methods: ['GET'])]
    public function getPending(RentalRepository $rentalRepository): JsonResponse
    {
        $user = $this->getUser();
        // On cherche les locations acceptées mais sans paiement 'success'
        $rentals = $rentalRepository->findBy(['locataire' => $user, 'status' => 'pending']);
        
        $data = [];
        foreach ($rentals as $rental) {
            // Vérifier si un paiement a déjà réussi pour cette location
            if (!$rental->isPaid()) {
                $data[] = [
                    'id' => $rental->getId(),
                    'property_title' => $rental->getProperty()->getTitle(),
                    'amount' => (float) $rental->getTotalAmountDue(),
                    'start_date' => $rental->getStartDate()->format('Y-m-d'),
                    'end_date' => $rental->getEndDate()->format('Y-m-d'),
                ];
            }
        }

        return $this->json($data);
    }

    // Route mobile : POST /api/payments/initiate avec { amount, description, email? }
    #[Route('/initiate', name: 'api_payments_initiate_direct', methods: ['POST'])]
    public function initiateDirect(Request $request, FedaPayService $fedaPayService, EntityManagerInterface $em): JsonResponse
    {
        $user = $this->getUser();
        if (!$user instanceof User) {
            return $this->json(['error' => 'Unauthorized'], 401);
        }
        $data = json_decode($request->getContent(), true);

        $amount = (float)($data['amount'] ?? 0);
        $description = $data['description'] ?? 'Paiement HomeConnect';
        $email = $data['email'] ?? $user->getEmail();
        $rentalId = $data['rental_id'] ?? $data['rentalId'] ?? null;

        if ($amount <= 0) {
            return $this->json(['error' => 'Amount must be positive'], 400);
        }

        $payment = new Payment();
        $payment->setUser($user)->setAmount($amount)->setStatus('pending');

        if ($rentalId) {
            $rental = $em->getRepository(Rental::class)->find($rentalId);
            if ($rental && $rental->getLocataire() === $user) {
                $payment->setRental($rental);
            }
        }

        $em->persist($payment);
        $em->flush();

        try {
            $paymentUrl = $fedaPayService->createPayment(
                $amount,
                $description,
                [
                    'firstname' => $user->getPrenom() ?? 'Client',
                    'lastname' => $user->getNom() ?? 'HomeConnect',
                    'email' => $email,
                    'phone' => $user->getTelephone() ?: '00000000',
                    'metadata' => ['payment_id' => $payment->getId()],
                ]
            );

            return $this->json([
                'payment_id' => $payment->getId(),
                'payment_url' => $paymentUrl,
            ]);
        } catch (\Exception $e) {
            return $this->json(['error' => $e->getMessage()], 500);
        }
    }

    // Route avec rental ID en path (usage web/admin)
    #[Route('/initiate/{id}', name: 'api_payments_initiate', methods: ['POST'])]
    public function initiate(Rental $rental, FedaPayService $fedaPayService, EntityManagerInterface $em): JsonResponse
    {
        $user = $this->getUser();
        if (!$user instanceof User || $rental->getLocataire() !== $user) {
            return $this->json(['error' => 'Unauthorized'], 403);
        }

        $payment = new Payment();
        $payment->setRental($rental)
            ->setUser($user)
            ->setAmount($rental->getTotalAmountDue())
            ->setStatus('pending');

        $em->persist($payment);
        $em->flush();

        $description = "Paiement Mobile - " . $rental->getProperty()->getTitle();

        try {
            $paymentUrl = $fedaPayService->createPayment(
                (float) $payment->getAmount(),
                $description,
                [
                    'firstname' => $user->getPrenom() ?? 'Civilité',
                    'lastname' => $user->getNom() ?? 'Locataire',
                    'email' => $user->getEmail(),
                    'phone' => $user->getTelephone() ?: '00000000',
                    'metadata' => [
                        'payment_id' => $payment->getId()
                    ]
                ]
            );

            return $this->json([
                'payment_id' => $payment->getId(),
                'payment_url' => $paymentUrl
            ]);
        } catch (\Exception $e) {
            return $this->json(['error' => $e->getMessage()], 500);
        }
    }

    #[Route('/status/{id}', name: 'api_payments_status', methods: ['GET'])]
    public function getStatus(Payment $payment): JsonResponse
    {
        if ($payment->getUser() !== $this->getUser()) {
            return $this->json(['error' => 'Unauthorized'], 403);
        }

        return $this->json([
            'id' => $payment->getId(),
            'status' => $payment->getStatus(),
            'rental_status' => $payment->getRental()->getStatus()
        ]);
    }
}
