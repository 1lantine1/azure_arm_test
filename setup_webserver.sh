#!/bin/bash

# 파라미터 받기: $1=MySQL 사용자명, $2=MySQL 비밀번호, $3=파일 기본 URL
MYSQL_USER=$1
MYSQL_PASS=$2
BASE_URL=$3

# === 시간대 설정 명령어 추가 (KST) ===
timedatectl set-timezone 'Asia/Seoul'

# 패키지 업데이트 및 필수 패키지 설치
apt-get update
apt-get install -y apache2 php libapache2-mod-php mysql-server python3

# 아파치 모듈 활성화 및 재시작
a2enconf php7.4-fpm
a2enmod rewrite
a2enmod proxy_fcgi
a2enmod ssl
systemctl restart apache2

# MySQL 데이터베이스 및 사용자 생성
mysql -e "CREATE DATABASE IF NOT EXISTS webapp;"
mysql -e "CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON webapp.* TO '${MYSQL_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"
mysql -e "USE webapp; CREATE TABLE IF NOT EXISTS users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255) NOT NULL, ip_address VARCHAR(45), log_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"

# 웹 파일 다운로드
# /var/www/html/ 경로에 기본 index.html이 있을 수 있으므로 삭제 후 진행
rm /var/www/html/index.html

# GitHub 등에서 Raw 파일 URL을 사용
curl -s -o /var/www/html/index.html ${BASE_URL}/index.html
curl -s -o /var/www/html/input.html ${BASE_URL}/input.html
curl -s -o /var/www/html/logging.html ${BASE_URL}/logging.html
curl -s -o /var/www/html/get_logs.php ${BASE_URL}/get_logs.php
curl -s -o /var/www/html/process_input.php ${BASE_URL}/process_input.php

# DB 설정 파일 생성 (내용을 직접 작성)
mkdir -p /var/www/includes
cat <<EOF > /var/www/includes/db_config.php
<?php
\$servername = "localhost";
\$username = "${MYSQL_USER}";
\$password = "${MYSQL_PASS}";
\$dbname = "webapp";
\$conn = new mysqli(\$servername, \$username, \$password, \$dbname);
if (\$conn->connect_error) {
    die("데이터베이스 연결 실패: " . \$conn->connect_error);
}
?>

EOF
