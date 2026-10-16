<?php

namespace App\Entity;

use App\Repository\PropertyRepository;
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;
use Doctrine\DBAL\Types\Types;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Component\Serializer\Annotation\Groups;
use Symfony\Component\Validator\Constraints as Assert;

#[ORM\Entity(repositoryClass: PropertyRepository::class)]
class Property
{
    const STATUS_DRAFT = 'draft';
    const STATUS_PENDING = 'pending';
    const STATUS_ACTIVE = 'active';
    const STATUS_SUSPENDED = 'suspended';
    const STATUS_DELETED = 'deleted';

    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    #[Groups(['property:read'])]
    private ?int $id = null;

    #[ORM\Column(length: 255)]
    #[Assert\NotBlank(message: 'Le titre est obligatoire.')]
    #[Assert\Length(min: 5, max: 255, minMessage: 'Le titre doit avoir au moins {{ limit }} caractères.')]
    #[Groups(['property:read'])]
    private ?string $title = null;

    #[ORM\Column(type: 'text')]
    #[Assert\NotBlank(message: 'La description est obligatoire.')]
    #[Assert\Length(min: 20, minMessage: 'La description doit avoir au moins {{ limit }} caractères.')]
    #[Groups(['property:read'])]
    private ?string $description = null;

    #[ORM\Column(length: 255)]
    #[Assert\NotBlank(message: 'L\'adresse est obligatoire.')]
    #[Assert\Length(min: 5, max: 255)]
    #[Groups(['property:read'])]
    private ?string $address = null;

    #[ORM\Column(length: 10, nullable: true)]
    #[Groups(['property:read'])]
    private ?string $zipCode = null;

    #[ORM\Column(length: 100, nullable: true)]
    #[Groups(['property:read'])]
    private ?string $city = null;

    #[ORM\Column(length: 50, nullable: true)]
    #[Groups(['property:read'])]
    private ?string $country = null;

    #[ORM\Column(type: 'decimal', precision: 10, scale: 2)]
    #[Assert\Positive]
    #[Groups(['property:read'])]
    private ?string $pricePerMonth = null;

    #[ORM\Column(type: 'decimal', precision: 10, scale: 2, nullable: true)]
    #[Groups(['property:read'])]
    private ?string $deposit = null;

    #[ORM\Column]
    #[Assert\Positive]
    #[Groups(['property:read'])]
    private ?int $rooms = null;

    #[ORM\Column]
    #[Assert\Positive]
    #[Groups(['property:read'])]
    private ?int $bedrooms = null;

    #[ORM\Column]
    #[Assert\Positive]
    #[Groups(['property:read'])]
    private ?float $surface = null;

    #[ORM\Column]
    #[Groups(['property:read'])]
    private bool $furnished = false;

    #[ORM\Column]
    #[Groups(['property:read'])]
    private bool $hasParking = false;

    #[ORM\Column]
    #[Groups(['property:read'])]
    private bool $isAvailable = true;

    #[ORM\ManyToOne(targetEntity: User::class, inversedBy: 'properties')]
    #[ORM\JoinColumn(nullable: false, onDelete: 'CASCADE')]
    #[Groups(['property:read'])]
    private ?User $proprietaire = null;

    #[ORM\Column(length: 50)]
    #[Groups(['property:read'])]
    private string $statut = self::STATUS_DRAFT;

    #[ORM\Column(length: 50, nullable: true)]
    #[Groups(['property:read'])]
    private ?string $type = null;

    #[ORM\Column(type: 'decimal', precision: 10, scale: 7, nullable: true)]
    #[Groups(['property:read'])]
    private ?string $latitude = null;

    #[ORM\Column(type: 'decimal', precision: 10, scale: 7, nullable: true)]
    #[Groups(['property:read'])]
    private ?string $longitude = null;

    #[ORM\Column(type: 'float', nullable: true)]
    private ?float $latePenaltyRate = 10.0; // Pourcentage (ex: 10%)

    #[ORM\Column(type: 'integer', nullable: true)]
    private ?int $gracePeriodDays = 5; // Jours après le début du mois (ex: après le 5)

    #[ORM\Column(type: Types::JSON, nullable: true)]
    #[Groups(['property:read'])]
    private ?array $images = [];

    #[ORM\Column(type: 'text', nullable: true)]
    #[Groups(['property:read'])]
    private ?string $motifSuspension = null;

    #[ORM\OneToMany(targetEntity: Rental::class, mappedBy: 'property', cascade: ['remove'])]
    private Collection $rentals;

    #[ORM\OneToMany(targetEntity: Application::class, mappedBy: 'property', cascade: ['remove'])]
    private Collection $applications;

