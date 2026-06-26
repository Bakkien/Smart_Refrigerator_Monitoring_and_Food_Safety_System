<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include 'dbconnect.php';

$device_id = isset($_GET['device_id']) ? trim($_GET['device_id']) : '';

if (empty($device_id)) {
    echo json_encode(["status" => "error", "message" => "Device ID is required"]);
    exit;
}

$sql = "SELECT wifi_ssid, wifi_password FROM device_settings WHERE device_id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $device_id);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    $wifi = $result->fetch_assoc();
    echo json_encode([
        "status" => "success",
        "data" => $wifi
    ]);
} else {
    echo json_encode([
        "status" => "error",
        "message" => "Wi-Fi settings not found for device: " . $device_id
    ]);
}

$stmt->close();
$conn->close();
exit;
?>