# BÀI TẬP 4: THIẾT LẬP CUSTOM NETWORK & NAMED VOLUME BẰNG DOCKER CLI

**Khóa học:** IT209 - Quản trị Hạ tầng & Công nghệ Đóng gói Ứng dụng  
**Session:** 10 - Bài tập 4 (Ex4)  
**Đường dẫn nộp bài:** `homework/session_10/ex4/`

---

## 1. Giới thiệu & Mục tiêu
Bài thực hành giải quyết 2 bài toán sống còn khi triển khai hệ thống phân tán (Microservices & Database) bằng Docker:
1. **Service Discovery qua Custom Network:** Cho phép các container tìm kiếm và kết nối với nhau thông qua tên định danh (Container Name / Service Name) thay vì phụ thuộc vào địa chỉ IP động dễ thay đổi.
2. **Lưu trữ dữ liệu bền vững (Data Persistence) qua Named Volume:** Tách rời trạng thái dữ liệu (state) khỏi vòng đời của container (ephemeral lifecycle), đảm bảo dữ liệu của Database không bị mất khi container gặp sự cố, bị khởi động lại hoặc bị xóa bỏ (`docker rm -f`).

---

## 2. Cấu trúc Thư mục Bài tập
```text
homework/session_10/ex4/
├── commands.sh       # Script bash thực thi tự động toàn bộ quy trình
└── README.md         # Báo cáo kỹ thuật chi tiết, giải thích kiến trúc & log kiểm thử
```

---

## 3. Phân tích Chuyên sâu Kiến trúc Mạng & Lưu trữ

### 3.1. Custom Bridge Network vs Default Bridge Network
Docker cung cấp sẵn một mạng mặc định tên là `bridge` (`docker0`). Tuy nhiên, trong sản xuất không bao giờ sử dụng default bridge để kết nối nhiều container vì những khác biệt bản chất sau:

| Tiêu chí | Default Bridge Network (`docker0`) | Custom Bridge Network (`app-net`) |
| :--- | :--- | :--- |
| **Phân giải DNS (Service Discovery)** | **Không hỗ trợ tự động:** Các container không thể ping hoặc kết nối với nhau qua Container Name. Muốn kết nối bắt buộc phải dùng IP tĩnh hoặc cờ `--link` cũ kỹ (đã bị deprecated). | **Tích hợp sẵn Embedded DNS Server:** Docker nhúng một máy chủ DNS nội bộ tại địa chỉ `127.0.0.11` bên trong mỗi container. Container chỉ cần gọi tên `db-server` là được phân giải tức thì ra địa chỉ IP nội bộ. |
| **Tính cô lập & Bảo mật (Isolation)** | Tất cả container không khai báo network đều bị đẩy chung vào mạng này, làm tăng nguy cơ tấn công trung gian giữa các ứng dụng không liên quan. | **Cô lập hoàn toàn:** Chỉ các container được chỉ định tham gia `app-net` mới có thể giao tiếp với nhau, ngăn chặn rò rỉ lưu lượng mạng ra ngoài. |
| **Gắn kết động (Hot-plugging)** | Không hỗ trợ ngắt kết nối mạng khi container đang chạy. | Hỗ trợ kết nối và ngắt kết nối linh hoạt (`docker network connect / disconnect`) ngay cả khi container đang hoạt động. |

### 3.2. Cơ chế Lưu trữ: Named Volume vs Bind Mount
Container bản chất là phi trạng thái (stateless) và có lớp lưu trữ ghi (writable layer) gắn liền với vòng đời của nó. Khi container bị xóa, toàn bộ dữ liệu trên writable layer sẽ biến mất vĩnh viễn.

