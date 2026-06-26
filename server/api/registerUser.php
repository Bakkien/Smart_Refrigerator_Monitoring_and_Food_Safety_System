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

// Validate input
if (!isset($data['username']) || !isset($data['email']) || !isset($data['password'])) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Missing required fields: username, email, password'
    ]);
    exit;
}

$username = trim($data['username']);
$email = trim($data['email']);
$password = $data['password'];
$hashed_password = password_hash($password, PASSWORD_DEFAULT);

// Check if email already exists
$stmt = $conn->prepare("SELECT id FROM users WHERE email = ?");
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Email already registered'
    ]);
    $stmt->close();
    exit;
}
$stmt->close();

// Insert new user
$stmt = $conn->prepare("INSERT INTO users (username, email, password) VALUES (?, ?, ?)");
$stmt->bind_param("sss", $username, $email, $hashed_password);

if ($stmt->execute()) {
    $userId = $stmt->insert_id;
    echo json_encode([
        'status' => 'success',
        'message' => 'User registered successfully',
        'data' => [
            'id' => $userId,
            'username' => $username,
            'email' => $email
        ]
    ]);
} else {
    echo json_encode([
        'status' => 'error',
        'message' => 'Registration failed: ' . $stmt->error
    ]);
}

$stmt->close();
$conn->close();
?>