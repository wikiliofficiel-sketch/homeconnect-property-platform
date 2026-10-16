<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260603000001 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Ajouter kyc_avis_imposition_url au User (document KYC optionnel)';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE user ADD kyc_avis_imposition_url VARCHAR(255) DEFAULT NULL');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE user DROP kyc_avis_imposition_url');
    }
}
