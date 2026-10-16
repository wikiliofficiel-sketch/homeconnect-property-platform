<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20260429000000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Add tenant space entities: Favorite, Post, PostComment, CommunityReport';
    }

    public function up(Schema $schema): void
    {
        // Add favorite property to user
        $this->addSql('CREATE TABLE favorite (id INT AUTO_INCREMENT NOT NULL, locataire_id INT NOT NULL, property_id INT NOT NULL, added_at DATETIME NOT NULL COMMENT \'(DC2Type:datetime_immutable)\', UNIQUE INDEX UNIQ_FAVORITE_LOCATAIRE_PROPERTY (locataire_id, property_id), INDEX IDX_54FA509F58E0A285 (property_id), PRIMARY KEY(id)) DEFAULT CHARACTER SET utf8mb4 COLLATE `utf8mb4_unicode_ci` ENGINE = InnoDB');
        
        // Add post table
        $this->addSql('CREATE TABLE post (id INT AUTO_INCREMENT NOT NULL, author_id INT NOT NULL, title VARCHAR(255) NOT NULL, content LONGTEXT NOT NULL, category VARCHAR(50) NOT NULL, view_count INT NOT NULL DEFAULT 0, created_at DATETIME NOT NULL COMMENT \'(DC2Type:datetime_immutable)\', updated_at DATETIME NOT NULL COMMENT \'(DC2Type:datetime_immutable)\', INDEX IDX_5A8A6C8DF675F31B (author_id), PRIMARY KEY(id)) DEFAULT CHARACTER SET utf8mb4 COLLATE `utf8mb4_unicode_ci` ENGINE = InnoDB');
        
        // Add post_comment table
        $this->addSql('CREATE TABLE post_comment (id INT AUTO_INCREMENT NOT NULL, post_id INT NOT NULL, author_id INT NOT NULL, content LONGTEXT NOT NULL, created_at DATETIME NOT NULL COMMENT \'(DC2Type:datetime_immutable)\', updated_at DATETIME NOT NULL COMMENT \'(DC2Type:datetime_immutable)\', INDEX IDX_DF475BA74B89F25B (post_id), INDEX IDX_DF475BA7F675F31B (author_id), PRIMARY KEY(id)) DEFAULT CHARACTER SET utf8mb4 COLLATE `utf8mb4_unicode_ci` ENGINE = InnoDB');
        
        // Add community_report table
        $this->addSql('CREATE TABLE community_report (id INT AUTO_INCREMENT NOT NULL, reporter_id INT NOT NULL, post_id INT NULL, post_comment_id INT NULL, reason VARCHAR(50) NOT NULL, description LONGTEXT NOT NULL, priority VARCHAR(20) NOT NULL DEFAULT \'medium\', status VARCHAR(20) NOT NULL DEFAULT \'pending\', reviewed_at DATETIME DEFAULT NULL COMMENT \'(DC2Type:datetime_immutable)\', created_at DATETIME NOT NULL COMMENT \'(DC2Type:datetime_immutable)\', INDEX IDX_2DC2D0EA61220EA6 (reporter_id), INDEX IDX_2DC2D0EA4B89F25B (post_id), INDEX IDX_2DC2D0EADAA4DA74 (post_comment_id), PRIMARY KEY(id)) DEFAULT CHARACTER SET utf8mb4 COLLATE `utf8mb4_unicode_ci` ENGINE = InnoDB');
        
        // Add foreign keys
        $this->addSql('ALTER TABLE favorite ADD CONSTRAINT FK_54FA509F58E0A285 FOREIGN KEY (locataire_id) REFERENCES user (id) ON DELETE CASCADE');
        $this->addSql('ALTER TABLE favorite ADD CONSTRAINT FK_54FA509E549213D2 FOREIGN KEY (property_id) REFERENCES property (id) ON DELETE CASCADE');
        
        $this->addSql('ALTER TABLE post ADD CONSTRAINT FK_5A8A6C8DF675F31B FOREIGN KEY (author_id) REFERENCES user (id) ON DELETE CASCADE');
        
        $this->addSql('ALTER TABLE post_comment ADD CONSTRAINT FK_DF475BA74B89F25B FOREIGN KEY (post_id) REFERENCES post (id) ON DELETE CASCADE');
        $this->addSql('ALTER TABLE post_comment ADD CONSTRAINT FK_DF475BA7F675F31B FOREIGN KEY (author_id) REFERENCES user (id) ON DELETE CASCADE');
        
        $this->addSql('ALTER TABLE community_report ADD CONSTRAINT FK_2DC2D0EA61220EA6 FOREIGN KEY (reporter_id) REFERENCES user (id) ON DELETE CASCADE');
        $this->addSql('ALTER TABLE community_report ADD CONSTRAINT FK_2DC2D0EA4B89F25B FOREIGN KEY (post_id) REFERENCES post (id) ON DELETE SET NULL');
        $this->addSql('ALTER TABLE community_report ADD CONSTRAINT FK_2DC2D0EADAA4DA74 FOREIGN KEY (post_comment_id) REFERENCES post_comment (id) ON DELETE SET NULL');
        
        // Update review table if needed (add type field if missing)
        $this->addSql('ALTER TABLE review ADD type VARCHAR(50) DEFAULT \'proprietaire\' NOT NULL');
        
        // Add collections to user
        $this->addSql('ALTER TABLE user ADD CONSTRAINT review_author FOREIGN KEY (id) REFERENCES user (id) ON DELETE CASCADE');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('DROP TABLE community_report');
        $this->addSql('DROP TABLE post_comment');
        $this->addSql('DROP TABLE post');
        $this->addSql('DROP TABLE favorite');
        $this->addSql('ALTER TABLE review DROP COLUMN type');
    }
}