- **Named Volume (`-v db-data:/var/lib/postgresql/data`):**
  - Do Docker Engine quản lý hoàn toàn tại phân vùng chuyên dụng (`/var/lib/docker/volumes/db-data/_data`).
  - **Độc lập vòng đời:** Tồn tại vĩnh viễn cho đến khi người quản trị gõ lệnh xóa tường minh (`docker volume rm`). Ngay cả khi container `db-server` bị xóa cưỡng bức bằng `docker rm -f`, volume vẫn nguyên vẹn.
  - **Hiệu năng cao:** Tận dụng trực tiếp hệ thống tệp gốc của Linux/WSL2 mà không bị suy giảm hiệu năng do cơ chế chia sẻ tệp chéo hệ điều hành (như trường hợp bind mount từ Windows Host `C:\` sang Linux container).
- **So sánh với Bind Mount (`-v /path/on/host:/path/in/container`):**
  - Bind mount phụ thuộc trực tiếp vào cấu trúc thư mục của máy chủ host, dễ gặp lỗi phân quyền (file permissions UID/GID) và không an toàn cho cơ sở dữ liệu quan hệ cần tốc độ I/O cao như PostgreSQL.

---

## 4. Hướng dẫn Lệnh Thực thi Từng bước (Step-by-Step)

### Bước 1: Tạo Custom Bridge Network
```bash
docker network create --driver bridge app-net
```

### Bước 2: Tạo Named Volume
```bash
docker volume create db-data
```

### Bước 3: Xác nhận Network và Volume đã sẵn sàng
```bash
docker network ls | grep app-net
docker volume ls | grep db-data
```

### Bước 4: Khởi chạy Database Container (PostgreSQL 15 Alpine)
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgrespassword \
  postgres:15-alpine
```

### Bước 5: Khởi chạy Backend Container (Node.js API)
```bash
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
```

### Bước 6: Kiểm tra DNS Resolution qua lệnh ping
```bash
docker exec -it app-container ping -c 2 db-server
```

### Bước 7: Kiểm tra cấu hình mạng chi tiết
```bash
docker network inspect app-net
```

---

## 5. Quy trình Kiểm thử Tính Bền vững Dữ liệu (Data Persistence Test)

Đây là bước chứng minh cốt lõi Named Volume hoạt động chính xác:

### Bước 5.1: Ghi dữ liệu mẫu vào Database `db-server`
```bash
docker exec -i db-server psql -U postgres -d testdb -c "CREATE TABLE IF NOT EXISTS users (id SERIAL PRIMARY KEY, name VARCHAR(100), email VARCHAR(100));"
docker exec -i db-server psql -U postgres -d testdb -c "INSERT INTO users (name, email) VALUES ('Nguyen Van A', 'vana@example.com'), ('Tran Thi B', 'thib@example.com');"
```

### Bước 5.2: Truy vấn kiểm tra dữ liệu trước khi xóa container
```bash
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"
```
*Kết quả:*
```text
 id |     name     |      email       
----+--------------+------------------
  1 | Nguyen Van A | vana@example.com
  2 | Tran Thi B   | thib@example.com
(2 rows)
```

### Bước 5.3: XÓA CỨNG CONTAINER DATABASE
```bash
docker rm -f db-server
```
*Kiểm tra danh sách container:* `docker ps -a` cho thấy container `db-server` đã bị xóa hoàn toàn khỏi hệ thống!

### Bước 5.4: Khởi chạy CONTAINER DB MỚI cùng tên và mount lại Volume `db-data`
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgrespassword \
  postgres:15-alpine
```

### Bước 5.5: Xác minh dữ liệu trong container mới
```bash
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"
```
*Kết quả thực tế sau khi tái tạo:*
```text
 id |     name     |      email       
----+--------------+------------------
  1 | Nguyen Van A | vana@example.com
  2 | Tran Thi B   | thib@example.com
(2 rows)
```
=> **Dữ liệu được khôi phục 100% nguyên vẹn!** Toàn bộ tệp dữ liệu bảng, chỉ mục và trạng thái giao dịch đã được bảo lưu an toàn bên trong Named Volume `db-data`.

---

## 6. Nhật ký Thực nghiệm Thực tế (Terminal Logs)

### 6.1. Log Ping DNS nội bộ:
```text
$ docker exec app-container ping -c 2 db-server
PING db-server (172.18.0.2): 56 data bytes
64 bytes from 172.18.0.2: seq=0 ttl=64 time=0.138 ms
64 bytes from 172.18.0.2: seq=1 ttl=64 time=0.124 ms

--- db-server ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.124/0.131/0.138 ms
```

### 6.2. Log Network Inspect `app-net`:
```json
{
    "Name": "app-net",
    "Driver": "bridge",
    "IPAM": {
        "Config": [
            {
                "Subnet": "172.18.0.0/16",
                "Gateway": "172.18.0.1"
            }
        ]
    },
    "Containers": {
        "10a386f9...": {
            "Name": "app-container",
            "IPv4Address": "172.18.0.3/16"
        },
        "2ccf50d7...": {
            "Name": "db-server",
            "IPv4Address": "172.18.0.2/16"
        }
    }
}
```

---

## 7. Hướng dẫn Chạy Script Tự Động
```bash
chmod +x commands.sh
./commands.sh
```
Hoặc thực thi qua Git Bash / WSL trên Windows:
```bash
bash commands.sh
```
