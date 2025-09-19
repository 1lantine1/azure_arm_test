#!/bin/bash

# 스크립트 실행 오류 시 즉시 중단
set -e

# 전달받은 MySQL 사용자 이름과 비밀번호 변수에 저장
MYSQL_USER=$1
MYSQL_PASSWORD=$2
DB_NAME="webapp"

# 인자 확인
if [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASSWORD" ]; then
  echo "오류: MySQL 사용자 이름과 비밀번호를 인자로 전달해야 합니다."
  echo "사용법: $0 <username> <password>"
  exit 1
fi

# 1. 웹서버(Apache), PHP, MySQL 설치 및 설정
echo "패키지 목록 업데이트 중..."
apt-get update

echo "Apache, PHP, MySQL 서버 설치 중..."
apt-get install -y apache2 php libapache2-mod-php php-mysql mysql-server

# 2. 서비스 시작 및 부팅 시 자동 시작 설정
echo "Apache 및 MySQL 서비스 시작 및 활성화 중..."
systemctl start apache2
systemctl enable apache2
systemctl start mysql
systemctl enable mysql

# 3. MySQL 데이터베이스 및 사용자 생성
echo "MySQL 데이터베이스 및 사용자 설정 중..."
mysql -u root -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
mysql -u root -e "CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';"
mysql -u root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${MYSQL_USER}'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

# 4. 점수 저장을 위한 테이블 생성
echo "MySQL 'scores' 테이블 생성 중..."
mysql -u root -e "USE ${DB_NAME}; CREATE TABLE IF NOT EXISTS scores (id INT AUTO_INCREMENT PRIMARY KEY, nickname VARCHAR(50) NOT NULL, score INT NOT NULL, duration_seconds INT NOT NULL, played_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"

# 5. 웹 페이지 파일 자동 생성
echo "웹 애플리케이션 파일 생성 중..."

# index.html
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <title>Tetris - 닉네임 입력</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container center-flex">
        <div class="start-box">
            <h1>Tetris Game</h1>
            <form action="game.html" method="get">
                <input type="text" name="nickname" placeholder="닉네임을 입력하세요" required minlength="2" maxlength="15">
                <button type="submit">게임 시작</button>
            </form>
        </div>
    </div>
</body>
</html>
EOF

# game.html
cat <<EOF > /var/www/html/game.html
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <title>Tetris Game</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <div id="game-over-modal" class="modal">
            <div class="modal-content">
                <h2>Game Over</h2>
                <p>최종 점수: <span id="final-score"></span></p>
                <button onclick="window.location.href='/';">다시 시작</button>
            </div>
        </div>
        <h1>Tetris</h1>
        <div class="game-area">
            <canvas id="tetris-canvas" width="200" height="400"></canvas>
            <div class="side-panel">
                <div class="info-box">
                    <h2>Next</h2>
                    <canvas id="next-canvas" width="80" height="80"></canvas>
                </div>
                <div class="info-box" id="current-user-field">
                    <h2>Player</h2>
                    <p>Nickname: <span id="nickname-display"></span></p>
                    <p>Score: <span id="score-display">0</span></p>
                    <p>Time: <span id="time-display">0s</span></p>
                </div>
                <div class="info-box">
                    <h2>Leaderboard</h2>
                    <ol id="leaderboard"></ol>
                </div>
            </div>
        </div>
    </div>
    <script src="game.js"></script>
</body>
</html>
EOF

# style.css
cat <<EOF > /var/www/html/style.css
body {
    font-family: sans-serif;
    background-color: #f0f0f0;
    color: #333;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
    margin: 0;
}
h1, h2 {
    text-align: center;
}
.container {
    background-color: white;
    padding: 20px;
    border-radius: 10px;
    box-shadow: 0 0 15px rgba(0,0,0,.1);
}
.center-flex {
    align-items: center;
    text-align: center;
}
.start-box input {
    display: block;
    margin: 10px auto;
    padding: 10px;
    width: 80%;
    border-radius: 5px;
    border: 1px solid #ccc;
}
.start-box button {
    padding: 10px 20px;
    border-radius: 5px;
    border: none;
    background-color: #007bff;
    color: white;
    cursor: pointer;
    font-size: 16px;
}
.game-area {
    display: flex;
    gap: 20px;
}
canvas {
    border: 2px solid #333;
    background-color: #f9f9f9;
}
.side-panel {
    width: 200px;
}
.info-box {
    background-color: #e9e9e9;
    padding: 15px;
    border-radius: 5px;
    margin-bottom: 15px;
}
#leaderboard {
    list-style-position: inside;
    padding-left: 0;
}
.modal {
    display: none;
    position: fixed;
    z-index: 1;
    left: 0;
    top: 0;
    width: 100%;
    height: 100%;
    overflow: auto;
    background-color: rgba(0,0,0,.5);
}
.modal-content {
    background-color: #fefefe;
    margin: 15% auto;
    padding: 20px;
    border: 1px solid #888;
    width: 80%;
    max-width: 400px;
    text-align: center;
    border-radius: 10px;
}
.modal-content button {
    margin-top: 15px;
    padding: 10px 20px;
    border-radius: 5px;
    border: none;
    background-color: #007bff;
    color: white;
    cursor: pointer;
}
EOF

