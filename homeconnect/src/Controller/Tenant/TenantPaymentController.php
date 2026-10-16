<?php

namespace App\Controller\Tenant;

use App\Entity\Rental;
use App\Entity\Payment;
use App\Service\FedaPayService;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/tenant/payments')]
#[IsGranted('ROLE_LOCATAIRE')]
class TenantPaymentController extends AbstractController
{
    #[Route('/{id}/initiate', name: 'app_tenant_payment_initiate')]
    public function initiate(Rental $rental, FedaPayService $fedaPayService, EntityManagerInterface $em): Response
    {
        // Vérifier que le locataire est bien celui de la location
        if ($rental->getLocataire() !== $this->getUser()) {
            throw $this->createAccessDeniedException();
        }

        // Créer un enregistrement de paiement "pending"
        $totalAmount = $rental->getTotalAmountDue();
        $penalty = $rental->calculatePenalty();

        $payment = new Payment();
        $payment->setRental($rental)
            ->setUser($this->getUser())
            ->setAmount($totalAmount)
            ->setStatus('pending');
        
        $em->persist($payment);
        $em->flush();

        $description = "Paiement Loyer - " . $rental->getProperty()->getTitle();
        if ($penalty > 0) {
            $description .= " (Incluant " . number_format($penalty, 0, ',', ' ') . " FCFA de pénalité de retard)";
        }

        // Générer le lien de paiement FedaPay
        try {
            $paymentUrl = $fedaPayService->createPayment(
                (float) $totalAmount,
                $description,
                [
                    'firstname' => $this->getUser()->getPrenom(),
                    'lastname' => $this->getUser()->getNom(),
                    'email' => $this->getUser()->getEmail(),
                    'phone' => $this->getUser()->getTelephone() ?: '00000000',
                    'callback_url' => $this->generateUrl('app_tenant_payment_callback', ['id' => $payment->getId()], \Symfony\Component\Routing\Generator\UrlGeneratorInterface::ABSOLUTE_URL),
                    'metadata' => [
                        'payment_id' => $payment->getId()
                    ]
                ]
            );

            return $this->redirect($paymentUrl);
        } catch (\Exception $e) {
            $this->addFlash('error', 'Erreur lors de l\'initialisation du paiement : ' . $e->getMessage());
            return $this->redirectToRoute('app_tenant_contracts');
        }
    }

    #[Route('/callback/{id}', name: 'app_tenant_payment_callback')]
    public function callback(Payment $payment, Request $request, EntityManagerInterface $em): Response
    {
        $status = $request->query->get('status');
        
        if ($status === 'success') {
            $payment->setStatus('success');
            $payment->setFedaPayRef($request->query->get('transaction_id')); // Store FedaPay Ref
            $this->addFlash('success', 'Votre paiement a été validé avec succès !');
        } else {
            $payment->setStatus('failed');
            $this->addFlash('error', 'Le paiement a échoué ou a été annulé.');
        }

        $em->flush();

        return $this->redirectToRoute('app_tenant_contracts');
    }

    #[Route('/{id}/receipt', name: 'app_tenant_payment_receipt')]
    public function receipt(Payment $payment, \App\Service\PdfService $pdfService): Response
    {
        // Sécurité : Vérifier que le paiement appartient bien à l'utilisateur
        if ($payment->getUser() !== $this->getUser()) {
            throw $this->createAccessDeniedException("Vous n'êtes pas autorisé à voir ce reçu.");
        }

        if ($payment->getStatus() !== 'success') {
            $this->addFlash('error', "La quittance n'est disponible que pour les paiements réussis.");
            return $this->redirectToRoute('app_tenant_contracts');
        }

        $pdfContent = $pdfService->generateBinaryPdf('pdf/quittance_loyer.html.twig', [
            'payment' => $payment
        ]);

        return new Response($pdfContent, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'inline; filename="quittance_loyer_' . $payment->getId() . '.pdf"',
        ]);
    }
}
