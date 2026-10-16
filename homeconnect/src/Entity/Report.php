<?php

namespace App\Entity;

use App\Repository\ReportRepository;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Component\Serializer\Annotation\Groups;

#[ORM\Entity(repositoryClass: ReportRepository::class)]
class Report
{
    const PRIORITY_LOW = 'low';
    const PRIORITY_MEDIUM = 'medium';
    const PRIORITY_HIGH = 'high';
    const PRIORITY_CRITICAL = 'critical';

    const TYPE_PROPERTY = 'property';
    const TYPE_USER = 'user';
    const TYPE_REVIEW = 'review';

    const STATUS_OPEN = 'open';
    const STATUS_IN_REVIEW = 'in_review';
    const STATUS_RESOLVED = 'resolved';
    const STATUS_DISMISSED = 'dismissed';

    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    #[Groups(['property:read'])]
    private ?int $id = null;

    #[ORM\Column(length: 50)]
    #[Groups(['property:read'])]
    private string $type;

    #[ORM\ManyToOne(targetEntity: Property::class, inversedBy: 'reports')]
    #[Groups(['property:read'])]
    private ?Property $property = null;

    #[ORM\ManyToOne(targetEntity: User::class)]
    #[Groups(['property:read'])]
    private ?User $utilisateur = null;

    #[ORM\ManyToOne(targetEntity: Review::class)]
    private ?Review $review = null;

    #[ORM\ManyToOne(targetEntity: User::class)]
    #[ORM\JoinColumn(nullable: false)]
    #[Groups(['property:read'])]
    private ?User $signataire = null;

    #[ORM\Column(type: 'text')]
    #[Groups(['property:read'])]
    private ?string $motif = null;

    #[ORM\Column(length: 50)]
    #[Groups(['property:read'])]
    private string $priorite = self::PRIORITY_MEDIUM;

    #[ORM\Column(length: 50)]
    #[Groups(['property:read'])]
    private string $statut = self::STATUS_OPEN;

    #[ORM\Column(nullable: true)]
    private ?string $sanction = null;

    #[ORM\Column(type: 'text', nullable: true)]
    private ?string $noteAdmin = null;

    #[ORM\Column]
    #[Groups(['property:read'])]
    private ?\DateTimeImmutable $createdAt = null;

    #[ORM\Column(nullable: true)]
    private ?\DateTimeImmutable $resolvedAt = null;

    public function __construct()
    {
        $this->createdAt = new \DateTimeImmutable();
    }

    public function getId(): ?int { return $this->id; }
    public function getType(): string { return $this->type; }
    public function setType(string $type): static { $this->type = $type; return $this; }
    public function getProperty(): ?Property { return $this->property; }
    public function setProperty(?Property $property): static { $this->property = $property; return $this; }
    public function getUtilisateur(): ?User { return $this->utilisateur; }
    public function setUtilisateur(?User $utilisateur): static { $this->utilisateur = $utilisateur; return $this; }
    public function getReview(): ?Review { return $this->review; }
    public function setReview(?Review $review): static { $this->review = $review; return $this; }
    public function getSignataire(): ?User { return $this->signataire; }
    public function setSignataire(?User $signataire): static { $this->signataire = $signataire; return $this; }
    public function getMotif(): ?string { return $this->motif; }
    public function setMotif(string $motif): static { $this->motif = $motif; return $this; }
    public function getPriorite(): string { return $this->priorite; }
    public function setPriorite(string $priorite): static { $this->priorite = $priorite; return $this; }
    public function getStatut(): string { return $this->statut; }
    public function setStatut(string $statut): static { $this->statut = $statut; return $this; }
    public function getSanction(): ?string { return $this->sanction; }
    public function setSanction(?string $sanction): static { $this->sanction = $sanction; return $this; }
    public function getNoteAdmin(): ?string { return $this->noteAdmin; }
    public function setNoteAdmin(?string $noteAdmin): static { $this->noteAdmin = $noteAdmin; return $this; }
    public function getCreatedAt(): ?\DateTimeImmutable { return $this->createdAt; }
    public function setCreatedAt(\DateTimeImmutable $createdAt): static { $this->createdAt = $createdAt; return $this; }
    public function getResolvedAt(): ?\DateTimeImmutable { return $this->resolvedAt; }
    public function setResolvedAt(?\DateTimeImmutable $resolvedAt): static { $this->resolvedAt = $resolvedAt; return $this; }
}
