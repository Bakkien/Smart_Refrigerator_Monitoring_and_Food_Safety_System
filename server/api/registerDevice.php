<?php
header("Access-Control-Allow-Origin: *");
include 'dbconnect.php';

$data = $_POST;
if (empty($data)) {
    $input = file_get_contents('php://input');
    parse_str($input, $parsed);
    if (!empty($parsed) && is_array($parsed)) {
        $data = $parsed;
    } else {
        $decoded = json_decode($input, true);
        if (is_array($decoded)) {
            $data = $decoded;
        }
    }
}

if (!isset($data['user_id']) || !isset($data['device_id'])) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Missing required fields: user_id, device_id'
    ]);
    exit;
}

$userId = intval($data['user_id']);
$deviceId = trim($data['device_id']);

// Validate device_id format (should match ESP32 device ID)
if (empty($deviceId)) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Device ID cannot be empty'
    ]);
    exit;
}

// Check if user exists
$stmt = $conn->prepare("SELECT id, device_id FROM users WHERE id = ?");
$stmt->bind_param("i", $userId);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo json_encode([
        'status' => 'error',
        'message' => 'User not found'
    ]);
    $stmt->close();
    exit;
}

$user = $result->fetch_assoc();
$stmt->close();

// Check if device_id exists in sensor_data table
$stmt = $conn->prepare("SELECT 1 FROM sensor_data WHERE device_id = ? LIMIT 1");
$stmt->bind_param("s", $deviceId);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Device ID does not exist in sensor data'
    ]);
    $stmt->close();
    exit;
}
$stmt->close();

// Check if device_id is already registered to another user
$stmt = $conn->prepare("SELECT id FROM users WHERE device_id = ? AND id != ?");
$stmt->bind_param("si", $deviceId, $userId);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Device ID is already registered to another user'
    ]);
    $stmt->close();
    exit;
}
$stmt->close();

// Check if user already has a device registered
if (!empty($user['device_id'])) {
    echo json_encode([
        'status' => 'error',
        'message' => 'You already have a device registered (Device ID: ' . $user['device_id'] . ')'
    ]);
    exit;
}

// Update user with device_id
$stmt = $conn->prepare("UPDATE users SET device_id = ? WHERE id = ?");
$stmt->bind_param("si", $deviceId, $userId);

if ($stmt->execute()) {
    echo json_encode([
        'status' => 'success',
        'message' => 'Device registered successfully',
        'data' => [
            'user_id' => $userId,
            'device_id' => $deviceId
        ]
    ]);
} else {
    echo json_encode([
        'status' => 'error',
        'message' => 'Device registration failed: ' . $stmt->error
    ]);
}

$stmt->close();
$conn->close();
?>