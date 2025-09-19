<?php
// 이 스크립트는 이제 HTML을 반환하지 않고, JSON 데이터만 반환합니다.

// 응답의 타입을 JSON으로 설정
header('Content-Type: application/json; charset=utf-8');

include_once '/var/www/includes/db_config.php';

// 반환할 데이터를 담을 배열 초기화
$response = [
    'success' => false,
    'message' => '',
    'statusMessage' => ''
];

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $name = isset($_POST['name_input']) ? trim($_POST['name_input']) : '';

    if (!empty($name)) {
        $user_ip = $_SERVER['REMOTE_ADDR'];
        
        // 환영 메시지 설정
        $response['message'] = htmlspecialchars($name) . '님 안녕하세요!';
        
        // 데이터베이스에 저장 시도
        $stmt = $conn->prepare("INSERT INTO users (name, ip_address) VALUES (?, ?)");
        $stmt->bind_param("ss", $name, $user_ip);

        if ($stmt->execute()) {
            $response['success'] = true;
            $response['statusMessage'] = "데이터가 성공적으로 저장되었습니다.";
        } else {
            $response['statusMessage'] = "데이터 저장 중 오류 발생: " . htmlspecialchars($stmt->error);
        }
        $stmt->close();

    } else {
        $response['statusMessage'] = "이름을 입력해주세요.";
    }
}

// 최종적으로 배열을 JSON 문자열로 변환하여 출력
echo json_encode($response);
?>
