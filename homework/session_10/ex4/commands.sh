#!/bin/bash
# ==============================================================================
# BÀI TẬP 4: THIẾT LẬP CUSTOM NETWORK & NAMED VOLUME BẰNG DOCKER CLI
# ==============================================================================
set -e

echo "=========================================================="
echo "  BẮT ĐẦU QUY TRÌNH THỰC THI BÀI TẬP 4 (EX4)"
echo "=========================================================="

# 1. Dọn dẹp tài nguyên cũ nếu có
echo "[1/7] Dọn dẹp container, network, volume cũ (nếu có)..."
docker rm -f app-container db-server 2>/dev/null || true
docker network rm app-net 2>/dev/null || true
docker volume rm db-data 2>/dev/null || true

# 2. Tạo Custom Bridge Network tên 'app-net'
echo "[2/7] Tạo Custom Bridge Network 'app-net'..."
docker network create --driver bridge app-net

# 3. Tạo Named Volume tên 'db-data'
echo "[3/7] Tạo Named Volume 'db-data'..."
docker volume create db-data

# 4. Kiểm tra sự tồn tại của Network và Volume
echo "[4/7] Xác nhận Network và Volume trong hệ thống..."
docker network ls | grep app-net
docker volume ls | grep db-data

# 5. Khởi chạy Database Container (PostgreSQL 15 Alpine)
# - Tham gia custom network app-net với tên miền nội bộ 'db-server'
# - Mount named volume db-data vào thư mục chuẩn /var/lib/postgresql/data
echo "[5/7] Khởi chạy Database Container 'db-server'..."
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgrespassword \
  postgres:15-alpine

echo "Chờ PostgreSQL sẵn sàng tiếp nhận kết nối (10 giây)..."
sleep 10

# 6. Khởi chạy Backend Container 'app-container'
# - Tham gia app-net
# - Cấu hình biến kết nối DB trỏ tới hostname 'db-server' (Embedded DNS)
echo "[6/7] Khởi chạy Backend Container 'app-container'..."
docker run -d \
  --name app-container \
  --network app-net \
  -p 8080:3000 \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=testdb \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgrespassword \
  hw-backend:v1

# 7. Kiểm tra phân giải tên miền nội bộ (Embedded DNS resolution)
echo "[7/7] Kiểm tra ping từ Backend container tới Database container..."
docker exec app-container ping -c 2 db-server

echo "Kiểm tra thông tin chi tiết app-net:"
docker network inspect app-net

# ==============================================================================
# KIỂM THỬ DATA PERSISTENCE (TÍNH TOÀN VẸN CỦA DỮ LIỆU QUA NAMED VOLUME)
# ==============================================================================
echo "=========================================================="
echo "  THỰC HIỆN KIỂM THỬ TÍNH BỀN VỮNG DỮ LIỆU (DATA PERSISTENCE)"
echo "=========================================================="

echo "Bước 8.1: Tạo bảng 'users' và thêm dữ liệu ban đầu vào db-server..."
docker exec -i db-server psql -U postgres -d testdb << 'EOF'
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (name, email) VALUES
('Nguyen Van A', 'vana@example.com'),
('Tran Thi B', 'thib@example.com'),
('Le Van C', 'vanc@example.com');
EOF

echo "Bước 8.2: Truy vấn dữ liệu hiện tại:"
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"

echo "Bước 8.3: XÓA CỨNG CONTAINER DB (docker rm -f db-server)..."
docker rm -f db-server

echo "Kiểm tra: Container db-server đã bị xóa hoàn toàn khỏi docker ps:"
docker ps -a | grep db-server || echo "Container db-server không còn tồn tại."

echo "Bước 8.4: Khởi chạy CONTAINER DB MỚI cùng tên, gắn lại Named Volume 'db-data'..."
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgrespassword \
  postgres:15-alpine

echo "Chờ DB container mới nạp dữ liệu từ Named Volume..."
sleep 10

echo "Bước 8.5: Xác minh dữ liệu trong container mới tái tạo:"
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"

echo "=========================================================="
echo "  XÁC MINH THÀNH CÔNG: DỮ LIỆU HOÀN TOÀN NGUYÊN VẸN!"
echo "=========================================================="
