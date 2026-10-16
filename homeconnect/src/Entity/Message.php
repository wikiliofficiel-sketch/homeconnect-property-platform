<?php

namespace App\Entity;

use App\Repository\MessageRepository;
use Doctrine\DBAL\Types\Types;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Component\Serializer\Annotation\Groups;

#[ORM\Entity(repositoryClass: MessageRepository::class)]
class Message
{
    const TYPE_TEXT   = 'text';
    const TYPE_IMAGE  = 'image';
    const TYPE_VIDEO  = 'video';
    const TYPE_AUDIO  = 'audio';
    const TYPE_VOICE  = 'voice';
    const TYPE_FILE   = 'file';
    const TYPE_CALL   = 'call';
    const TYPE_SYSTEM = 'system';

    const STATUS_SENT      = 'sent';
    const STATUS_DELIVERED = 'delivered';
    const STATUS_READ      = 'read';

    const CALL_MISSED   = 'missed';
    const CALL_ANSWERED = 'answered';
    const CALL_REJECTED = 'rejected';

    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    #[Groups(['message:read'])]
    private ?int $id = null;

    #[ORM\ManyToOne(inversedBy: 'sentMessages')]
    #[ORM\JoinColumn(nullable: false)]
    #[Groups(['message:read'])]
    private ?User $sender = null;

    #[ORM\ManyToOne(inversedBy: 'receivedMessages')]
    #[ORM\JoinColumn(nullable: false)]
    #[Groups(['message:read'])]
    private ?User $receiver = null;

    #[ORM\Column(type: Types::TEXT, nullable: true)]
    #[Groups(['message:read'])]
    private ?string $content = null;

    #[ORM\Column]
    #[Groups(['message:read'])]
    private ?\DateTimeImmutable $createdAt = null;

    #[ORM\Column(nullable: true)]
    #[Groups(['message:read'])]
    private ?\DateTimeImmutable $updatedAt = null;

    #[ORM\Column(length: 20)]
    #[Groups(['message:read'])]
    private string $type = self::TYPE_TEXT;

    /** sent → delivered → read */
    #[ORM\Column(length: 20)]
    #[Groups(['message:read'])]
    private string $status = self::STATUS_SENT;

    #[ORM\Column(nullable: true)]
    #[Groups(['message:read'])]
    private ?\DateTimeImmutable $readAt = null;

    #[ORM\Column(nullable: true)]
    #[Groups(['message:read'])]
    private ?\DateTimeImmutable $deliveredAt = null;

    #[ORM\Column(length: 255, nullable: true)]
    #[Groups(['message:read'])]
    private ?string $attachmentUrl = null;

    #[ORM\Column(length: 255, nullable: true)]
    #[Groups(['message:read'])]
    private ?string $attachmentName = null;

    #[ORM\Column(nullable: true)]
    #[Groups(['message:read'])]
    private ?int $attachmentSize = null;

    /** Réponse à un message */
    #[ORM\ManyToOne(targetEntity: self::class)]
    #[ORM\JoinColumn(nullable: true, onDelete: 'SET NULL')]
    #[Groups(['message:read'])]
    private ?Message $replyTo = null;

    /** Transfert depuis un message */
    #[ORM\ManyToOne(targetEntity: self::class)]
    #[ORM\JoinColumn(nullable: true, onDelete: 'SET NULL')]
    #[Groups(['message:read'])]
    private ?Message $forwardedFrom = null;

    /** JSON : {"👍":[1,2],"❤️":[3]} */
    #[ORM\Column(type: Types::TEXT, nullable: true)]
    #[Groups(['message:read'])]
    private ?string $reactions = null;

    #[ORM\Column]
    private bool $deletedForSender = false;

    #[ORM\Column]
    private bool $deletedForReceiver = false;

    #[ORM\Column]
    #[Groups(['message:read'])]
    private bool $isEdited = false;

    /** Durée note vocale en secondes */
    #[ORM\Column(nullable: true)]
    #[Groups(['message:read'])]
    private ?int $voiceDuration = null;

    /** audio | video */
    #[ORM\Column(length: 10, nullable: true)]
    #[Groups(['message:read'])]
    private ?string $callType = null;

    /** Durée appel en secondes */
    #[ORM\Column(nullable: true)]
    #[Groups(['message:read'])]
    private ?int $callDuration = null;

    /** missed | answered | rejected */
    #[ORM\Column(length: 20, nullable: true)]
    #[Groups(['message:read'])]
    private ?string $callStatus = null;

    public function __construct()
    {
        $this->createdAt = new \DateTimeImmutable();
    }

    // ── Rétro-compat ────────────────────────────────────────────────────────
    public function isRead(): bool { return $this->status === self::STATUS_READ; }
    public function setIsRead(bool $v): static
    {
        if ($v) {
            $this->status = self::STATUS_READ;
            if (!$this->readAt) $this->readAt = new \DateTimeImmutable();
        }
        return $this;
    }

    // ── Getters / Setters ───────────────────────────────────────────────────

    public function getId(): ?int { return $this->id; }

    public function getSender(): ?User { return $this->sender; }
    public function setSender(?User $s): static { $this->sender = $s; return $this; }

    public function getReceiver(): ?User { return $this->receiver; }
    public function setReceiver(?User $r): static { $this->receiver = $r; return $this; }

    public function getContent(): ?string { return $this->content; }
    public function setContent(?string $c): static { $this->content = $c; return $this; }

