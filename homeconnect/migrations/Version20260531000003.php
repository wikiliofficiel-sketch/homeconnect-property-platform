<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260531000003 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Reset verificationStatus pour les comptes non réellement certifiés';
    }

    public function up(Schema $schema): void
    {
        // Propriétaires sans KYC validé → remettre en_attente
        $this->addSql("
            UPDATE user
            SET verification_status = 'en_attente',
                kyc_status = 'pending'
            WHERE roles LIKE '%ROLE_PROPRIETAIRE%'
              AND kyc_status != 'approved'
              AND (verification_status = 'certifie' OR verification_status IS NULL)
        ");

        // Locataires → remettre à null (pas de KYC requis)
        $this->addSql("
            UPDATE user
            SET verification_status = NULL
            WHERE roles LIKE '%ROLE_LOCATAIRE%'
              AND roles NOT LIKE '%ROLE_ADMIN%'
              AND roles NOT LIKE '%ROLE_PROPRIETAIRE%'
        ");
    }

    public function down(Schema $schema): void
    {
        $this->addSql("UPDATE user SET verification_status = 'certifie' WHERE roles LIKE '%ROLE_PROPRIETAIRE%'");
    }
}
