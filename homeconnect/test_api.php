<?php

function post($url, $data) {
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
    $response = curl_exec($ch);
    $status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return ['status' => $status, 'body' => json_decode($response, true)];
}

echo "--- TEST 1: REGISTER ---\n";
$reg = post('http://localhost:8000/api/register', [
    'email' => 'test_api@test.com',
    'password' => 'password123',
    'prenom' => 'API',
    'nom' => 'Tester'
]);
print_r($reg);

if ($reg['status'] === 201 || $reg['status'] === 500) { // 500 if already exists
    echo "\n--- TEST 2: LOGIN ---\n";
    $login = post('http://localhost:8000/api/login_check', [
        'username' => 'test_api@test.com',
        'password' => 'password123'
    ]);
    print_r($login);

    if (isset($login['body']['token'])) {
        $token = $login['body']['token'];
        echo "\n--- TEST 3: GET ME ---\n";
        $ch = curl_init('http://localhost:8000/api/me');
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Authorization: Bearer ' . $token,
            'Accept: application/json'
        ]);
        $me = curl_exec($ch);
        print_r(json_decode($me, true));
        curl_close($ch);
    }
}
