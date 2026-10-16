<?php

namespace App\Entity;

use App\Repository\RentalRepository;
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Component\Validator\Constraints as Assert;
use Symfony\Component\Serializer\Annotation\Groups;

#[ORM\Entity(repositoryClass: RentalRepository::class)]
class Rental
{
    const STATUS_PENDING = 'pending';
    const STATUS_CONFIRMED = 'confirmed';
    const STATUS_ONGOING = 'ongoing';
    const STATUS_COMPLETED = 'completed';
    const STATUS_CANCELLED = 'cancelled';

    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    #[Groups(['property:read'])]
    private ?int $id = null;

    #[ORM\ManyToOne(targetEntity: Property::class, inversedBy: 'rentals')]
    #[ORM\JoinColumn(nullable: false, onDelete: 'CASCADE')]
    #[Groups(['property:read'])]
    private ?Property $property = null;

    #[ORM\ManyToOne(targetEntity: User::class, inversedBy: 'rentals')]
    #[ORM\JoinColumn(nullable: false, onDelete: 'CASCADE')]
    #[Groups(['property:read'])]
    private ?User $locataire = null;

    #[ORM\OneToMany(targetEntity: Review::class, mappedBy: 'rental', cascade: ['remove'])]
    private Collection $reviews;

    #[ORM\Column(type: 'datetime_immutable')]
    #[Assert\NotNull]
    #[Groups(['property:read'])]
    private ?\DateTimeImmutable $startDate = null;

    #[ORM\Column(type: 'datetime_immutable')]
    #[Assert\NotNull]
    #[Groups(['property:read'])]
    private ?\DateTimeImmutable $endDate = null;

    #[ORM\Column(type: 'decimal', precision: 10, scale: 2)]
    #[Assert\Positive]
    #[Groups(['property:read'])]
    private ?string $monthlyPrice = null;

    #[ORM\Column(type: 'decimal', precision: 10, scale: 2, nullable: true)]
    private ?string $totalPrice = null;

    #[ORM\Column(length: 50)]
    #[Assert\Choice(choices: ['pending', 'active', 'completed', 'cancelled'])]
    #[Groups(['property:read'])]
    private ?string $status = 'pending';

    #[ORM\Column(type: 'text', nullable: true)]
    private ?string $notes = null;

    #[ORM\Column(type: 'text', nullable: true)]
    private ?string $inventoryData = null; // JSON format for room ratings and photos

    #[ORM\Column]
    private ?\DateTimeImmutable $createdAt = null;

    #[ORM\Column(nullable: true)]
    private ?\DateTimeImmutable $updatedAt = null;

    #[ORM\OneToMany(mappedBy: 'rental', targetEntity: Payment::class, cascade: ['remove'])]
    private Collection $payments;

    public function __construct()
    {
        $this->createdAt = new \DateTimeImmutable();
        $this->reviews = new ArrayCollection();
        $this->payments = new ArrayCollection();
    }

    // ── Getters / Setters ──────────────────────

    public function getInventoryData(): ?string { return $this->inventoryData; }
    public function setInventoryData(?string $inventoryData): static { $this->inventoryData = $inventoryData; return $this; }

    public function getId(): ?int
    {
        return $this->id;
    }

    public function getProperty(): ?Property
    {
        return $this->property;
    }

    public function setProperty(?Property $property): static
    {
        $this->property = $property;
        return $this;
    }

    public function getLocataire(): ?User
    {
        return $this->locataire;
    }

    public function setLocataire(?User $locataire): static
    {
        $this->locataire = $locataire;
        return $this;
    }

    public function getStartDate(): ?\DateTimeImmutable
    {
        return $this->startDate;
    }

    public function setStartDate(\DateTimeImmutable $startDate): static
    {
        $this->startDate = $startDate;
        return $this;
    }

    public function getEndDate(): ?\DateTimeImmutable
    {
        return $this->endDate;
    }

    public function setEndDate(\DateTimeImmutable $endDate): static
    {
        $this->endDate = $endDate;
        return $this;
    }

    public function getMonthlyPrice(): ?string
    {
        return $this->monthlyPrice;
    }

