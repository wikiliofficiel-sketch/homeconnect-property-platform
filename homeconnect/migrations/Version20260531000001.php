<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260531000001 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'WhatsApp messaging fields + Subscription plans (starter/pro)';
    }

    public function up(Schema $schema): void
    {
        // ── Message : nouveaux champs WhatsApp ───────────────────────────────
        $this->addSql('ALTER TABLE message
            CHANGE content content LONGTEXT DEFAULT NULL,
            CHANGE is_read is_read TINYINT(1) NOT NULL DEFAULT 0,
            ADD updated_at DATETIME DEFAULT NULL COMMENT \'(DC2Type:datetime_immutable)\',
            ADD status VARCHAR(20) NOT NULL DEFAULT \'sent\',
            ADD read_at DATETIME DEFAULT NULL COMMENT \'(DC2Type:datetime_immutable)\',
            ADD delivered_at DATETIME DEFAULT NULL COMMENT \'(DC2Type:datetime_immutable)\',
            ADD attachment_name VARCHAR(255) DEFAULT NULL,
            ADD attachment_size INT DEFAULT NULL,
            ADD reply_to_id INT DEFAULT NULL,
            ADD forwarded_from_id INT DEFAULT NULL,
            ADD reactions LONGTEXT DEFAULT NULL,
            ADD deleted_for_sender TINYINT(1) NOT NULL DEFAULT 0,
            ADD deleted_for_receiver TINYINT(1) NOT NULL DEFAULT 0,
            ADD is_edited TINYINT(1) NOT NULL DEFAULT 0,
            ADD voice_duration INT DEFAULT NULL,
            ADD call_type VARCHAR(10) DEFAULT NULL,
            ADD call_duration INT DEFAULT NULL,
            ADD call_status VARCHAR(20) DEFAULT NULL
        ');

        $this->addSql('ALTER TABLE message
            ADD CONSTRAINT FK_B6BD307FE8CB72C3 FOREIGN KEY (reply_to_id) REFERENCES message (id) ON DELETE SET NULL,
            ADD CONSTRAINT FK_B6BD307F9B4ADE10 FOREIGN KEY (forwarded_from_id) REFERENCES message (id) ON DELETE SET NULL
        ');

        $this->addSql('CREATE INDEX IDX_B6BD307FE8CB72C3 ON message (reply_to_id)');
        $this->addSql('CREATE INDEX IDX_B6BD307F9B4ADE10 ON message (forwarded_from_id)');

        // Migrer is_read → status
        $this->addSql("UPDATE message SET status = 'read' WHERE is_read = 1");

        // ── Subscription : garder la colonne plan, juste mettre à jour les valeurs ──
        // 'premium_plus' → 'pro' (rétro-compat)
        $this->addSql("UPDATE subscription SET plan = 'pro' WHERE plan = 'premium_plus'");
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE message
            DROP FOREIGN KEY FK_B6BD307FE8CB72C3,
            DROP FOREIGN KEY FK_B6BD307F9B4ADE10
        ');
        $this->addSql('DROP INDEX IDX_B6BD307FE8CB72C3 ON message');
        $this->addSql('DROP INDEX IDX_B6BD307F9B4ADE10 ON message');

        $this->addSql('ALTER TABLE message
            DROP updated_at, DROP status, DROP read_at, DROP delivered_at,
            DROP attachment_name, DROP attachment_size,
            DROP reply_to_id, DROP forwarded_from_id, DROP reactions,
            DROP deleted_for_sender, DROP deleted_for_receiver,
            DROP is_edited, DROP voice_duration,
            DROP call_type, DROP call_duration, DROP call_status,
            CHANGE content content LONGTEXT NOT NULL,
            CHANGE is_read is_read TINYINT(1) NOT NULL
        ');

        $this->addSql("UPDATE subscription SET plan = 'premium_plus' WHERE plan = 'pro'");
    }
}