    #[ORM\Column]
    #[Groups(['property:read'])]
    private ?\DateTimeImmutable $createdAt = null;

    #[ORM\Column(nullable: true)]
    #[Groups(['property:read'])]
    private ?\DateTimeImmutable $updatedAt = null;

    #[ORM\Column(type: 'string', length: 255, nullable: true)]
    #[Groups(['property:read'])]
    private ?string $videoUrl = null;

    #[ORM\Column(type: 'boolean')]
    #[Groups(['property:read'])]
    private bool $verified = false;

    #[ORM\Column(type: 'integer')]
    #[Groups(['property:read'])]
    private int $views = 0;

    #[ORM\OneToMany(targetEntity: Report::class, mappedBy: 'property', cascade: ['remove'])]
    private Collection $reports;

    #[ORM\OneToMany(targetEntity: PropertyComment::class, mappedBy: 'property', cascade: ['remove'])]
    private Collection $propertyComments;

    #[ORM\Column(type: 'integer')]
    #[Groups(['property:read'])]
    private int $likesCount = 0;

    #[ORM\Column(type: 'integer')]
    #[Groups(['property:read'])]
    private int $dislikesCount = 0;

    #[ORM\Column(type: 'integer')]
    #[Groups(['property:read'])]
    private int $commentsCount = 0;

    #[ORM\Column(type: 'boolean')]
    #[Groups(['property:read'])]
    private bool $isReserved = false;

    #[ORM\Column(type: 'boolean')]
    #[Groups(['property:read'])]
    private bool $isHighlighted = false;

    #[ORM\Column(type: 'datetime_immutable', nullable: true)]
    #[Groups(['property:read'])]
    private ?\DateTimeImmutable $highlightedUntil = null;

    #[ORM\Column(type: 'string', length: 50, nullable: true)]
    #[Groups(['property:read'])]
    private ?string $statutAnnonce = 'À louer';

    #[ORM\Column(type: 'decimal', precision: 12, scale: 2, nullable: true)]
    #[Groups(['property:read'])]
    private ?string $prixVente = null;

    #[ORM\Column(type: 'boolean')]
    #[Groups(['property:read'])]
    private bool $chargesComprises = false;

    #[ORM\Column(type: 'decimal', precision: 10, scale: 2, nullable: true)]
    #[Groups(['property:read'])]
    private ?string $montantCharges = null;

    #[ORM\Column(type: 'decimal', precision: 10, scale: 2, nullable: true)]
    #[Groups(['property:read'])]
    private ?string $fraisAgence = null;

    #[ORM\Column(type: 'integer', nullable: true)]
    #[Groups(['property:read'])]
    private ?int $nbSalons = 0;

    #[ORM\Column(type: 'integer', nullable: true)]
    #[Groups(['property:read'])]
    private ?int $nbSallesDeBain = 0;

    #[ORM\Column(type: 'integer', nullable: true)]
    #[Groups(['property:read'])]
    private ?int $nbToilettes = 0;

    #[ORM\Column(type: 'string', length: 100, nullable: true)]
    #[Groups(['property:read'])]
    private ?string $typeCuisine = 'Non équipée';

    #[ORM\Column(type: 'integer', nullable: true)]
    #[Groups(['property:read'])]
    private ?int $etage = null;

    #[ORM\Column(type: 'boolean')]
    #[Groups(['property:read'])]
    private bool $hasAscenseur = false;

    #[ORM\Column(type: 'integer', nullable: true)]
    #[Groups(['property:read'])]
    private ?int $parkingPlaces = 0;

    #[ORM\Column(type: 'boolean')]
    #[Groups(['property:read'])]
    private bool $hasJardin = false;

    #[ORM\Column(type: 'boolean')]
    #[Groups(['property:read'])]
    private bool $hasBalcon = false;

    #[ORM\Column(type: Types::JSON, nullable: true)]
    #[Groups(['property:read'])]
    private ?array $equipements = [];

    #[ORM\Column(type: 'string', length: 255, nullable: true)]
    #[Groups(['property:read'])]
    private ?string $planUrl = null;

    #[ORM\Column(type: 'boolean')]
    #[Groups(['property:read'])]
    private bool $animauxAcceptes = false;

    #[ORM\Column(type: 'boolean')]
    #[Groups(['property:read'])]
    private bool $fumeursAcceptes = false;

    #[ORM\Column(type: 'integer', nullable: true)]
    #[Groups(['property:read'])]
    private ?int $dureeMinLocation = null;

