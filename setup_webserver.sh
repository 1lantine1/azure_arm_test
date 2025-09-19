#!/bin/bash
set -e # 스크립트 실행 오류 시 즉시 중단

# --- Parameters ---
MYSQL_USER=$1
MYSQL_PASSWORD=$2
DB_NAME="webapp"
BASE_URL="https://raw.githubusercontent.com/1lantine1/azure_arm_test/main"
DEST_DIR="/var/www/html"

# --- Argument Check ---
if [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASSWORD" ]; then
  echo "Error: MySQL username and password must be provided."
  exit 1
fi

# --- 1. Install Packages (Robust Version) ---
echo "Waiting for apt/dpkg locks to be released..."
# Loop until the dpkg and apt lock files are free
while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 ; do
   echo "Another process is using apt, waiting 10 seconds..."
   sleep 10
done

echo "Force cleaning apt state and updating packages..."
export DEBIAN_FRONTEND=noninteractive
# Clean up any potentially corrupted list files
sudo rm -rf /var/lib/apt/lists/*
sudo apt-get clean
# Run a robust update
sudo apt-get update -y --fix-missing

echo "Installing Apache, PHP, MySQL..."
# Now, run the installation
sudo apt-get install -y \
  apache2 \
  php \
  libapache2-mod-php \
  php-mysql \
  mysql-server \
  curl

# --- 2. Start and Enable Services ---
echo "Starting and enabling services..."
systemctl start apache2
systemctl enable apache2
systemctl start mysql
systemctl enable mysql

# --- 3. Configure MySQL ---
echo "Configuring MySQL database and user..."
mysql -u root -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
mysql -u root -e "CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';"
mysql -u root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${MYSQL_USER}'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"
mysql -u root -e "USE ${DB_NAME}; CREATE TABLE IF NOT EXISTS scores (id INT AUTO_INCREMENT PRIMARY KEY, nickname VARCHAR(50) NOT NULL, score INT NOT NULL, duration_seconds INT NOT NULL, played_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"

# --- 4. Download Web Content from GitHub ---
echo "Downloading web files from GitHub to ${DEST_DIR}..."
rm -f ${DEST_DIR}/index.html # Remove default apache page
curl -sS -o ${DEST_DIR}/index.html ${BASE_URL}/index.html
curl -sS -o ${DEST_DIR}/game.html ${BASE_URL}/game.html
curl -sS -o ${DEST_DIR}/style.css ${BASE_URL}/style.css
curl -sS -o ${DEST_DIR}/game.js ${BASE_URL}/game.js
curl -sS -o ${DEST_DIR}/save_score.php ${BASE_URL}/save_score.php
curl -sS -o ${DEST_DIR}/get_leaderboard.php ${BASE_URL}/get_leaderboard.php

echo "Web server setup and game deployment completed successfully."
