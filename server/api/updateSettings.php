<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include 'dbconnect.php';


$device_id = isset($_POST['device_id']) ? trim($_POST['device_id']) : '';
$temperature_threshold = isset($_POST['temperature_threshold']) ? floatval($_POST['temperature_threshold']) : 10.0;
$humidity_threshold_low = isset($_POST['humidity_threshold_low']) ? floatval($_POST['humidity_threshold_low']) : 50.0;
$humidity_threshold_high = isset($_POST['humidity_threshold_high']) ? floatval($_POST['humidity_threshold_high']) : 85.0;
$gas_threshold_normal = isset($_POST['gas_threshold_normal']) ? intval($_POST['gas_threshold_normal']) : 150;
$gas_threshold_warning = isset($_POST['gas_threshold_warning']) ? intval($_POST['gas_threshold_warning']) : 300;
$upload_interval = isset($_POST['upload_interval']) ? intval($_POST['upload_interval']) : 5;
$buzzer_enabled = isset($_POST['buzzer_enabled']) ? intval($_POST['buzzer_enabled']) : 1;
$updated_at = date('Y-m-d H:i:s');
    
// Validate required data
if (empty($device_id)) {
    echo json_encode(["status" => "error", "message" => "Device ID is required"]);
    exit;
}
    
// Check if device exists
$check_sql = "SELECT id FROM device_settings WHERE device_id = ?";
$check_stmt = $conn->prepare($check_sql);
$check_stmt->bind_param("s", $device_id);
$check_stmt->execute();
$check_result = $check_stmt->get_result();
    
if ($check_result->num_rows > 0) {
    // Update existing settings
    $sql = "UPDATE device_settings SET 
                temperature_threshold = ?,
                humidity_threshold_low = ?,
                humidity_threshold_high = ?,
                gas_threshold_normal = ?,
                gas_threshold_warning = ?,
                upload_interval = ?,
                buzzer_enabled = ?,
                updated_at = ?
            WHERE device_id = ?";
        
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("dddiiiiss", 
        $temperature_threshold,
        $humidity_threshold_low,
        $humidity_threshold_high,
        $gas_threshold_normal,
        $gas_threshold_warning,
        $upload_interval,
        $buzzer_enabled,
        $updated_at,
        $device_id
    );
        
    if ($stmt->execute()) {
        echo json_encode([
            "status" => "success",
            "message" => "Settings updated successfully",
            "updated_at" => $updated_at
        ]);
    } else {
        echo json_encode([
            "status" => "error",
            "message" => "Failed to update settings: " . $stmt->error
        ]);
    }
    $stmt->close();
} else {
    // Insert new settings
    $sql = "INSERT INTO device_settings (
                device_id, 
                temperature_threshold, 
                humidity_threshold_low, 
                humidity_threshold_high, 
                gas_threshold_normal, 
                gas_threshold_warning, 
                upload_interval, 
                buzzer_enabled, 
                updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
        
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sssddiiss", 
        $device_id,
        $temperature_threshold,
        $humidity_threshold_low,
        $humidity_threshold_high,
        $gas_threshold_normal,
        $gas_threshold_warning,
        $upload_interval,
        $buzzer_enabled,
        $updated_at
    );
        
    if ($stmt->execute()) {
        echo json_encode([
            "status" => "success",
            "message" => "Settings created successfully",
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
exit;

?>