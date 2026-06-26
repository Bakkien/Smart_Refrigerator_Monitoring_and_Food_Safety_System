<?php
header("Access-Control-Allow-Origin: *");
include 'dbconnect.php';

$data = $_POST;
if (empty($data)) {
    $input = file_get_contents('php://input');
    $decoded = json_decode($input, true);
    if (is_array($decoded)) {
        $data = $decoded;
    }
}

if (!isset($data['username']) || !isset($data['password'])) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Missing required fields: username, password'
    ]);
    exit;
}

$username = trim($data['username']);
$password = $data['password'];

// Get user from database
$stmt = $conn->prepare("SELECT id, username, email, password, device_id FROM users WHERE username = ?");
$stmt->bind_param("s", $username);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Invalid username'
    ]);
    $stmt->close();
    exit;
}

$user = $result->fetch_assoc();

// Verify password
$isValidPassword = password_verify($password, $user['password']) ||
    hash_equals($user['password'], sha1($password));

if (!$isValidPassword) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Invalid password'
    ]);
    $stmt->close();
    exit;
}

$stmt->close();

echo json_encode([
    'status' => 'success',
    'message' => 'Login successful',
    'data' => [
        'id' => $user['id'],
        'username' => $user['username'],
        'email' => $user['email'],
        'device_id' => $user['device_id']
    ]
]);

$conn->close();
?>