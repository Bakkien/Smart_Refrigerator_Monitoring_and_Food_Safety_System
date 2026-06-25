<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include 'dbconnect.php';

// Get POST data from ESP32
$device_id = isset($_POST['device_id']) ? trim($_POST['device_id']) : '';
$temperature = isset($_POST['temperature']) ? floatval($_POST['temperature']) : 0;
$humidity = isset($_POST['humidity']) ? floatval($_POST['humidity']) : 0;
$gas_level = isset($_POST['gas_level']) ? intval($_POST['gas_level']) : 0;
$door_status = isset($_POST['door_status']) ? $_POST['door_status'] : '';
$status = isset($_POST['system_status']) ? $_POST['system_status'] : 'NORMAL';
$created_at = isset($_POST['created_at']) ? $_POST['created_at'] : '';

// Validate required data
if (empty($device_id)) {
    echo json_encode(["status" => "error", "message" => "Device ID is required"]);
    exit;
}

// Validate datetime format (YYYY-MM-DD HH:MM:SS)
if (empty($created_at)) {
    echo json_encode(["status" => "error", "message" => "Timestamp is required"]);
    exit;
}

$datetime_pattern = '/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/';
if (!preg_match($datetime_pattern, $created_at)) {
    echo json_encode(["status" => "error", "message" => "Invalid datetime format. Use: YYYY-MM-DD HH:MM:SS"]);
    exit;
}

// Insert data
$sql = "INSERT INTO sensor_data (device_id, temperature, humidity, gas_level, door_status, status, created_at) 
        VALUES (?, ?, ?, ?, ?, ?, ?)";

$stmt = $conn->prepare($sql);
$stmt->bind_param("sddisss", $device_id, $temperature, $humidity, $gas_level, $door_status, $status, $created_at);

if ($stmt->execute()) {
    echo json_encode(["status" => "success", "message" => "Data saved successfully"]);
} else {
    echo json_encode(["status" => "error", "message" => "Failed to save data: " . $stmt->error]);
}

$stmt->close();
$conn->close();
?>