    public function setMonthlyPrice(string $monthlyPrice): static
    {
        $this->monthlyPrice = $monthlyPrice;
        return $this;
    }

    public function getTotalPrice(): ?string
    {
        return $this->totalPrice;
    }

    public function setTotalPrice(?string $totalPrice): static
    {
        $this->totalPrice = $totalPrice;
        return $this;
    }

    public function getStatus(): ?string
    {
        return $this->status;
    }

    public function setStatus(string $status): static
    {
        $this->status = $status;
        return $this;
    }

    public function getNotes(): ?string
    {
        return $this->notes;
    }

    public function setNotes(?string $notes): static
    {
        $this->notes = $notes;
        return $this;
    }

    public function getCreatedAt(): ?\DateTimeImmutable
    {
        return $this->createdAt;
    }

    public function setCreatedAt(\DateTimeImmutable $createdAt): static
    {
        $this->createdAt = $createdAt;
        return $this;
    }

    public function getUpdatedAt(): ?\DateTimeImmutable
    {
        return $this->updatedAt;
    }

    public function setUpdatedAt(?\DateTimeImmutable $updatedAt): static
    {
        $this->updatedAt = $updatedAt;
        return $this;
    }

    // ── Helpers ───────────────────────────────

    public function isActive(): bool
    {
        $now = new \DateTimeImmutable();
        return $this->status === 'active' 
            && $this->startDate <= $now 
            && $this->endDate >= $now;
    }

    public function isPending(): bool
    {
        return $this->status === 'pending';
    }

    public function isCompleted(): bool
    {
        return $this->status === 'completed';
    }

    public function isCancelled(): bool
    {
        return $this->status === 'cancelled';
    }

    public function getDurationInMonths(): int
    {
        $interval = $this->startDate->diff($this->endDate);
        return (int) ceil($interval->days / 30);
    }

    public function calculateTotalPrice(): string
    {
        $months = $this->getDurationInMonths();
        $total = (float) $this->monthlyPrice * $months;
        return (string) $total;
    }
    /**
     * @return Collection<int, Review>
     */
    public function getReviews(): Collection
    {
        return $this->reviews;
    }

    public function addReview(Review $review): static
    {
        if (!$this->reviews->contains($review)) {
            $this->reviews->add($review);
            $review->setRental($this);
        }
        return $this;
    }

    public function removeReview(Review $review): static
    {
        if ($this->reviews->removeElement($review)) {
            // set the owning side to null (unless already changed)
            if ($review->getRental() === $this) {
                $review->setRental(null);
            }
        }
        return $this;
    }

    /**
     * @return Collection<int, Payment>
     */
    public function getPayments(): Collection
    {
        return $this->payments;
    }

    public function addPayment(Payment $payment): static
    {
        if (!$this->payments->contains($payment)) {
            $this->payments->add($payment);
            $payment->setRental($this);
        }
        return $this;
    }

    public function removePayment(Payment $payment): static
    {
        if ($this->payments->removeElement($payment)) {
            if ($payment->getRental() === $this) {
                $payment->setRental(null);
            }
        }
        return $this;
    }

    #[Groups(['property:read'])]
    public function isPaid(): bool
    {
        foreach ($this->payments as $payment) {
            if ($payment->getStatus() === 'success') {
                return true;
            }
        }
        return false;
    }

    /**
     * Calcule le montant de la pénalité si le paiement est en retard
     */
    #[Groups(['property:read'])]
    public function calculatePenalty(): float
    {
        if ($this->isPaid()) return 0.0;

        $now = new \DateTime();
        $dayOfMonth = (int) $now->format('d');
        $gracePeriod = $this->property->getGracePeriodDays() ?? 5;

        if ($dayOfMonth > $gracePeriod) {
            $rate = ($this->property->getLatePenaltyRate() ?? 10.0) / 100;
            return (float) $this->monthlyPrice * $rate;
        }

        return 0.0;
    }

    /**
     * Retourne le montant total à payer (Loyer + Pénalités éventuelles)
     */
    #[Groups(['property:read'])]
    public function getTotalAmountDue(): float
    {
        return (float) $this->monthlyPrice + $this->calculatePenalty();
    }
}
