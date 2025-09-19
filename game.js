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
