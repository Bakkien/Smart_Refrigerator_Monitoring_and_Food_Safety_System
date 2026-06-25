<?php
    $servername = "localhost";
    $username = "canortxw_bakkien";
    $password = "C-%#jU6v,sHa";
    $dbname = "canortxw_srm_db";
    
    // Create connection
    $conn = new mysqli($servername, $username, $password, $dbname);
    // Check connection
    if ($conn->connect_error) {
        die("Connection failed: " . $conn->connect_error);
    }
?>