    #[ORM\Column(type: 'integer', nullable: true)]
    #[Groups(['property:read'])]
    private ?int $preavis = null;

    #[ORM\Column(type: 'string', length: 100, nullable: true)]
    #[Groups(['property:read'])]
    private ?string $disponibilite = null;

    #[ORM\Column(type: 'float', nullable: true)]
    #[Groups(['property:read'])]
    private ?float $rating = 0.0;

    public function __construct()
    {
        $this->images = [];
        $this->rentals = new ArrayCollection();
        $this->applications = new ArrayCollection();
        $this->reports = new ArrayCollection();
        $this->propertyComments = new ArrayCollection();
        $this->createdAt = new \DateTimeImmutable();
    }

    /**
     * @return Collection<int, PropertyComment>
     */
    public function getPropertyComments(): Collection
    {
        return $this->propertyComments;
    }

    public function addPropertyComment(PropertyComment $comment): static
    {
        if (!$this->propertyComments->contains($comment)) {
            $this->propertyComments->add($comment);
            $comment->setProperty($this);
        }
        return $this;
    }

    public function removePropertyComment(PropertyComment $comment): static
    {
        if ($this->propertyComments->removeElement($comment)) {
            if ($comment->getProperty() === $this) {
                $comment->setProperty(null);
            }
        }
        return $this;
    }

    // ── Getters / Setters ──────────────────────

    public function getId(): ?int
    {
        return $this->id;
    }

    public function getTitle(): ?string
    {
        return $this->title;
    }

    public function setTitle(string $title): static
    {
        $this->title = $title;
        return $this;
    }

    public function getDescription(): ?string
    {
        return $this->description;
    }

    public function setDescription(string $description): static
    {
        $this->description = $description;
        return $this;
    }

    public function getAddress(): ?string
    {
        return $this->address;
    }

    public function setAddress(string $address): static
    {
        $this->address = $address;
        return $this;
    }

    public function getZipCode(): ?string
    {
        return $this->zipCode;
    }

    public function setZipCode(string $zipCode): static
    {
        $this->zipCode = $zipCode;
        return $this;
    }

    public function getCity(): ?string
    {
        return $this->city;
    }

    public function setCity(string $city): static
    {
        $this->city = $city;
        return $this;
    }

    public function getCountry(): ?string
    {
        return $this->country;
    }

    public function setCountry(?string $country): static
    {
        $this->country = $country;
        return $this;
    }

    public function getPricePerMonth(): ?string
    {
        return $this->pricePerMonth;
    }

    public function setPricePerMonth(string $pricePerMonth): static
    {
        $this->pricePerMonth = $pricePerMonth;
        return $this;
    }

    public function getDeposit(): ?string
    {
        return $this->deposit;
    }

    public function setDeposit(?string $deposit): static
    {
        $this->deposit = $deposit;
        return $this;
    }

    public function getRooms(): ?int
    {
        return $this->rooms;
    }

    public function setRooms(int $rooms): static
    {
        $this->rooms = $rooms;
        return $this;
    }

    public function getBedrooms(): ?int
    {
        return $this->bedrooms;
    }

    public function setBedrooms(int $bedrooms): static
    {
        $this->bedrooms = $bedrooms;
        return $this;
    }

    public function getSurface(): ?float
    {
        return $this->surface;
    }

    public function setSurface(float $surface): static
    {
        $this->surface = $surface;
        return $this;
    }

    public function isFurnished(): bool
    {
        return $this->furnished;
    }

    public function setFurnished(bool $furnished): static
    {
        $this->furnished = $furnished;
        return $this;
    }

    public function hasParking(): bool
    {
        return $this->hasParking;
    }

    public function setHasParking(bool $hasParking): static
    {
        $this->hasParking = $hasParking;
        return $this;
    }

    public function isAvailable(): bool
    {
        return $this->isAvailable;
    }

    public function setIsAvailable(bool $isAvailable): static
    {
        $this->isAvailable = $isAvailable;
        return $this;
    }

    public function getProprietaire(): ?User
    {
        return $this->proprietaire;
    }

    public function setProprietaire(?User $proprietaire): static
    {
        $this->proprietaire = $proprietaire;
        return $this;
    }

    /**
     * @return Collection<int, Rental>
     */
    public function getRentals(): Collection
    {
        return $this->rentals;
    }

    public function addRental(Rental $rental): static
    {
        if (!$this->rentals->contains($rental)) {
            $this->rentals->add($rental);
            $rental->setProperty($this);
        }
        return $this;
    }

