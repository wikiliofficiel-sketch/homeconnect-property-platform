<?php

namespace App\Command;

use App\Service\ReminderService;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Style\SymfonyStyle;

#[AsCommand(
    name: 'app:send-rent-reminders',
    description: 'Vérifie les loyers impayés et envoie des relances aux locataires.',
)]
class SendRentRemindersCommand extends Command
{
    private $reminderService;

    public function __construct(ReminderService $reminderService)
    {
        parent::__construct();
        $this->reminderService = $reminderService;
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $io = new SymfonyStyle($input, $output);
        
        $io->title('Lancement de la vérification des loyers impayés');
        
        $count = $this->reminderService->sendReminders();

        if ($count > 0) {
            $io->success("$count relance(s) ont été envoyées avec succès.");
        } else {
            $io->info("Aucun retard de paiement détecté. Félicitations à vos locataires !");
        }

        return Command::SUCCESS;
    }
}
