<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include 'dbconnect.php';

$device_id = isset($_GET['device_id']) ? trim($_GET['device_id']) : '';

if (empty($device_id)) {
    echo json_encode(["status" => "error", "message" => "Device ID is required"]);
    exit;
}

$sql = "SELECT * FROM sensor_data WHERE device_id = ? ORDER BY created_at DESC LIMIT 1";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $device_id);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    $data = $result->fetch_assoc();
    echo json_encode(["status" => "success", "data" => $data]);
} else {
    echo json_encode(["status" => "error", "message" => "No data found"]);
}

$stmt->close();
$conn->close();
?>