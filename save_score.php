<?php
header('Content-Type: application/json; charset=utf-8');

// 이 파일은 setup_webserver.sh가 DB 정보를 동적으로 채워주지 않으므로,
// ARM 템플릿의 commandToExecute에서 sed 같은 명령어로 DB 정보를 주입하거나
// 혹은 설정 파일을 별도로 분리해야 합니다.
// 지금은 하드코딩된 예시를 보여드립니다. 실제 배포 시에는 보안에 유의해야 합니다.

// 데이터베이스 연결 정보
$servername = "localhost";
$username = "tetris_user"; // 실제 배포 시 이 값은 파라미터로 받아야 함
$password = "YourMySQLPassword456!"; // 실제 배포 시 이 값은 파라미터로 받아야 함
$dbname = "webapp";

// 데이터베이스 연결
$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'DB connection failed']);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $nickname = $_POST['nickname'] ?? '';
    $score = $_POST['score'] ?? 0;
    $duration = $_POST['duration'] ?? 0;

    if (!empty($nickname) && is_numeric($score) && is_numeric($duration)) {
        $stmt = $conn->prepare("INSERT INTO scores (nickname, score, duration_seconds) VALUES (?, ?, ?)");
        $stmt->bind_param("sii", $nickname, $score, $duration);

        if ($stmt->execute()) {
            echo json_encode(['status' => 'success']);
        } else {
            http_response_code(500);
            echo json_encode(['status' => 'error', 'message' => 'Failed to save score']);
        }
        $stmt->close();
    } else {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Invalid data']);
    }
}
$conn->close();
?>
