<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include 'dbconnect.php';

// Get all unique device IDs from sensor_data table
$sql = "SELECT DISTINCT device_id FROM sensor_data ORDER BY device_id";
$result = $conn->query($sql);

$devices = [];
if ($result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $devices[] = $row['device_id'];
    }
}

echo json_encode([
    "status" => "success",
    "devices" => $devices
]);

$conn->close();
?>