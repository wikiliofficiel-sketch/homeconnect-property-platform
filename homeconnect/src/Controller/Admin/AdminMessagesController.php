<?php

namespace App\Controller\Admin;

use App\Entity\User;
use App\Entity\Message;
use App\Repository\MessageRepository;
use App\Repository\UserRepository;
use App\Service\NotificationService;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/admin/messages', name: 'admin_messages_')]
#[IsGranted('ROLE_ADMIN')]
class AdminMessagesController extends AbstractController
{
    #[Route('/', name: 'index')]
    public function index(MessageRepository $messageRepo, Request $request): Response
    {
        /** @var User $admin */
        $admin = $this->getUser();
        $conversations = $messageRepo->findConversationsForUser($admin->getId());

        return $this->render('admin/messages/index.html.twig', [
            'conversations' => $conversations,
        ]);
    }

    #[Route('/new/{userId}', name: 'new_chat')]
    public function newChat(int $userId, UserRepository $userRepo, MessageRepository $messageRepo): Response
    {
        /** @var User $admin */
        $admin = $this->getUser();
        $user = $userRepo->find($userId);
        if (!$user) return $this->redirectToRoute('admin_messages_index');

        $conversations = $messageRepo->findConversationsForUser($admin->getId());

        return $this->render('admin/messages/index.html.twig', [
            'conversations'  => $conversations,
            'activeContact'  => $user,
            'messages'       => [],
        ]);
    }

    #[Route('/{receiverId}', name: 'chat')]
    public function chat(
        int $receiverId,
        MessageRepository $messageRepo,
        EntityManagerInterface $em,
        Request $request,
        NotificationService $notificationService
    ): Response {
        /** @var User $admin */
        $admin    = $this->getUser();
        $receiver = $em->getRepository(User::class)->find($receiverId);

        if (!$receiver) return $this->redirectToRoute('admin_messages_index');

        if ($request->isMethod('POST')) {
            $content = trim($request->request->get('content', ''));
            if ($content) {
                $msg = new Message();
                $msg->setSender($admin)->setReceiver($receiver)->setContent($content);
                $msg->setStatus(Message::STATUS_SENT);
                $em->persist($msg);
                $em->flush();

                // Notifier le destinataire
                $notificationService->notifyAndFlush(
                    $receiver,
                    'message_received',
                    sprintf('Nouveau message de l\'administration : "%s"', mb_substr($content, 0, 80)),
                    'Message de l\'admin',
                    $msg->getId(),
                    'message'
                );

                if ($request->isXmlHttpRequest() || $request->headers->get('X-Requested-With') === 'XMLHttpRequest') {
                    return new JsonResponse([
                        'success' => true,
                        'message' => [
                            'id'        => $msg->getId(),
                            'content'   => $msg->getContent(),
                            'createdAt' => $msg->getCreatedAt()->format('H:i'),
                            'isMe'      => true,
                        ],
                    ]);
                }

                return $this->redirectToRoute('admin_messages_chat', ['receiverId' => $receiverId]);
            }
        }

        $messages = $messageRepo->findConversation($admin->getId(), $receiverId);

        // Marquer les messages reçus comme lus
        foreach ($messages as $msg) {
            if ($msg->getReceiver()?->getId() === $admin->getId()
                && $msg->getStatus() !== Message::STATUS_READ) {
                $msg->setStatus(Message::STATUS_READ);
                $msg->setReadAt(new \DateTimeImmutable());
            }
        }
        $em->flush();

        $conversations = $messageRepo->findConversationsForUser($admin->getId());

        return $this->render('admin/messages/index.html.twig', [
            'conversations' => $conversations,
            'activeContact' => $receiver,
            'messages'      => $messages,
        ]);
    }

    #[Route('/upload/{receiverId}', name: 'upload', methods: ['POST'])]
    public function upload(int $receiverId, Request $request, EntityManagerInterface $em): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        $receiver = $em->getRepository(User::class)->find($receiverId);
        if (!$receiver) return new JsonResponse(['error' => 'User not found'], 404);

        $file = $request->files->get('file');
        $type = $request->request->get('type', 'image'); 
        $stickerUrl = $request->request->get('sticker_url');
        
        if (!$file && !$stickerUrl) return new JsonResponse(['error' => 'No file provided'], 400);

        $attachmentUrl = $stickerUrl;
        if ($file) {
            $uploadDir = $this->getParameter('kernel.project_dir') . '/public/uploads/messages';
            if (!is_dir($uploadDir)) mkdir($uploadDir, 0777, true);
            $filename = uniqid() . '.' . $file->guessExtension();
            $file->move($uploadDir, $filename);
            $attachmentUrl = '/uploads/messages/' . $filename;
        }

        $msg = new Message();
        $msg->setSender($user)->setReceiver($receiver)->setType($type);
        $msg->setAttachmentUrl($attachmentUrl);
        $msg->setContent($stickerUrl ? 'Sticker' : ($type === 'audio' ? 'Message vocal' : ($type === 'image' ? 'Image' : 'Fichier')));
        
        $em->persist($msg);
        $em->flush();

        return new JsonResponse(['success' => true, 'url' => $msg->getAttachmentUrl()]);
    }
}
