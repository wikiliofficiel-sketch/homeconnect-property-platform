<?php
require_once __DIR__ . '/vendor/autoload.php';
$kernel = new \App\Kernel('dev', true);
$kernel->boot();
$em = $kernel->getContainer()->get('doctrine')->getManager();
$uploadDir = __DIR__ . '/public/uploads/properties';
if (!is_dir($uploadDir)) mkdir($uploadDir, 0777, true);

$properties = $em->getRepository(\App\Entity\Property::class)->findAll();
$count = 0;
foreach ($properties as $p) {
    $images = $p->getImages() ?? [];
    $changed = false;
    $newImages = [];
    foreach ($images as $img) {
        if (is_string($img) && str_starts_with($img, 'data:image/')) {
            $base64 = explode(',', $img, 2)[1] ?? '';
            $data = base64_decode($base64);
            $ext = str_contains($img, 'png') ? 'png' : (str_contains($img, 'webp') ? 'webp' : 'jpg');
            $name = uniqid('prop_', true) . '.' . $ext;
            file_put_contents($uploadDir . '/' . $name, $data);
            $newImages[] = '/uploads/properties/' . $name;
            $changed = true;
        } else {
            $newImages[] = $img;
        }
    }
    if ($changed) {
        $p->setImages($newImages);
        $em->persist($p);
        $count++;
        echo "Bien #{$p->getId()} '{$p->getTitle()}' : " . count($newImages) . " image(s) converties\n";
    }
}
$em->flush();
echo "\nTerminé : $count bien(s) mis à jour.\n";
