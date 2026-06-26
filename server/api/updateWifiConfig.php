<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include 'dbconnect.php';

$device_id = isset($_POST['device_id']) ? trim($_POST['device_id']) : '';
$wifi_ssid = isset($_POST['wifi_ssid']) ? trim($_POST['wifi_ssid']) : '';
$wifi_password = isset($_POST['wifi_password']) ? trim($_POST['wifi_password']) : '';

if (empty($device_id)) {
    echo json_encode(["status" => "error", "message" => "Device ID is required"]);
    exit;
}

if (empty($wifi_ssid)) {
    echo json_encode(["status" => "error", "message" => "Wi-Fi SSID is required"]);
    exit;
}

$check_sql = "SELECT id FROM device_settings WHERE device_id = ?";
$check_stmt = $conn->prepare($check_sql);
$check_stmt->bind_param("s", $device_id);
$check_stmt->execute();
$check_result = $check_stmt->get_result();

$updated_at = date('Y-m-d H:i:s');

if ($check_result->num_rows > 0) {
    $sql = "UPDATE device_settings SET wifi_ssid = ?, wifi_password = ?, updated_at = ? WHERE device_id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ssss", $wifi_ssid, $wifi_password, $updated_at, $device_id);
    if ($stmt->execute()) {
        echo json_encode([
            "status" => "success",
            "message" => "Wi-Fi settings updated successfully",
            "updated_at" => $updated_at
        ]);
    } else {
        echo json_encode([
            "status" => "error",
            "message" => "Failed to update Wi-Fi settings: " . $stmt->error
        ]);
    }
    $stmt->close();
} else {
    $sql = "INSERT INTO device_settings (device_id, wifi_ssid, wifi_password, updated_at, buzzer_enabled) VALUES (?, ?, ?, ?, 0)";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ssss", $device_id, $wifi_ssid, $wifi_password, $updated_at);
    if ($stmt->execute()) {
        echo json_encode([
            "status" => "success",
            "message" => "Wi-Fi settings created successfully",
            "updated_at" => $updated_at
        ]);
    } else {
        echo json_encode([
            "status" => "error",
            "message" => "Failed to create Wi-Fi settings: " . $stmt->error
        ]);
    }
    $stmt->close();
}

$check_stmt->close();
$conn->close();
exit;
?>