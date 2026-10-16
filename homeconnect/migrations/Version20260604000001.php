<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260604000001 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Sanctions utilisateur (isSuspended, suspendedUntil, isBanned, warningsCount) + réponse admin sur support_ticket';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE `user` ADD is_suspended TINYINT(1) NOT NULL DEFAULT 0');
        $this->addSql('ALTER TABLE `user` ADD suspended_until DATETIME DEFAULT NULL COMMENT \'(DC2Type:datetime_immutable)\'');
        $this->addSql('ALTER TABLE `user` ADD is_banned TINYINT(1) NOT NULL DEFAULT 0');
        $this->addSql('ALTER TABLE `user` ADD warnings_count INT NOT NULL DEFAULT 0');
        $this->addSql('ALTER TABLE support_ticket ADD admin_response LONGTEXT DEFAULT NULL');
        $this->addSql('ALTER TABLE support_ticket ADD responded_at DATETIME DEFAULT NULL COMMENT \'(DC2Type:datetime_immutable)\'');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE `user` DROP is_suspended, DROP suspended_until, DROP is_banned, DROP warnings_count');
        $this->addSql('ALTER TABLE support_ticket DROP admin_response, DROP responded_at');
    }
}
