<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20260504234941 extends AbstractMigration
{
    public function getDescription(): string
    {
        return '';
    }

    public function up(Schema $schema): void
    {
        // this up() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE application CHANGE responded_at responded_at DATETIME DEFAULT NULL');
        $this->addSql('ALTER TABLE community_report CHANGE reviewed_at reviewed_at DATETIME DEFAULT NULL');
        $this->addSql('ALTER TABLE message ADD type VARCHAR(20) NOT NULL, ADD attachment_url VARCHAR(255) DEFAULT NULL');
        $this->addSql('ALTER TABLE notification CHANGE lien lien VARCHAR(255) DEFAULT NULL, CHANGE read_at read_at DATETIME DEFAULT NULL, CHANGE related_entity_type related_entity_type VARCHAR(50) DEFAULT NULL');
        $this->addSql('ALTER TABLE partner CHANGE website website VARCHAR(255) DEFAULT NULL, CHANGE telephone telephone VARCHAR(20) DEFAULT NULL, CHANGE email email VARCHAR(255) DEFAULT NULL, CHANGE updated_at updated_at DATETIME DEFAULT NULL');
        $this->addSql('ALTER TABLE post CHANGE category category VARCHAR(50) DEFAULT NULL, CHANGE updated_at updated_at DATETIME DEFAULT NULL');
        $this->addSql('ALTER TABLE post_comment CHANGE updated_at updated_at DATETIME DEFAULT NULL');
        $this->addSql('ALTER TABLE property CHANGE country country VARCHAR(50) DEFAULT NULL, CHANGE deposit deposit NUMERIC(10, 2) DEFAULT NULL, CHANGE updated_at updated_at DATETIME DEFAULT NULL, CHANGE type type VARCHAR(50) DEFAULT NULL, CHANGE images images JSON DEFAULT NULL');
        $this->addSql('ALTER TABLE rental CHANGE total_price total_price NUMERIC(10, 2) DEFAULT NULL, CHANGE updated_at updated_at DATETIME DEFAULT NULL');
        $this->addSql('ALTER TABLE report CHANGE sanction sanction VARCHAR(255) DEFAULT NULL, CHANGE resolved_at resolved_at DATETIME DEFAULT NULL');
        $this->addSql('ALTER TABLE subscription CHANGE date_debut date_debut DATETIME DEFAULT NULL, CHANGE date_expiration date_expiration DATETIME DEFAULT NULL, CHANGE updated_at updated_at DATETIME DEFAULT NULL');
        $this->addSql('ALTER TABLE user CHANGE roles roles JSON NOT NULL, CHANGE telephone telephone VARCHAR(20) DEFAULT NULL, CHANGE ville ville VARCHAR(100) DEFAULT NULL, CHANGE updated_at updated_at DATETIME DEFAULT NULL, CHANGE kyc_status kyc_status VARCHAR(50) DEFAULT NULL, CHANGE kyc_submitted_at kyc_submitted_at DATETIME DEFAULT NULL, CHANGE kyc_approved_at kyc_approved_at DATETIME DEFAULT NULL, CHANGE num_siret num_siret VARCHAR(255) DEFAULT NULL');
        $this->addSql('ALTER TABLE messenger_messages CHANGE delivered_at delivered_at DATETIME DEFAULT NULL');
    }

    public function down(Schema $schema): void
    {
        // this down() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE `application` CHANGE responded_at responded_at DATETIME DEFAULT \'NULL\'');
        $this->addSql('ALTER TABLE community_report CHANGE reviewed_at reviewed_at DATETIME DEFAULT \'NULL\'');
        $this->addSql('ALTER TABLE message DROP type, DROP attachment_url');
        $this->addSql('ALTER TABLE messenger_messages CHANGE delivered_at delivered_at DATETIME DEFAULT \'NULL\'');
        $this->addSql('ALTER TABLE notification CHANGE lien lien VARCHAR(255) DEFAULT \'NULL\', CHANGE read_at read_at DATETIME DEFAULT \'NULL\', CHANGE related_entity_type related_entity_type VARCHAR(50) DEFAULT \'NULL\'');
        $this->addSql('ALTER TABLE partner CHANGE website website VARCHAR(255) DEFAULT \'NULL\', CHANGE telephone telephone VARCHAR(20) DEFAULT \'NULL\', CHANGE email email VARCHAR(255) DEFAULT \'NULL\', CHANGE updated_at updated_at DATETIME DEFAULT \'NULL\'');
        $this->addSql('ALTER TABLE post CHANGE category category VARCHAR(50) DEFAULT \'NULL\', CHANGE updated_at updated_at DATETIME DEFAULT \'NULL\'');
        $this->addSql('ALTER TABLE post_comment CHANGE updated_at updated_at DATETIME DEFAULT \'NULL\'');
        $this->addSql('ALTER TABLE property CHANGE country country VARCHAR(50) DEFAULT \'NULL\', CHANGE deposit deposit NUMERIC(10, 2) DEFAULT \'NULL\', CHANGE type type VARCHAR(50) DEFAULT \'NULL\', CHANGE images images LONGTEXT DEFAULT NULL COLLATE `utf8mb4_bin`, CHANGE updated_at updated_at DATETIME DEFAULT \'NULL\'');
        $this->addSql('ALTER TABLE rental CHANGE total_price total_price NUMERIC(10, 2) DEFAULT \'NULL\', CHANGE updated_at updated_at DATETIME DEFAULT \'NULL\'');
        $this->addSql('ALTER TABLE report CHANGE sanction sanction VARCHAR(255) DEFAULT \'NULL\', CHANGE resolved_at resolved_at DATETIME DEFAULT \'NULL\'');
        $this->addSql('ALTER TABLE subscription CHANGE date_debut date_debut DATETIME DEFAULT \'NULL\', CHANGE date_expiration date_expiration DATETIME DEFAULT \'NULL\', CHANGE updated_at updated_at DATETIME DEFAULT \'NULL\'');
        $this->addSql('ALTER TABLE `user` CHANGE roles roles LONGTEXT NOT NULL COLLATE `utf8mb4_bin`, CHANGE telephone telephone VARCHAR(20) DEFAULT \'NULL\', CHANGE ville ville VARCHAR(100) DEFAULT \'NULL\', CHANGE updated_at updated_at DATETIME DEFAULT \'NULL\', CHANGE kyc_status kyc_status VARCHAR(50) DEFAULT \'NULL\', CHANGE kyc_submitted_at kyc_submitted_at DATETIME DEFAULT \'NULL\', CHANGE kyc_approved_at kyc_approved_at DATETIME DEFAULT \'NULL\', CHANGE num_siret num_siret VARCHAR(255) DEFAULT \'NULL\'');
    }
}
