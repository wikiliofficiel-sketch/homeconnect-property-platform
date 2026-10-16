<?php

namespace App\Entity;

use App\Repository\CommissionRepository;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity(repositoryClass: CommissionRepository::class)]
class Commission
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    private ?int $id = null;

    #[ORM\ManyToOne(targetEntity: Rental::class)]
    #[ORM\JoinColumn(nullable: false)]
    private ?Rental $rental = null;

    #[ORM\Column]
    private ?float $montantLocation = null;

    #[ORM\Column]
    private ?float $pourcentageCommission = null;

    #[ORM\Column]
    private ?float $montantCommission = null;

    #[ORM\Column]
    private ?\DateTimeImmutable $createdAt = null;

    public function __construct()
    {
        $this->createdAt = new \DateTimeImmutable();
    }

    public function getId(): ?int { return $this->id; }
    public function getRental(): ?Rental { return $this->rental; }
    public function setRental(?Rental $rental): static { $this->rental = $rental; return $this; }
    public function getMontantLocation(): ?float { return $this->montantLocation; }
    public function setMontantLocation(?float $montantLocation): static { $this->montantLocation = $montantLocation; return $this; }
    public function getPourcentageCommission(): ?float { return $this->pourcentageCommission; }
    public function setPourcentageCommission(?float $pourcentageCommission): static { $this->pourcentageCommission = $pourcentageCommission; return $this; }
    public function getMontantCommission(): ?float { return $this->montantCommission; }
    public function setMontantCommission(?float $montantCommission): static { $this->montantCommission = $montantCommission; return $this; }
    public function getCreatedAt(): ?\DateTimeImmutable { return $this->createdAt; }
    public function setCreatedAt(\DateTimeImmutable $createdAt): static { $this->createdAt = $createdAt; return $this; }
}