# game.js
cat <<'EOF' > /var/www/html/game.js
document.addEventListener('DOMContentLoaded', () => {
    const params = new URLSearchParams(window.location.search);
    const nickname = params.get('nickname') || 'Guest';
    document.getElementById('nickname-display').textContent = nickname;

    const canvas = document.getElementById('tetris-canvas');
    const context = canvas.getContext('2d');
    const nextCanvas = document.getElementById('next-canvas');
    const nextContext = nextCanvas.getContext('2d');
    const scoreDisplay = document.getElementById('score-display');
    const timeDisplay = document.getElementById('time-display');
    const leaderboardList = document.getElementById('leaderboard');

    const COLS = 10;
    const ROWS = 20;
    const BLOCK_SIZE = 20;
    const NEXT_BLOCK_SIZE = 20;

    context.scale(BLOCK_SIZE, BLOCK_SIZE);
    nextContext.scale(NEXT_BLOCK_SIZE, NEXT_BLOCK_SIZE);

    let score = 0;
    let startTime = Date.now();
    let gameInterval;
    let dropInterval = 1000;

    const grid = Array.from({ length: ROWS }, () => Array(COLS).fill(0));
    const shapes = [
        [[1,1,1,1]], // I
        [[1,1],[1,1]], // O
        [[1,1,0],[0,1,1]], // S
        [[0,1,1],[1,1,0]], // Z
        [[1,1,1],[0,1,0]], // T
        [[1,1,1],[1,0,0]], // L
        [[1,1,1],[0,0,1]]  // J
    ];
    const colors = [ null, '#FF0D72', '#0DC2FF', '#0DFF72', '#F538FF', '#FF8E0D', '#FFE138', '#3877FF' ];
    
    let currentPiece;
    let nextPiece;

    function createPiece() {
        const typeId = Math.floor(Math.random() * shapes.length);
        const shape = shapes[typeId];
        return {
            shape,
            color: colors[typeId + 1],
            x: Math.floor(COLS / 2) - Math.floor(shape[0].length / 2),
            y: 0
        };
    }

    function draw() {
        context.clearRect(0, 0, canvas.width, canvas.height);
        grid.forEach((row, y) => row.forEach((value, x) => {
            if (value > 0) {
                context.fillStyle = colors[value];
                context.fillRect(x, y, 1, 1);
            }
        }));
        if (currentPiece) {
            context.fillStyle = currentPiece.color;
            currentPiece.shape.forEach((row, dy) => row.forEach((value, dx) => {
                if (value) context.fillRect(currentPiece.x + dx, currentPiece.y + dy, 1, 1);
            }));
        }
    }
    
    function drawNext() {
        nextContext.clearRect(0, 0, nextCanvas.width, nextCanvas.height);
        if (nextPiece) {
            nextContext.fillStyle = nextPiece.color;
            nextPiece.shape.forEach((row, dy) => row.forEach((value, dx) => {
                if (value) nextContext.fillRect(dx, dy, 1, 1);
            }));
        }
    }

    function collides(piece) {
        for (let y = 0; y < piece.shape.length; y++) {
            for (let x = 0; x < piece.shape[y].length; x++) {
                if (piece.shape[y][x] && (grid[piece.y + y] && grid[piece.y + y][piece.x + x]) !== 0) {
                    return true;
                }
            }
        }
        return false;
    }

    function merge(piece) {
        piece.shape.forEach((row, y) => {
            row.forEach((value, x) => {
                if (value) {
                    grid[piece.y + y][piece.x + x] = colors.indexOf(piece.color);
                }
            });
        });
    }

    function rotate(piece) {
        const newShape = piece.shape[0].map((_, colIndex) => piece.shape.map(row => row[colIndex]).reverse());
        const originalX = piece.x;
        let offset = 1;
        while(collides({ ...piece, shape: newShape })) {
            piece.x += offset;
            offset = -(offset + (offset > 0 ? 1 : -1));
            if (offset > newShape[0].length) {
                piece.x = originalX;
                return;
            }
        }
        piece.shape = newShape;
    }

    function move(dir) {
        if (!currentPiece) return;
        currentPiece.x += dir;
        if (collides(currentPiece)) {
            currentPiece.x -= dir;
        }
    }

    function drop() {
        if (!currentPiece) return;
        currentPiece.y++;
        if (collides(currentPiece)) {
            currentPiece.y--;
            merge(currentPiece);
            clearLines();
            resetPiece();
            if (collides(currentPiece)) {
                gameOver();
            }
        }
    }
    
    function clearLines() {
        let linesCleared = 0;
        for (let y = ROWS - 1; y >= 0; y--) {
            if (grid[y].every(value => value > 0)) {
                linesCleared++;
                grid.splice(y, 1);
                grid.unshift(Array(COLS).fill(0));
                y++;
            }
        }
        if (linesCleared > 0) {
            score += linesCleared * 100 * linesCleared; // Bonus for multiple lines
            scoreDisplay.textContent = score;
            if (dropInterval > 200) {
                dropInterval -= 25;
                resetInterval();
            }
        }
    }

    function resetPiece() {
        currentPiece = nextPiece;
        nextPiece = createPiece();
        drawNext();
    }
    
    function resetInterval() {
        clearInterval(gameInterval);
        gameInterval = setInterval(drop, dropInterval);
    }

    function updateTime() {
        const elapsedSeconds = Math.floor((Date.now() - startTime) / 1000);
        timeDisplay.textContent = `${elapsedSeconds}s`;
    }

    async function fetchLeaderboard() {
        try {
            const response = await fetch('get_leaderboard.php');
            const data = await response.json();
            leaderboardList.innerHTML = '';
            data.forEach(item => {
                const li = document.createElement('li');
                li.textContent = `${item.nickname}: ${item.score}`;
                leaderboardList.appendChild(li);
            });
        } catch (error) {
            console.error('Leaderboard fetch error:', error);
        }
    }

    async function saveScore() {
        const duration = Math.floor((Date.now() - startTime) / 1000);
        const formData = new FormData();
        formData.append('nickname', nickname);
        formData.append('score', score);
        formData.append('duration', duration);
        try {
            await fetch('save_score.php', { method: 'POST', body: formData });
        } catch (error) {
            console.error('Score save error:', error);
        }
    }

    function gameOver() {
        clearInterval(gameInterval);
        document.getElementById('final-score').textContent = score;
        document.getElementById('game-over-modal').style.display = 'block';
        saveScore();
    }

    document.addEventListener('keydown', event => {
        if (!currentPiece) return;
        if (event.key === 'ArrowLeft') move(-1);
        else if (event.key === 'ArrowRight') move(1);
        else if (event.key === 'ArrowDown') drop();
        else if (event.key === 'ArrowUp') rotate(currentPiece);
        draw();
    });

    function startGame() {
        nextPiece = createPiece();
        resetPiece();
        fetchLeaderboard();
        setInterval(updateTime, 1000);
        gameInterval = setInterval(drop, dropInterval);
    }

    startGame();
    setInterval(fetchLeaderboard, 30000); // 30초마다 리더보드 갱신
});
EOF

