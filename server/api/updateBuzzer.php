<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include 'dbconnect.php';

$device_id = isset($_POST['device_id']) ? trim($_POST['device_id']) : '';
$buzzer_enabled = isset($_POST['buzzer_enabled']) ? intval($_POST['buzzer_enabled']) : 0;
$updated_at = date('Y-m-d H:i:s');

if (empty($device_id)) {
    echo json_encode(["status" => "error", "message" => "Device ID is required"]);
    exit;
}

// Check if device exists in device_settings
$check_sql = "SELECT id FROM device_settings WHERE device_id = ?";
$check_stmt = $conn->prepare($check_sql);
$check_stmt->bind_param("s", $device_id);
$check_stmt->execute();
$check_result = $check_stmt->get_result();

if ($check_result->num_rows > 0) {
    // Update existing settings
    $sql = "UPDATE device_settings SET buzzer_enabled = ?, updated_at = ? WHERE device_id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("iss", $buzzer_enabled, $updated_at, $device_id);
    
    if ($stmt->execute()) {
        echo json_encode([
            "status" => "success",
            "message" => "Buzzer setting updated successfully",
            "buzzer_enabled" => $buzzer_enabled,
            "updated_at" => $updated_at
        ]);
    } else {
        echo json_encode([
            "status" => "error",
            "message" => "Failed to update buzzer setting: " . $stmt->error
        ]);
    }
    $stmt->close();
} else {
    // Insert new settings with default values and buzzer setting
    $sql = "INSERT INTO device_settings (
                device_id, 
                buzzer_enabled, 
                temperature_threshold,
                humidity_threshold_low,
                humidity_threshold_high,
                gas_threshold_normal,
                gas_threshold_warning,
                upload_interval,
                updated_at
            ) VALUES (?, ?, 10.0, 50.0, 85.0, 150, 300, 5, ?)";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sis", $device_id, $buzzer_enabled, $updated_at);
    
    if ($stmt->execute()) {
        echo json_encode([
            "status" => "success",
            "message" => "Device settings created with buzzer setting",
            "buzzer_enabled" => $buzzer_enabled,
            "updated_at" => $updated_at
        ]);
    } else {
        echo json_encode([
            "status" => "error",
            "message" => "Failed to create settings: " . $stmt->error
        ]);
    }
    $stmt->close();
}

$check_stmt->close();
$conn->close();
?>