<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260531000002 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Champs KYC spécifiques pour les propriétaires';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE user
            ADD kyc_identite_url VARCHAR(255) DEFAULT NULL,
            ADD kyc_identite_type VARCHAR(50) DEFAULT NULL,
            ADD kyc_domicile_url VARCHAR(255) DEFAULT NULL,
            ADD kyc_domicile_type VARCHAR(100) DEFAULT NULL,
            ADD kyc_propriete_url VARCHAR(255) DEFAULT NULL,
            ADD kyc_propriete_type VARCHAR(100) DEFAULT NULL,
            ADD kyc_rib_url VARCHAR(255) DEFAULT NULL,
            ADD kyc_assurance_url VARCHAR(255) DEFAULT NULL,
            ADD kyc_cas_particulier VARCHAR(50) DEFAULT NULL,
            ADD kyc_cas_particulier_url VARCHAR(255) DEFAULT NULL
        ');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE user
            DROP kyc_identite_url,
            DROP kyc_identite_type,
            DROP kyc_domicile_url,
            DROP kyc_domicile_type,
            DROP kyc_propriete_url,
            DROP kyc_propriete_type,
            DROP kyc_rib_url,
            DROP kyc_assurance_url,
            DROP kyc_cas_particulier,
            DROP kyc_cas_particulier_url
        ');
    }
}