    public function getCreatedAt(): ?\DateTimeImmutable { return $this->createdAt; }
    public function setCreatedAt(\DateTimeImmutable $d): static { $this->createdAt = $d; return $this; }

    public function getUpdatedAt(): ?\DateTimeImmutable { return $this->updatedAt; }
    public function setUpdatedAt(?\DateTimeImmutable $d): static { $this->updatedAt = $d; return $this; }

    public function getType(): string { return $this->type; }
    public function setType(string $t): static { $this->type = $t; return $this; }

    public function getStatus(): string { return $this->status; }
    public function setStatus(string $s): static { $this->status = $s; return $this; }

    public function getReadAt(): ?\DateTimeImmutable { return $this->readAt; }
    public function setReadAt(?\DateTimeImmutable $d): static { $this->readAt = $d; return $this; }

    public function getDeliveredAt(): ?\DateTimeImmutable { return $this->deliveredAt; }
    public function setDeliveredAt(?\DateTimeImmutable $d): static { $this->deliveredAt = $d; return $this; }

    public function getAttachmentUrl(): ?string { return $this->attachmentUrl; }
    public function setAttachmentUrl(?string $u): static { $this->attachmentUrl = $u; return $this; }

    public function getAttachmentName(): ?string { return $this->attachmentName; }
    public function setAttachmentName(?string $n): static { $this->attachmentName = $n; return $this; }

    public function getAttachmentSize(): ?int { return $this->attachmentSize; }
    public function setAttachmentSize(?int $s): static { $this->attachmentSize = $s; return $this; }

    public function getReplyTo(): ?Message { return $this->replyTo; }
    public function setReplyTo(?Message $m): static { $this->replyTo = $m; return $this; }

    public function getForwardedFrom(): ?Message { return $this->forwardedFrom; }
    public function setForwardedFrom(?Message $m): static { $this->forwardedFrom = $m; return $this; }

    public function getReactions(): ?string { return $this->reactions; }
    public function setReactions(?string $r): static { $this->reactions = $r; return $this; }
    public function getReactionsArray(): array
    {
        return $this->reactions ? (json_decode($this->reactions, true) ?? []) : [];
    }

    public function isDeletedForSender(): bool { return $this->deletedForSender; }
    public function setDeletedForSender(bool $v): static { $this->deletedForSender = $v; return $this; }

    public function isDeletedForReceiver(): bool { return $this->deletedForReceiver; }
    public function setDeletedForReceiver(bool $v): static { $this->deletedForReceiver = $v; return $this; }

    public function isEdited(): bool { return $this->isEdited; }
    public function setIsEdited(bool $v): static { $this->isEdited = $v; return $this; }

    public function getVoiceDuration(): ?int { return $this->voiceDuration; }
    public function setVoiceDuration(?int $v): static { $this->voiceDuration = $v; return $this; }

    public function getCallType(): ?string { return $this->callType; }
    public function setCallType(?string $v): static { $this->callType = $v; return $this; }

    public function getCallDuration(): ?int { return $this->callDuration; }
    public function setCallDuration(?int $v): static { $this->callDuration = $v; return $this; }

    public function getCallStatus(): ?string { return $this->callStatus; }
    public function setCallStatus(?string $v): static { $this->callStatus = $v; return $this; }

    // ── Sérialisation API ────────────────────────────────────────────────────

    public function toApiArray(int $currentUserId): array
    {
        $isMine = $this->sender?->getId() === $currentUserId;

        if ($isMine && $this->deletedForSender)   return ['id' => $this->id, 'deleted' => true];
        if (!$isMine && $this->deletedForReceiver) return ['id' => $this->id, 'deleted' => true];

        $replySnippet = null;
        if ($this->replyTo) {
            $replySnippet = [
                'id'         => $this->replyTo->getId(),
                'content'    => $this->replyTo->getContent(),
                'senderName' => $this->replyTo->getSender()?->getFullName(),
                'type'       => $this->replyTo->getType(),
                'attachmentUrl' => $this->replyTo->getAttachmentUrl(),
            ];
        }

        return [
            'id'             => $this->id,
            'senderId'       => $this->sender?->getId(),
            'senderName'     => $this->sender?->getFullName(),
            'senderEmail'    => $this->sender?->getEmail(),
            'receiverId'     => $this->receiver?->getId(),
            'receiverName'   => $this->receiver?->getFullName(),
            'receiverEmail'  => $this->receiver?->getEmail(),
            'content'        => $this->content,
            'text'           => $this->content,         // alias mobile
            'type'           => $this->type,
            'status'         => $this->status,
            'isRead'         => $this->status === self::STATUS_READ,
            'readAt'         => $this->readAt?->format('c'),
            'deliveredAt'    => $this->deliveredAt?->format('c'),
            'createdAt'      => $this->createdAt?->format('c'),
            'timestamp'      => $this->createdAt?->format('c'), // alias mobile
            'updatedAt'      => $this->updatedAt?->format('c'),
            'isEdited'       => $this->isEdited,
            'attachmentUrl'  => $this->attachmentUrl,
            'attachmentName' => $this->attachmentName,
            'attachmentSize' => $this->attachmentSize,
            'replyTo'        => $replySnippet,
            'forwardedFrom'  => $this->forwardedFrom?->getId(),
            'reactions'      => $this->getReactionsArray(),
            'isMine'         => $isMine,
            'voiceDuration'  => $this->voiceDuration,
            'callType'       => $this->callType,
            'callDuration'   => $this->callDuration,
            'callStatus'     => $this->callStatus,
        ];
    }
}
