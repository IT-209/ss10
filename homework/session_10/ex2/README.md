# BÀI TẬP 2: ĐÓNG GÓI ỨNG DỤNG WEB BACKEND BẰNG SINGLE-STAGE DOCKERFILE

**Khóa học:** IT209 - Quản trị Hạ tầng & Công nghệ Đóng gói Ứng dụng  
**Session:** 10 - Bài tập 2 (Ex2)  
**Đường dẫn nộp bài:** `homework/session_10/ex2/`

---

## 1. Giới thiệu & Mục tiêu
Bài thực hành nhằm mục tiêu chuẩn hóa quy trình đóng gói ứng dụng Web Backend (Node.js/Express) bằng kỹ thuật **Single-stage Dockerfile**. Sau khi hoàn tất:
- Ứng dụng Web API độc lập được đóng gói hoàn chỉnh thành Docker Image `hw-backend:v1`.
- Container được khởi chạy với tên `app-single-stage`, ánh xạ cổng `8080:3000`.
- API phản hồi chính xác JSON tại địa chỉ `http://localhost:8080/`.

---

## 2. Cấu trúc Thư mục Bài tập
```text
homework/session_10/ex2/
├── Dockerfile          # Tệp hướng dẫn đóng gói Single-stage Dockerfile
├── .dockerignore       # Bỏ qua node_modules và các tệp không cần thiết
├── package.json        # Định nghĩa dự án và thư viện express
├── server.js           # Mã nguồn Web API Node.js/Express
└── README.md           # Hướng dẫn chi tiết và kết quả thực nghiệm
```

---

## 3. Giải thích Chi tiết các Chỉ thị trong Dockerfile

Dockerfile bao gồm đầy đủ các chỉ thị theo chuẩn OCI/Docker:

1. **`FROM node:18-alpine`**
   - Định nghĩa **Base Image** nền tảng. Sử dụng bản phân phối Alpine Linux với dung lượng siêu nhỏ (~5MB base + Node.js runtime ~170MB), giúp giảm tối đa kích thước image so với bản Ubuntu/Debian đầy đủ (~1GB).
2. **`WORKDIR /app`**
   - Thiết lập thư mục làm việc mặc định bên trong container là `/app`. Mọi chỉ thị tiếp theo (`COPY`, `RUN`, `CMD`) đều được thực thi tương đối từ thư mục này. Nếu thư mục chưa tồn tại, Docker sẽ tự động tạo mới.
3. **`ENV PORT=3000`**
   - Khai báo biến môi trường (Environment Variable) `PORT=3000`. Ứng dụng Node.js trong `server.js` đọc giá trị này qua `process.env.PORT`.
4. **`EXPOSE 3000`**
   - Khai báo metadata tài liệu rằng container lắng nghe trên cổng `3000`. Đây là hướng dẫn cấu hình mạng cho người vận hành (không tự động publish cổng ra máy chủ host nếu không có cờ `-p`).
5. **`COPY package*.json ./`**
   - Sao chép các tệp khai báo phụ thuộc (`package.json`, `package-lock.json` nếu có) vào thư mục làm việc `/app`.
   - **Tối ưu Layer Caching:** Tách riêng bước copy package file trước bước copy toàn bộ source code giúp Docker tái sử dụng kết quả `npm install` đã lưu trong cache khi lập trình viên chỉ chỉnh sửa mã nguồn JavaScript mà không thay đổi thư viện.
6. **`RUN npm install`**
   - Thực thi lệnh cài đặt các gói thư viện phụ thuộc (ở đây là Express) ngay trong quá trình Build Image.
7. **`COPY . .`**
   - Sao chép toàn bộ mã nguồn còn lại của ứng dụng vào container. Nhờ tệp `.dockerignore`, thư mục `node_modules` cục bộ trên host sẽ không bị ghi đè vào container.
8. **`CMD ["node", "server.js"]`**
   - Định nghĩa lệnh mặc định được thực thi khi Container khởi chạy.
   - **Exec form (dạng mảng JSON):** `["node", "server.js"]` giúp ứng dụng Node.js nhận trực tiếp `PID = 1` bên trong container, đón nhận trực tiếp các tín hiệu hệ thống (`SIGTERM`, `SIGINT`) để thực hiện Graceful Shutdown mà không bị bọc qua một tiến trình shell (`/bin/sh -c`).

---

## 4. Hướng dẫn Thực thi & Kiểm tra (Step-by-Step)

### Bước 1: Build Docker Image
Chuyển vào thư mục `homework/session_10/ex2` và thực thi:
```bash
docker build -t hw-backend:v1 .
```

### Bước 2: Khởi chạy Container
Khởi chạy container ở chế độ chạy nền (detached mode `-d`), đặt tên container là `app-single-stage`, ánh xạ cổng `8080` của host vào cổng `3000` của container:
```bash
docker run -d --name app-single-stage -p 8080:3000 hw-backend:v1
```

### Bước 3: Kiểm tra trạng thái Container
```bash
docker ps
```
*Kết quả mong đợi:* Container `app-single-stage` hiển thị trạng thái `Up` và Port `0.0.0.0:8080->3000/tcp`.

### Bước 4: Kiểm tra Log Container
```bash
docker logs app-single-stage
```
*Kết quả mong đợi:* `Server listening on port 3000`.

### Bước 5: Gửi yêu cầu HTTP kiểm tra API (cURL)
```bash
curl -i http://localhost:8080/
```
*Kết quả mong đợi:*
```http
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
Content-Length: 64

{"status":"success","message":"Hello from Docker Single-stage!"}
```

Kiểm tra thêm endpoint sức khỏe:
```bash
curl -i http://localhost:8080/health
```

### Bước 6: Dọn dẹp môi trường (Khi cần tắt)
```bash
docker stop app-single-stage
docker rm app-single-stage
```
