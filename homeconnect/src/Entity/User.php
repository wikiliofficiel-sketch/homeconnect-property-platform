<?php

namespace App\Entity;

use App\Repository\UserRepository;
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Validator\Constraints\UniqueEntity;
use Symfony\Component\Serializer\Annotation\Groups;
use Symfony\Component\Security\Core\User\PasswordAuthenticatedUserInterface;
use Symfony\Component\Security\Core\User\UserInterface;
use Symfony\Component\Validator\Constraints as Assert;

#[ORM\Entity(repositoryClass: UserRepository::class)]
#[ORM\Table(name: '`user`')]
#[UniqueEntity(fields: ['email'], message: 'Un compte existe déjà avec cet email.')]
class User implements UserInterface, PasswordAuthenticatedUserInterface
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    #[Groups(['property:read'])]
    private ?int $id = null;

    #[ORM\Column(length: 180, unique: true)]
    #[Groups(['property:read'])]
    #[Assert\NotBlank(message: 'L\'email est obligatoire.')]
    #[Assert\Email(message: 'Adresse email invalide.')]
    #[Assert\Length(max: 180, maxMessage: 'L\'email ne peut pas dépasser {{ limit }} caractères.')]
    private ?string $email = null;

    #[ORM\Column]
    private array $roles = [];

    #[ORM\Column]
    private ?string $password = null;

    #[ORM\Column(length: 100)]
    #[Groups(['property:read'])]
    #[Assert\NotBlank(message: 'Le prénom est obligatoire.')]
    #[Assert\Length(min: 2, max: 100, minMessage: 'Le prénom doit avoir au moins {{ limit }} caractères.')]
    #[Assert\Regex(pattern: '/^[\p{L}\s\-]+$/u', message: 'Le prénom ne doit contenir que des lettres.')]
    private ?string $prenom = null;

    #[ORM\Column(length: 100)]
    #[Groups(['property:read'])]
    #[Assert\NotBlank(message: 'Le nom est obligatoire.')]
    #[Assert\Length(min: 2, max: 100, minMessage: 'Le nom doit avoir au moins {{ limit }} caractères.')]
    #[Assert\Regex(pattern: '/^[\p{L}\s\-]+$/u', message: 'Le nom ne doit contenir que des lettres.')]
    private ?string $nom = null;

    #[ORM\Column(length: 20, nullable: true)]
    #[Groups(['property:read'])]
    #[Assert\Regex(pattern: '/^[\+0-9\s\-]{8,20}$/', message: 'Numéro de téléphone invalide.')]
    private ?string $telephone = null;

    #[ORM\Column(length: 100, nullable: true)]
    #[Groups(['property:read'])]
    #[Assert\Length(max: 100)]
    private ?string $ville = null;

    #[ORM\Column]
    private bool $isVerified = true;

    #[ORM\Column]
    private ?\DateTimeImmutable $createdAt = null;

    #[ORM\Column(nullable: true)]
    private ?\DateTimeImmutable $updatedAt = null;

    #[ORM\Column(type: 'string', length: 50, nullable: true)]
    private ?string $subscriptionType = 'gratuit';

    #[ORM\Column(type: 'datetime_immutable', nullable: true)]
    private ?\DateTimeImmutable $subscriptionExpiry = null;

    #[ORM\Column(type: 'float', nullable: true)]
    private ?float $rating = 0.0;

    #[ORM\Column(type: 'integer', nullable: true)]
    private ?int $reviewCount = 0;

    #[ORM\Column(type: 'string', length: 50, nullable: true)]
    private ?string $verificationStatus = null; // null = locataire standard ; 'en_attente' = KYC soumis ; 'certifie' = validé ; 'rejete' = refusé

    // ── KYC (Know Your Customer) ──────────────

    #[ORM\Column(length: 50, nullable: true)]
    private ?string $kyc_status = null; // pending, approved, rejected

    #[ORM\Column(type: 'text', nullable: true)]
    private ?string $kyc_documents = null; // JSON array of document paths

    #[ORM\Column(nullable: true)]
    private ?\DateTimeImmutable $kyc_submitted_at = null;

    #[ORM\Column(nullable: true)]
    private ?\DateTimeImmutable $kyc_approved_at = null;

    #[ORM\Column(type: 'text', nullable: true)]
    private ?string $kyc_rejection_reason = null;

    // ── Documents KYC propriétaire ─────────────────────────────────────────

    /** CNI ou Passeport */
    #[ORM\Column(length: 255, nullable: true)]
    private ?string $kycIdentiteUrl = null;

    #[ORM\Column(length: 50, nullable: true)]
    private ?string $kycIdentiteType = null; // cni | passeport

    /** Justificatif de domicile */
    #[ORM\Column(length: 255, nullable: true)]
    private ?string $kycDomicileUrl = null;

    #[ORM\Column(length: 100, nullable: true)]
    private ?string $kycDomicileType = null; // electricite | eau | telephone | taxe_fonciere | quittance

    /** Justificatif de propriété du bien */
    #[ORM\Column(length: 255, nullable: true)]
    private ?string $kycProprieteUrl = null;

    #[ORM\Column(length: 100, nullable: true)]
    private ?string $kycProprieteType = null; // titre_foncier | attestation_notaire | acte_vente | donation_succession

    /** Complémentaires (optionnels) */
    #[ORM\Column(length: 255, nullable: true)]
    private ?string $kycRibUrl = null;

    #[ORM\Column(length: 255, nullable: true)]
    private ?string $kycAssuranceUrl = null;

    /** Avis d'imposition (optionnel) */
    #[ORM\Column(length: 255, nullable: true)]
    private ?string $kycAvisImpositionUrl = null;

    /** Cas particuliers : copropriété / SCI */
    #[ORM\Column(length: 50, nullable: true)]
    private ?string $kycCasParticulier = null; // copropriete | sci

    #[ORM\Column(length: 255, nullable: true)]
    private ?string $kycCasParticulierUrl = null;

    #[ORM\Column(length: 255, nullable: true)]
    private ?string $num_siret = null;

    // ── Sanctions ────────────────────────────

    #[ORM\Column(type: 'boolean')]
    private bool $isSuspended = false;

    #[ORM\Column(nullable: true)]
    private ?\DateTimeImmutable $suspendedUntil = null;

    #[ORM\Column(type: 'boolean')]
    private bool $isBanned = false;

    #[ORM\Column(type: 'integer')]
    private int $warningsCount = 0;

    // ────────────────────────────────────────

    #[ORM\OneToMany(targetEntity: Property::class, mappedBy: 'proprietaire', cascade: ['remove'])]
    private Collection $properties;

    #[ORM\OneToMany(targetEntity: Rental::class, mappedBy: 'locataire', cascade: ['remove'])]
    private Collection $rentals;

    #[ORM\OneToMany(targetEntity: Application::class, mappedBy: 'locataire', cascade: ['remove'])]
    private Collection $applications;

    #[ORM\OneToMany(targetEntity: Notification::class, mappedBy: 'destinataire', cascade: ['remove'])]
    private Collection $notifications;

    #[ORM\OneToMany(targetEntity: Favorite::class, mappedBy: 'locataire', cascade: ['remove'])]
    private Collection $favorites;

    #[ORM\OneToMany(targetEntity: Post::class, mappedBy: 'author', cascade: ['remove'])]
    private Collection $posts;

    #[ORM\OneToMany(targetEntity: PostComment::class, mappedBy: 'author', cascade: ['remove'])]
    private Collection $comments;

    #[ORM\OneToMany(targetEntity: Message::class, mappedBy: 'sender', cascade: ['remove'])]
    private Collection $sentMessages;

    #[ORM\OneToMany(targetEntity: Message::class, mappedBy: 'receiver', cascade: ['remove'])]
    private Collection $receivedMessages;

    #[ORM\OneToMany(mappedBy: 'user', targetEntity: Payment::class, cascade: ['remove'])]
    private Collection $payments;

    public function __construct()
    {
        $this->roles = ['ROLE_USER'];
        $this->createdAt = new \DateTimeImmutable();
        $this->properties = new ArrayCollection();
        $this->rentals = new ArrayCollection();
        $this->applications = new ArrayCollection();
        $this->notifications = new ArrayCollection();
        $this->favorites = new ArrayCollection();
        $this->posts = new ArrayCollection();
        $this->comments = new ArrayCollection();
        $this->sentMessages = new ArrayCollection();
        $this->receivedMessages = new ArrayCollection();
        $this->payments = new ArrayCollection();
    }

    public function getId(): ?int
    {
        return $this->id;
    }

    public function getEmail(): ?string
    {
        return $this->email;
    }

    public function setEmail(string $email): static
    {
        $this->email = $email;
        return $this;
    }

    /**
     * @see UserInterface
     */
    public function getUserIdentifier(): string
    {
        return (string) $this->email;
    }

    /**
     * @see UserInterface
     */
    public function getRoles(): array
    {
        $roles = $this->roles;
        // guarantee every user at least has ROLE_USER
        $roles[] = 'ROLE_USER';

        return array_unique($roles);
    }

    public function setRoles(array $roles): static
    {
        $this->roles = $roles;
        return $this;
    }

    /**
     * @see PasswordAuthenticatedUserInterface
     */
    public function getPassword(): ?string
    {
        return $this->password;
    }

    public function setPassword(string $password): static
    {
        $this->password = $password;
        return $this;
    }

    /**
     * @see UserInterface
     */
    public function eraseCredentials(): void
    {
        // If you store any temporary, sensitive data on the user, clear it here
        // $this->plainPassword = null;
    }

    public function getPrenom(): ?string
    {
        return $this->prenom;
    }

    public function setPrenom(string $prenom): static
    {
        $this->prenom = $prenom;
        return $this;
    }

    public function getNom(): ?string
    {
        return $this->nom;
    }

    public function setNom(string $nom): static
    {
        $this->nom = $nom;
        return $this;
    }

    public function getFullName(): string
    {
        return $this->prenom . ' ' . $this->nom;
    }

    public function getTelephone(): ?string
    {
        return $this->telephone;
    }

    public function setTelephone(?string $telephone): static
    {
        $this->telephone = $telephone;
        return $this;
    }

    public function getVille(): ?string
    {
        return $this->ville;
    }

    public function setVille(?string $ville): static
    {
        $this->ville = $ville;
        return $this;
    }

    public function isVerified(): bool
    {
        return $this->isVerified;
    }

    public function setIsVerified(bool $isVerified): static
    {
        $this->isVerified = $isVerified;
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

    /**
     * @return Collection<int, Property>
     */
    public function getProperties(): Collection
    {
        return $this->properties;
    }

    /**
     * @return Collection<int, Notification>
     */
    public function getNotifications(): Collection
    {
        return $this->notifications;
    }

    /**
     * @return Collection<int, Rental>
     */
    public function getRentals(): Collection
    {
        return $this->rentals;
    }

    /**
     * @return Collection<int, Application>
     */
    public function getApplications(): Collection
    {
        return $this->applications;
    }

    /**
     * @return Collection<int, Favorite>
     */
    public function getFavorites(): Collection
    {
        return $this->favorites;
    }

    /**
     * @return Collection<int, Post>
     */
    public function getPosts(): Collection
    {
        return $this->posts;
    }

    /**
     * @return Collection<int, PostComment>
     */
    public function getComments(): Collection
    {
        return $this->comments;
    }

    /**
     * @return Collection<int, Message>
     */
    public function getSentMessages(): Collection
    {
        return $this->sentMessages;
    }

    /**
     * @return Collection<int, Message>
     */
    public function getReceivedMessages(): Collection
    {
        return $this->receivedMessages;
    }

    // ── Helpers ───────────────────────────────

    public function isProprietaire(): bool { return in_array('ROLE_PROPRIETAIRE', $this->roles); }
    public function isLocataire(): bool    { return in_array('ROLE_LOCATAIRE', $this->roles); }

    // ── KYC Getters / Setters ──────────────────

    public function getKycStatus(): ?string { return $this->kyc_status; }
    public function setKycStatus(?string $kyc_status): static { $this->kyc_status = $kyc_status; return $this; }

    public function getKycDocuments(): ?string { return $this->kyc_documents; }
    public function setKycDocuments(?string $kyc_documents): static { $this->kyc_documents = $kyc_documents; return $this; }

    public function getKycSubmittedAt(): ?\DateTimeImmutable { return $this->kyc_submitted_at; }
    public function setKycSubmittedAt(?\DateTimeImmutable $kyc_submitted_at): static { $this->kyc_submitted_at = $kyc_submitted_at; return $this; }

    public function getKycApprovedAt(): ?\DateTimeImmutable { return $this->kyc_approved_at; }
    public function setKycApprovedAt(?\DateTimeImmutable $kyc_approved_at): static { $this->kyc_approved_at = $kyc_approved_at; return $this; }

    public function getKycRejectionReason(): ?string { return $this->kyc_rejection_reason; }
    public function setKycRejectionReason(?string $kyc_rejection_reason): static { $this->kyc_rejection_reason = $kyc_rejection_reason; return $this; }

    public function getNumSiret(): ?string { return $this->num_siret; }
    public function setNumSiret(?string $num_siret): static { $this->num_siret = $num_siret; return $this; }

    public function isKycApproved(): bool { return $this->kyc_status === 'approved'; }
    public function isKycPending(): bool  { return $this->kyc_status === 'pending'; }
    public function isKycRejected(): bool { return $this->kyc_status === 'rejected'; }

    // ── Documents KYC spécifiques ───────────────────────────────────────────

    public function getKycIdentiteUrl(): ?string { return $this->kycIdentiteUrl; }
    public function setKycIdentiteUrl(?string $v): static { $this->kycIdentiteUrl = $v; return $this; }

    public function getKycIdentiteType(): ?string { return $this->kycIdentiteType; }
    public function setKycIdentiteType(?string $v): static { $this->kycIdentiteType = $v; return $this; }

    public function getKycDomicileUrl(): ?string { return $this->kycDomicileUrl; }
    public function setKycDomicileUrl(?string $v): static { $this->kycDomicileUrl = $v; return $this; }

    public function getKycDomicileType(): ?string { return $this->kycDomicileType; }
    public function setKycDomicileType(?string $v): static { $this->kycDomicileType = $v; return $this; }

    public function getKycProprieteUrl(): ?string { return $this->kycProprieteUrl; }
    public function setKycProprieteUrl(?string $v): static { $this->kycProprieteUrl = $v; return $this; }

    public function getKycProprieteType(): ?string { return $this->kycProprieteType; }
    public function setKycProprieteType(?string $v): static { $this->kycProprieteType = $v; return $this; }

    public function getKycRibUrl(): ?string { return $this->kycRibUrl; }
    public function setKycRibUrl(?string $v): static { $this->kycRibUrl = $v; return $this; }

    public function getKycAssuranceUrl(): ?string { return $this->kycAssuranceUrl; }
    public function setKycAssuranceUrl(?string $v): static { $this->kycAssuranceUrl = $v; return $this; }

    public function getKycAvisImpositionUrl(): ?string { return $this->kycAvisImpositionUrl; }
    public function setKycAvisImpositionUrl(?string $v): static { $this->kycAvisImpositionUrl = $v; return $this; }

    public function getKycCasParticulier(): ?string { return $this->kycCasParticulier; }
    public function setKycCasParticulier(?string $v): static { $this->kycCasParticulier = $v; return $this; }

    public function getKycCasParticulierUrl(): ?string { return $this->kycCasParticulierUrl; }
    public function setKycCasParticulierUrl(?string $v): static { $this->kycCasParticulierUrl = $v; return $this; }

    public function hasKycDocuments(): bool
    {
        return $this->kycIdentiteUrl !== null
            && $this->kycDomicileUrl !== null
            && $this->kycProprieteUrl !== null;
    }

    public function canPublishProperty(): bool
    {
        // Un propriétaire ne peut publier que si son KYC est approuvé.
        // Les admins sont exonérés (vérification faite dans le controller).
        return $this->isProprietaire() && $this->isKycApproved();
    }

    public function isKycCertifie(): bool
    {
        return $this->kyc_status === 'approved' || $this->verificationStatus === 'certifie';
    }

    public function getSubscriptionType(): ?string
    {
        return $this->subscriptionType;
    }

    public function setSubscriptionType(?string $subscriptionType): static
    {
        $this->subscriptionType = $subscriptionType;
        return $this;
    }

    public function getSubscriptionExpiry(): ?\DateTimeImmutable
    {
        return $this->subscriptionExpiry;
    }

    public function setSubscriptionExpiry(?\DateTimeImmutable $subscriptionExpiry): static
    {
        $this->subscriptionExpiry = $subscriptionExpiry;
        return $this;
    }

    public function getRating(): ?float
    {
        return $this->rating;
    }

    public function setRating(?float $rating): static
    {
        $this->rating = $rating;
        return $this;
    }

    public function getReviewCount(): ?int
    {
        return $this->reviewCount;
    }

    public function setReviewCount(?int $reviewCount): static
    {
        $this->reviewCount = $reviewCount;
        return $this;
    }

    public function getVerificationStatus(): ?string
    {
        return $this->verificationStatus;
    }

    public function setVerificationStatus(?string $verificationStatus): static
    {
        $this->verificationStatus = $verificationStatus;
        return $this;
    }

    public function isSuspended(): bool { return $this->isSuspended; }
    public function setIsSuspended(bool $isSuspended): static { $this->isSuspended = $isSuspended; return $this; }

    public function getSuspendedUntil(): ?\DateTimeImmutable { return $this->suspendedUntil; }
    public function setSuspendedUntil(?\DateTimeImmutable $suspendedUntil): static { $this->suspendedUntil = $suspendedUntil; return $this; }

    public function isBanned(): bool { return $this->isBanned; }
    public function setIsBanned(bool $isBanned): static { $this->isBanned = $isBanned; return $this; }

    public function getWarningsCount(): int { return $this->warningsCount; }
    public function setWarningsCount(int $warningsCount): static { $this->warningsCount = $warningsCount; return $this; }

    public function isActivelySuspended(): bool
    {
        if (!$this->isSuspended) return false;
        if ($this->suspendedUntil === null) return true;
        return $this->suspendedUntil > new \DateTimeImmutable();
    }
}
