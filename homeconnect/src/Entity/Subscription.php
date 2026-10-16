<?php

namespace App\Entity;

use App\Repository\SubscriptionRepository;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Component\Serializer\Annotation\Groups;

#[ORM\Entity(repositoryClass: SubscriptionRepository::class)]
class Subscription
{
    const PLAN_FREE    = 'free';
    const PLAN_STARTER = 'starter';
    const PLAN_PRO     = 'pro';
    const PLAN_PREMIUM_PLUS = 'pro'; // rétro-compat

    const STATUS_ACTIVE    = 'active';
    const STATUS_EXPIRED   = 'expired';
    const STATUS_CANCELLED = 'cancelled';

    const PLAN_LIMITS = [
        'free'    => 3,
        'starter' => 10,
        'pro'     => null,
    ];

    const PLAN_PRICES = [
        'free'    => 0,
        'starter' => 5000,
        'pro'     => 10000,
    ];

    const PLAN_LABELS = [
        'free'    => 'Gratuit',
        'starter' => 'Starter',
        'pro'     => 'Pro',
    ];

    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    #[Groups(['property:read', 'subscription:read'])]
    private ?int $id = null;

    #[ORM\OneToOne(targetEntity: User::class)]
    #[ORM\JoinColumn(nullable: false)]
    #[Groups(['subscription:read'])]
    private ?User $proprietaire = null;

    #[ORM\Column(length: 50)]
    #[Groups(['property:read', 'subscription:read'])]
    private string $plan = self::PLAN_FREE;

    #[ORM\Column(nullable: true)]
    #[Groups(['subscription:read'])]
    private ?\DateTimeImmutable $dateDebut = null;

    #[ORM\Column(nullable: true)]
    #[Groups(['subscription:read'])]
    private ?\DateTimeImmutable $dateExpiration = null;

    #[ORM\Column(length: 50)]
    #[Groups(['subscription:read'])]
    private string $statut = self::STATUS_ACTIVE;

    #[ORM\Column]
    #[Groups(['subscription:read'])]
    private ?\DateTimeImmutable $createdAt = null;

    #[ORM\Column(nullable: true)]
    private ?\DateTimeImmutable $updatedAt = null;

    public function __construct()
    {
        $this->createdAt = new \DateTimeImmutable();
    }

    public function getId(): ?int { return $this->id; }
    public function getProprietaire(): ?User { return $this->proprietaire; }
    public function setProprietaire(?User $proprietaire): static { $this->proprietaire = $proprietaire; return $this; }
    public function getPlan(): string { return $this->plan; }
    public function setPlan(string $plan): static { $this->plan = $plan; return $this; }
    public function getDateDebut(): ?\DateTimeImmutable { return $this->dateDebut; }
    public function setDateDebut(?\DateTimeImmutable $dateDebut): static { $this->dateDebut = $dateDebut; return $this; }
    public function getDateExpiration(): ?\DateTimeImmutable { return $this->dateExpiration; }
    public function setDateExpiration(?\DateTimeImmutable $dateExpiration): static { $this->dateExpiration = $dateExpiration; return $this; }
    public function getStatut(): string { return $this->statut; }
    public function setStatut(string $statut): static { $this->statut = $statut; return $this; }
    public function getCreatedAt(): ?\DateTimeImmutable { return $this->createdAt; }
    public function setCreatedAt(\DateTimeImmutable $createdAt): static { $this->createdAt = $createdAt; return $this; }
    public function getUpdatedAt(): ?\DateTimeImmutable { return $this->updatedAt; }
    public function setUpdatedAt(?\DateTimeImmutable $updatedAt): static { $this->updatedAt = $updatedAt; return $this; }

    public function isExpired(): bool
    {
        return $this->dateExpiration !== null && $this->dateExpiration <= new \DateTimeImmutable();
    }

    public function isActive(): bool
    {
        return $this->statut === self::STATUS_ACTIVE && !$this->isExpired();
    }

    public function getMaxProperties(): ?int
    {
        return self::PLAN_LIMITS[$this->plan] ?? 3;
    }

    public function getPlanPrice(): int
    {
        return self::PLAN_PRICES[$this->plan] ?? 0;
    }

    public function getPlanLabel(): string
    {
        return self::PLAN_LABELS[$this->plan] ?? $this->plan;
    }

    public function isPremiumPlus(): bool { return $this->plan === self::PLAN_PRO; }
    public function isStarter(): bool     { return $this->plan === self::PLAN_STARTER; }
    public function isPro(): bool         { return $this->plan === self::PLAN_PRO; }
    public function isFree(): bool        { return $this->plan === self::PLAN_FREE; }

    public function canPublishMore(int $currentCount): bool
    {
        $max = $this->getMaxProperties();
        return $max === null || $currentCount < $max;
    }

    public function getNextUpgradePlan(): ?string
    {
        return match ($this->plan) {
            self::PLAN_FREE    => self::PLAN_STARTER,
            self::PLAN_STARTER => self::PLAN_PRO,
            default            => null,
        };
    }

    public function toApiArray(): array
    {
        $next = $this->getNextUpgradePlan();
        return [
            'id'             => $this->id,
            'plan'           => $this->plan,
            'planLabel'      => $this->getPlanLabel(),
            'planPrice'      => $this->getPlanPrice(),
            'maxProperties'  => $this->getMaxProperties(),
            'statut'         => $this->statut,
            'isActive'       => $this->isActive(),
            'isExpired'      => $this->isExpired(),
            'dateDebut'      => $this->dateDebut?->format('c'),
            'dateExpiration' => $this->dateExpiration?->format('c'),
            'createdAt'      => $this->createdAt?->format('c'),
            'nextPlan'       => $next,
            'nextPlanLabel'  => $next ? (self::PLAN_LABELS[$next] ?? null) : null,
            'nextPlanPrice'  => $next ? (self::PLAN_PRICES[$next] ?? null) : null,
        ];
    }
}
