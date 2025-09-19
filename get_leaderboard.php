<?php
header('Content-Type: application/json; charset=utf-8');

// 데이터베이스 연결 정보 (save_score.php와 동일한 이슈가 있음)
$servername = "localhost";
$username = "tetris_user"; // 실제 배포 시 이 값은 파라미터로 받아야 함
$password = "YourMySQLPassword456!"; // 실제 배포 시 이 값은 파라미터로 받아야 함
$dbname = "webapp";

// 데이터베이스 연결
$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode([]);
    exit();
}

$sql = "SELECT nickname, score FROM scores ORDER BY score DESC, played_at DESC LIMIT 10";
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