# save_score.php
cat <<EOF > /var/www/html/save_score.php
<?php
header('Content-Type: application/json; charset=utf-8');

// 데이터베이스 연결 정보
\$servername = "localhost";
\$username = "${MYSQL_USER}";
\$password = "${MYSQL_PASSWORD}";
\$dbname = "${DB_NAME}";

// 데이터베이스 연결
\$conn = new mysqli(\$servername, \$username, \$password, \$dbname);
if (\$conn->connect_error) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'DB connection failed']);
    exit();
}

if (\$_SERVER['REQUEST_METHOD'] == 'POST') {
    \$nickname = \$_POST['nickname'] ?? '';
    \$score = \$_POST['score'] ?? 0;
    \$duration = \$_POST['duration'] ?? 0;

    if (!empty(\$nickname) && is_numeric(\$score) && is_numeric(\$duration)) {
        \$stmt = \$conn->prepare("INSERT INTO scores (nickname, score, duration_seconds) VALUES (?, ?, ?)");
        \$stmt->bind_param("sii", \$nickname, \$score, \$duration);

        if (\$stmt->execute()) {
            echo json_encode(['status' => 'success']);
        } else {
            http_response_code(500);
            echo json_encode(['status' => 'error', 'message' => 'Failed to save score']);
        }
        \$stmt->close();
    } else {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Invalid data']);
    }
}
\$conn->close();
?>
EOF

# get_leaderboard.php
cat <<EOF > /var/www/html/get_leaderboard.php
<?php
header('Content-Type: application/json; charset=utf-8');

// 데이터베이스 연결 정보
\$servername = "localhost";
\$username = "${MYSQL_USER}";
\$password = "${MYSQL_PASSWORD}";
\$dbname = "${DB_NAME}";

// 데이터베이스 연결
\$conn = new mysqli(\$servername, \$username, \$password, \$dbname);
if (\$conn->connect_error) {
    http_response_code(500);
    echo json_encode([]);
    exit();
}

\$sql = "SELECT nickname, score FROM scores ORDER BY score DESC, played_at DESC LIMIT 10";
\$result = \$conn->query(\$sql);

\$data = [];
if (\$result->num_rows > 0) {
    while(\$row = \$result->fetch_assoc()) {
        \$data[] = \$row;
    }
}
\$conn->close();

echo json_encode(\$data);
?>
EOF


echo "웹 서버 설치 및 게임 설정이 완료되었습니다."
