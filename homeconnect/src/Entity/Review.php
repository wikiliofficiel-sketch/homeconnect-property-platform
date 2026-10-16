<?php

namespace App\Entity;

use App\Repository\ReviewRepository;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Component\Validator\Constraints as Assert;
use Symfony\Component\Serializer\Annotation\Groups;

#[ORM\Entity(repositoryClass: ReviewRepository::class)]
class Review
{
    const TYPE_PROPRIETAIRE = 'proprietaire';
    const TYPE_LOCATAIRE = 'locataire';

    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    #[Groups(['property:read'])]
    private ?int $id = null;

    #[ORM\ManyToOne(targetEntity: Rental::class, inversedBy: 'reviews')]
    #[ORM\JoinColumn(nullable: false, onDelete: 'CASCADE')]
    #[Groups(['property:read'])]
    private ?Rental $rental = null;

    #[ORM\ManyToOne(targetEntity: User::class)]
    #[ORM\JoinColumn(nullable: false, onDelete: 'CASCADE')]
    #[Groups(['property:read'])]
    private ?User $author = null;

    #[ORM\ManyToOne(targetEntity: User::class)]
    #[ORM\JoinColumn(nullable: false, onDelete: 'CASCADE')]
    #[Groups(['property:read'])]
    private ?User $targetUser = null;

    #[ORM\Column(length: 50)]
    #[Assert\Choice(choices: ['proprietaire', 'locataire'])]
    #[Groups(['property:read'])]
    private ?string $type = null; // proprietaire ou locataire

    #[ORM\Column]
    #[Assert\Range(min: 1, max: 5)]
    #[Groups(['property:read'])]
    private ?int $rating = null; // 1-5 stars

    #[ORM\Column(type: 'text')]
    #[Assert\NotBlank]
    #[Assert\Length(min: 10, max: 500)]
    #[Groups(['property:read'])]
    private ?string $comment = null;

    #[ORM\Column]
    #[Groups(['property:read'])]
    private ?\DateTimeImmutable $createdAt = null;

    public function __construct()
    {
        $this->createdAt = new \DateTimeImmutable();
    }

    public function getId(): ?int { return $this->id; }
    public function getRental(): ?Rental { return $this->rental; }
    public function setRental(?Rental $rental): static { $this->rental = $rental; return $this; }
    public function getAuthor(): ?User { return $this->author; }
    public function setAuthor(?User $author): static { $this->author = $author; return $this; }
    public function getTargetUser(): ?User { return $this->targetUser; }
    public function setTargetUser(?User $targetUser): static { $this->targetUser = $targetUser; return $this; }
    public function getType(): ?string { return $this->type; }
    public function setType(string $type): static { $this->type = $type; return $this; }
    public function getRating(): ?int { return $this->rating; }
    public function setRating(int $rating): static { $this->rating = $rating; return $this; }
    public function getComment(): ?string { return $this->comment; }
    public function setComment(string $comment): static { $this->comment = $comment; return $this; }
    public function getCreatedAt(): ?\DateTimeImmutable { return $this->createdAt; }
    public function setCreatedAt(\DateTimeImmutable $createdAt): static { $this->createdAt = $createdAt; return $this; }
}