    public function removeRental(Rental $rental): static
    {
        if ($this->rentals->removeElement($rental)) {
            if ($rental->getProperty() === $this) {
                $rental->setProperty(null);
            }
        }
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
     * @return Collection<int, Application>
     */
    public function getApplications(): Collection
    {
        return $this->applications;
    }

    public function addApplication(Application $application): static
    {
        if (!$this->applications->contains($application)) {
            $this->applications->add($application);
            $application->setProperty($this);
        }
        return $this;
    }

    public function removeApplication(Application $application): static
    {
        if ($this->applications->removeElement($application)) {
            if ($application->getProperty() === $this) {
                $application->setProperty(null);
            }
        }
        return $this;
    }

    public function getStatut(): ?string
    {
        return $this->statut;
    }

    public function setStatut(string $statut): static
    {
        $this->statut = $statut;
        return $this;
    }

    public function getMotifSuspension(): ?string
    {
        return $this->motifSuspension;
    }

    public function setMotifSuspension(?string $motifSuspension): static
    {
        $this->motifSuspension = $motifSuspension;
        return $this;
    }

    public function getType(): ?string
    {
        return $this->type;
    }

    public function setType(?string $type): static
    {
        $this->type = $type;
        return $this;
    }

    public function getImages(): array
    {
        return $this->images ?? [];
    }

    public function setImages(?array $images): static
    {
        $this->images = $images ?: [];
        return $this;
    }

    // ── Helpers ───────────────────────────────

    public function getVideoUrl(): ?string
    {
        return $this->videoUrl;
    }

    public function setVideoUrl(?string $videoUrl): static
    {
        $this->videoUrl = $videoUrl;
        return $this;
    }

    public function isVerified(): bool
    {
        return $this->verified;
    }

    public function setVerified(bool $verified): static
    {
        $this->verified = $verified;
        return $this;
    }

    public function getViews(): int
    {
        return $this->views;
    }

    public function setViews(int $views): static
    {
        $this->views = $views;
        return $this;
    }

    /**
     * @return Collection<int, Report>
     */
    public function getReports(): Collection
    {
        return $this->reports;
    }

    public function addReport(Report $report): static
    {
        if (!$this->reports->contains($report)) {
            $this->reports->add($report);
            $report->setProperty($this);
        }
        return $this;
    }

    public function removeReport(Report $report): static
    {
        if ($this->reports->removeElement($report)) {
            // set the owning side to null (unless already changed)
            if ($report->getProperty() === $this) {
                $report->setProperty(null);
            }
        }
        return $this;
    }

    public function getLikesCount(): int
    {
        return $this->likesCount;
    }

    public function setLikesCount(int $likesCount): static
    {
        $this->likesCount = $likesCount;
        return $this;
    }

    public function getDislikesCount(): int
    {
        return $this->dislikesCount;
    }

    public function setDislikesCount(int $dislikesCount): static
    {
        $this->dislikesCount = $dislikesCount;
        return $this;
    }

    public function getCommentsCount(): int
    {
        return $this->commentsCount;
    }

    public function setCommentsCount(int $commentsCount): static
    {
        $this->commentsCount = $commentsCount;
        return $this;
    }

    public function isReserved(): bool
    {
        return $this->isReserved;
    }

    public function setIsReserved(bool $isReserved): static
    {
        $this->isReserved = $isReserved;
        return $this;
    }

    public function isHighlighted(): bool
    {
        return $this->isHighlighted;
    }

    public function setIsHighlighted(bool $isHighlighted): static
    {
        $this->isHighlighted = $isHighlighted;
        return $this;
    }

    public function getHighlightedUntil(): ?\DateTimeImmutable
    {
        return $this->highlightedUntil;
    }

    public function setHighlightedUntil(?\DateTimeImmutable $highlightedUntil): static
    {
        $this->highlightedUntil = $highlightedUntil;
        return $this;
    }

    public function getStatutAnnonce(): ?string
    {
        return $this->statutAnnonce;
    }

    public function setStatutAnnonce(?string $statutAnnonce): static
    {
        $this->statutAnnonce = $statutAnnonce;
        return $this;
    }

    public function getPrixVente(): ?string
    {
        return $this->prixVente;
    }

    public function setPrixVente(?string $prixVente): static
    {
        $this->prixVente = $prixVente;
        return $this;
    }

    public function isChargesComprises(): bool
    {
        return $this->chargesComprises;
    }

    public function setChargesComprises(bool $chargesComprises): static
    {
        $this->chargesComprises = $chargesComprises;
        return $this;
    }

    public function getMontantCharges(): ?string
    {
        return $this->montantCharges;
    }

    public function setMontantCharges(?string $montantCharges): static
    {
        $this->montantCharges = $montantCharges;
        return $this;
    }

    public function getFraisAgence(): ?string
    {
        return $this->fraisAgence;
    }

    public function setFraisAgence(?string $fraisAgence): static
    {
        $this->fraisAgence = $fraisAgence;
        return $this;
    }

    public function getNbSalons(): ?int
    {
        return $this->nbSalons;
    }

    public function setNbSalons(?int $nbSalons): static
    {
        $this->nbSalons = $nbSalons;
        return $this;
    }

    public function getNbSallesDeBain(): ?int
    {
        return $this->nbSallesDeBain;
    }

    public function setNbSallesDeBain(?int $nbSallesDeBain): static
    {
        $this->nbSallesDeBain = $nbSallesDeBain;
        return $this;
    }

    public function getNbToilettes(): ?int
    {
        return $this->nbToilettes;
    }

    public function setNbToilettes(?int $nbToilettes): static
    {
        $this->nbToilettes = $nbToilettes;
        return $this;
    }

    public function getTypeCuisine(): ?string
    {
        return $this->typeCuisine;
    }

    public function setTypeCuisine(?string $typeCuisine): static
    {
        $this->typeCuisine = $typeCuisine;
        return $this;
    }

    public function getEtage(): ?int
    {
        return $this->etage;
    }

    public function setEtage(?int $etage): static
    {
        $this->etage = $etage;
        return $this;
    }

    public function hasAscenseur(): bool
    {
        return $this->hasAscenseur;
    }

    public function setHasAscenseur(bool $hasAscenseur): static
    {
        $this->hasAscenseur = $hasAscenseur;
        return $this;
    }

    public function getParkingPlaces(): ?int
    {
        return $this->parkingPlaces;
    }

    public function setParkingPlaces(?int $parkingPlaces): static
    {
        $this->parkingPlaces = $parkingPlaces;
        return $this;
    }

    public function hasJardin(): bool
    {
        return $this->hasJardin;
    }

    public function setHasJardin(bool $hasJardin): static
    {
        $this->hasJardin = $hasJardin;
        return $this;
    }

    public function hasBalcon(): bool
    {
        return $this->hasBalcon;
    }

    public function setHasBalcon(bool $hasBalcon): static
    {
        $this->hasBalcon = $hasBalcon;
        return $this;
    }

    public function getEquipements(): ?array
    {
        return $this->equipements;
    }

    public function setEquipements(?array $equipements): static
    {
        $this->equipements = $equipements;
        return $this;
    }

    public function getPlanUrl(): ?string
    {
        return $this->planUrl;
    }

    public function setPlanUrl(?string $planUrl): static
    {
        $this->planUrl = $planUrl;
        return $this;
    }

    public function isAnimauxAcceptes(): bool
    {
        return $this->animauxAcceptes;
    }

    public function setAnimauxAcceptes(bool $animauxAcceptes): static
    {
        $this->animauxAcceptes = $animauxAcceptes;
        return $this;
    }

    public function isFumeursAcceptes(): bool
    {
        return $this->fumeursAcceptes;
    }

    public function setFumeursAcceptes(bool $fumeursAcceptes): static
    {
        $this->fumeursAcceptes = $fumeursAcceptes;
        return $this;
    }

    public function getDureeMinLocation(): ?int
    {
        return $this->dureeMinLocation;
    }

    public function setDureeMinLocation(?int $dureeMinLocation): static
    {
        $this->dureeMinLocation = $dureeMinLocation;
        return $this;
    }

    public function getPreavis(): ?int
    {
        return $this->preavis;
    }

    public function setPreavis(?int $preavis): static
    {
        $this->preavis = $preavis;
        return $this;
    }

    public function getDisponibilite(): ?string
    {
        return $this->disponibilite;
    }

    public function setDisponibilite(?string $disponibilite): static
    {
        $this->disponibilite = $disponibilite;
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

    public function getFullAddress(): string

    {
        return $this->address . ', ' . $this->zipCode . ' ' . $this->city;
    }

    public function hasActiveRental(): bool
    {
        foreach ($this->rentals as $rental) {
            if ($rental->isActive()) {
                return true;
            }
        }
        return false;
    }

    public function getLatePenaltyRate(): ?float { return $this->latePenaltyRate; }
    public function setLatePenaltyRate(?float $latePenaltyRate): static { $this->latePenaltyRate = $latePenaltyRate; return $this; }

    public function getGracePeriodDays(): ?int { return $this->gracePeriodDays; }
    public function setGracePeriodDays(?int $gracePeriodDays): static { $this->gracePeriodDays = $gracePeriodDays; return $this; }
}
