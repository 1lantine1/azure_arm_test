<?php
header('Content-Type: application/json; charset=utf-8');
include_once '/var/www/includes/db_config.php';

$sql = "SELECT id, name, ip_address, log_time FROM users ORDER BY log_time DESC";
$result = $conn->query($sql);

$data = [];
if ($result->num_rows > 0) {
    while($row = $result->fetch_assoc()) {
        $data[] = $row;
    }
}
$conn->close();

echo json_encode($data);
?>