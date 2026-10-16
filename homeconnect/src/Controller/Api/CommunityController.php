<?php

namespace App\Controller\Api;

use App\Entity\Post;
use App\Entity\PostComment;
use App\Entity\User;
use App\Repository\PostRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

#[Route('/api/community', name: 'api_community_')]
class CommunityController extends AbstractController
{
    #[Route('/posts', name: 'posts_list', methods: ['GET'])]
    public function listPosts(PostRepository $repository, Request $request): JsonResponse
    {
        $category = $request->query->get('category');
        $limit = (int)($request->query->get('limit', 20));
        $offset = (int)($request->query->get('offset', 0));

        $qb = $repository->createQueryBuilder('p')
            ->orderBy('p.createdAt', 'DESC')
            ->setMaxResults($limit)
            ->setFirstResult($offset);

        if ($category) {
            $qb->andWhere('p.category = :cat')->setParameter('cat', $category);
        }

        $posts = $qb->getQuery()->getResult();

        return new JsonResponse(array_map(fn(Post $p) => $this->serializePost($p), $posts));
    }

    #[Route('/posts', name: 'posts_create', methods: ['POST'])]
    public function createPost(Request $request, EntityManagerInterface $em): JsonResponse
    {
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $data = json_decode($request->getContent(), true);
        $title = $data['title'] ?? $data['titre'] ?? null;
        $content = $data['content'] ?? $data['contenu'] ?? null;

        if (!$title || !$content) {
            return new JsonResponse(['error' => 'title and content are required'], Response::HTTP_BAD_REQUEST);
        }

        $post = new Post();
        $post->setAuthor($user);
        $post->setTitle($title);
        $post->setContent($content);
        $post->setCategory($data['category'] ?? null);
        $post->setCreatedAt(new \DateTimeImmutable());

        $em->persist($post);
        $em->flush();

        return new JsonResponse($this->serializePost($post), Response::HTTP_CREATED);
    }

    #[Route('/posts/{id}', name: 'posts_show', methods: ['GET'], requirements: ['id' => '\d+'])]
    public function showPost(Post $post): JsonResponse
    {
        $post->setViewCount($post->getViewCount() + 1);
        return new JsonResponse($this->serializePost($post, true));
    }

    #[Route('/posts/{id}/comments', name: 'posts_comment', methods: ['POST'])]
    public function addComment(Post $post, Request $request, EntityManagerInterface $em): JsonResponse
    {
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $data = json_decode($request->getContent(), true);
        $content = $data['content'] ?? $data['contenu'] ?? null;

        if (!$content) {
            return new JsonResponse(['error' => 'content is required'], Response::HTTP_BAD_REQUEST);
        }

        $comment = new PostComment();
        $comment->setPost($post);
        $comment->setAuthor($user);
        $comment->setContent($content);
        $comment->setCreatedAt(new \DateTimeImmutable());

        $em->persist($comment);
        $em->flush();

        return new JsonResponse([
            'id' => $comment->getId(),
            'userId' => $user->getId(),
            'userName' => $user->getFullName(),
            'contenu' => $comment->getContent(),
            'content' => $comment->getContent(),
            'dateCreation' => $comment->getCreatedAt()->format('c'),
        ], Response::HTTP_CREATED);
    }

    #[Route('/posts/{id}', name: 'posts_delete', methods: ['DELETE'])]
    public function deletePost(Post $post, EntityManagerInterface $em): JsonResponse
    {
        $user = $this->getUser();
        if ($post->getAuthor() !== $user) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        $em->remove($post);
        $em->flush();

        return new JsonResponse(['message' => 'Post deleted']);
    }

    private function serializePost(Post $post, bool $withComments = false): array
    {
        $data = [
            'id' => $post->getId(),
            'userId' => $post->getAuthor()->getId(),
            'userName' => $post->getAuthor()->getFullName(),
            'userAvatar' => null,
            // Alias FR mobile
            'titre' => $post->getTitle(),
            'contenu' => $post->getContent(),
            // Alias EN standard
            'title' => $post->getTitle(),
            'content' => $post->getContent(),
            'category' => $post->getCategory(),
            'viewCount' => $post->getViewCount(),
            'commentsCount' => $post->getComments()->count(),
            'dateCreation' => $post->getCreatedAt()->format('c'),
            'createdAt' => $post->getCreatedAt()->format('c'),
        ];

        if ($withComments) {
            $data['comments'] = array_map(fn(PostComment $c) => [
                'id' => $c->getId(),
                'userId' => $c->getAuthor()->getId(),
                'userName' => $c->getAuthor()->getFullName(),
                'contenu' => $c->getContent(),
                'content' => $c->getContent(),
                'dateCreation' => $c->getCreatedAt()->format('c'),
            ], $post->getComments()->toArray());
        }

        return $data;
    }
}
