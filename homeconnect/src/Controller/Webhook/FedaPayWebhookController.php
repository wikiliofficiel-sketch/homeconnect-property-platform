<?php

namespace App\Controller\Webhook;

use App\Entity\Payment;
use App\Entity\Rental;
use App\Entity\Notification;
use App\Repository\PaymentRepository;
use Doctrine\ORM\EntityManagerInterface;
use FedaPay\FedaPay;
use FedaPay\Transaction;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

class FedaPayWebhookController extends AbstractController
{
    #[Route('/webhooks/fedapay', name: 'app_fedapay_webhook', methods: ['POST'])]
    public function handle(Request $request, PaymentRepository $paymentRepository, EntityManagerInterface $em): Response
    {
        $payload = json_decode($request->getContent(), true);
        
        if (!$payload || !isset($payload['entity'])) {
            return new Response('Invalid payload', 400);
        }

        $entity = $payload['entity'];
        $eventId = $payload['id'] ?? null;
        
        // On ne traite que les transactions approuvées
        if ($payload['event'] === 'transaction.approved') {
            $transactionId = $entity['id'];
            $status = $entity['status'];

            // Sécurité : Vérifier auprès de FedaPay
            FedaPay::setApiKey($_ENV['FEDAPAY_API_KEY']);
            FedaPay::setEnvironment($_ENV['FEDAPAY_ENVIRONMENT']);

            try {
                $transaction = Transaction::retrieve($transactionId);
                
                if ($transaction->status === 'approved') {
                    // Trouver le paiement associé dans notre base
                    // On utilise la référence stockée lors du callback ou on fait une recherche par montant/user si nécessaire
                    // L'idéal est d'avoir passé le 'custom_metadata' à FedaPay avec le payment_id
                    
                    $paymentId = $transaction->custom_metadata['payment_id'] ?? null;
                    $payment = null;

                    if ($paymentId) {
                        $payment = $paymentRepository->find($paymentId);
                    } else {
                        // fallback search by reference if implemented
                        $payment = $paymentRepository->findOneBy(['fedaPayRef' => $transactionId]);
                    }

                    if ($payment && $payment->getStatus() !== 'success') {
                        $payment->setStatus('success');
                        $payment->setFedaPayRef($transactionId);
                        
                        $rental = $payment->getRental();
                        if ($rental) {
                            $rental->setStatus('active');
                            $rental->getProperty()->setIsAvailable(false);

                            // Créer une notification pour le locataire
                            $notif = new Notification();
                            $notif->setUser($payment->getUser());
                            $notif->setTitle("Paiement Validé ✅");
                            $notif->setMessage("Votre paiement pour le bien '" . $rental->getProperty()->getTitle() . "' a été confirmé. Votre contrat est maintenant actif.");
                            $notif->setType("payment_success");
                            $notif->setLien("/tenant/contracts");
                            $em->persist($notif);
                        }

                        $em->flush();
                    }
                }
            } catch (\Exception $e) {
                return new Response('Error verifying transaction: ' . $e->getMessage(), 500);
            }
        }

        return new Response('Webhook received', 200);
    }
}
