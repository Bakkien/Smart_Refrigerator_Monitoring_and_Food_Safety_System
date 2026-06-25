<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include 'dbconnect.php';

$device_id = isset($_GET['device_id']) ? trim($_GET['device_id']) : '';
$days = isset($_GET['days']) ? intval($_GET['days']) : 7;

if (empty($device_id)) {
    echo json_encode(["status" => "error", "message" => "Device ID is required"]);
    exit;
}

$sql = "SELECT * FROM sensor_data 
        WHERE device_id = ? 
        AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
        ORDER BY created_at ASC";

$stmt = $conn->prepare($sql);
$stmt->bind_param("si", $device_id, $days);
$stmt->execute();
$result = $stmt->get_result();

$data = [];
while ($row = $result->fetch_assoc()) {
    $data[] = $row;
}

echo json_encode([
    "status" => "success",
    "count" => count($data),
    "data" => $data
]);

$stmt->close();
$conn->close();
?>