<?php

namespace App\Service;

use App\Repository\RentalRepository;
use App\Entity\Notification;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Mime\Email;
use Twig\Environment;

class ReminderService
{
    private $rentalRepo;
    private $em;
    private $mailer;
    private $twig;

    public function __construct(
        RentalRepository $rentalRepo,
        EntityManagerInterface $em,
        MailerInterface $mailer,
        Environment $twig
    ) {
        $this->rentalRepo = $rentalRepo;
        $this->em = $em;
        $this->mailer = $mailer;
        $this->twig = $twig;
    }

    /**
     * Vérifie les loyers impayés et envoie les relances
     */
    public function sendReminders(): int
    {
        $rentals = $this->rentalRepo->findBy(['status' => 'active']);
        $count = 0;

        foreach ($rentals as $rental) {
            // Vérifier si un paiement réussi existe pour le mois en cours
            if (!$rental->isPaid()) {
                $this->sendEmailReminder($rental);
                $this->sendInAppNotification($rental);
                $this->sendSmsReminder($rental); // Simulation
                $count++;
            }
        }

        return $count;
    }

    private function sendEmailReminder($rental)
    {
        $email = (new Email())
            ->from('noreply@homeconnect.bj')
            ->to($rental->getLocataire()->getEmail())
            ->subject('Rappel : Paiement de votre loyer - ' . $rental->getProperty()->getTitle())
            ->html($this->twig->render('emails/rent_reminder.html.twig', [
                'rental' => $rental
            ]));

        try {
            $this->mailer->send($email);
        } catch (\Exception $e) {
            // Log error
        }
    }

    private function sendInAppNotification($rental)
    {
        $notif = new Notification();
        $notif->setDestinataire($rental->getLocataire())
            ->setType('rent_reminder')
            ->setMessage('⏳ Rappel : Votre loyer pour ' . $rental->getProperty()->getTitle() . ' est en attente de paiement.')
            ->setLien('/tenant/contracts');
        
        $this->em->persist($notif);
        $this->em->flush();
    }

    private function sendSmsReminder($rental)
    {
        $phone = $rental->getLocataire()->getTelephone();
        if ($phone) {
            // Ici, vous pourriez appeler une API SMS (ex: Twilio ou un fournisseur local)
            // dump("SMS envoyé à $phone : Rappel loyer HomeConnect.");
        }
    }
}
