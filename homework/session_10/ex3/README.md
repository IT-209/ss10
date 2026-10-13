# BÀI TẬP 3: TỐI ƯU HÓA DUNG LƯỢNG IMAGE & LAYER CACHING VỚI MULTI-STAGE BUILD

**Khóa học:** IT209 - Quản trị Hạ tầng & Công nghệ Đóng gói Ứng dụng  
**Session:** 10 - Bài tập 3 (Ex3)  
**Đường dẫn nộp bài:** `homework/session_10/ex3/`

---

## 1. Giới thiệu & Mục tiêu
Trong môi trường Production, việc tối ưu hóa Docker Image là yêu cầu bắt buộc nhằm:
1. **Giảm thiểu thời gian tải & triển khai (Deploy time / Pull time):** Image càng nhẹ, tốc độ truyền qua mạng nội bộ hoặc Container Registry càng nhanh.
2. **Tiết kiệm tài nguyên lưu trữ (Storage):** Giảm chi phí lưu trữ trên server và registry.
3. **Gia tăng tính bảo mật (Hardening & Reduced Attack Surface):** Loại bỏ hoàn toàn các công cụ biên dịch (compilers, build-tools, package managers cache) khỏi runtime container, ngăn chặn kẻ tấn công lợi dụng các công cụ này khi container bị thâm nhập.

Bài thực hành so sánh trực quan giữa kỹ thuật **Single-stage Build** và **Multi-stage Build**, đồng thời áp dụng nguyên lý **Docker Layer Caching**.

---

## 2. Cấu trúc Thư mục Bài tập
```text
homework/session_10/ex3/
├── Dockerfile           # Multi-stage Dockerfile tối ưu hóa cho Production
├── Dockerfile.single    # Single-stage Dockerfile dùng làm mốc đối chứng
├── .dockerignore        # Bỏ qua node_modules và tệp tạm
├── package.json         # Khai báo phụ thuộc ứng dụng Express
├── server.js            # Mã nguồn Web API Node.js/Express
└── README.md            # Phân tích kỹ thuật & bảng so sánh thực nghiệm
```

---

## 3. Phân tích Nguyên lý Kỹ thuật Cốt lõi

### 3.1. Cơ chế Layer Caching (Bộ nhớ đệm tầng)
Docker xây dựng Image dưới dạng các tầng xếp chồng lên nhau (Union File System - Overlay2). Mỗi chỉ thị (`COPY`, `RUN`, `ADD`) tạo ra một layer mới có mã băm SHA256 tương ứng.
- **Quy tắc tận dụng Cache:** Docker sẽ tái sử dụng cache từ layer trước nếu tập lệnh và dữ liệu đầu vào không thay đổi. Khi một layer bị vô hiệu hóa cache (cache miss), tất cả các layer phía sau nó đều buộc phải build lại từ đầu.
- **Kỹ thuật tối ưu:**
  ```dockerfile
  # BƯỚC 1: Chỉ copy file package*.json trước
  COPY package*.json ./
  RUN npm install --omit=dev && npm cache clean --force

  # BƯỚC 2: Copy toàn bộ source code sau
  COPY . .
  ```
  Nếu lập trình viên chỉ sửa đổi code trong `server.js` mà không cài thêm thư viện, Docker sẽ sử dụng lại toàn bộ layer đã cài `node_modules` từ cache, rút ngắn thời gian build từ hàng chục giây xuống dưới 1 giây.

### 3.2. Kỹ thuật Multi-stage Build (Xây dựng đa giai đoạn)
Trong Single-stage, mọi tệp tạm sinh ra trong quá trình cài đặt (npm cache, log, tệp build tạm thời) đều bị lưu vĩnh viễn vào lịch sử layer của Image cuối cùng.

Với Multi-stage Build:
- **Stage 1 (`AS builder`):** Đóng vai trò là "nhà xưởng" chuyên dụng. Tại đây thực hiện tải thư viện, biên dịch mã nguồn, dọn rác.
- **Stage 2 (Runtime):** Khởi tạo từ một base image sạch (`node:18-alpine`). Sử dụng chỉ thị `COPY --from=builder` để chỉ bốc đúng những tệp thành phẩm cần thiết (`node_modules`, `package.json`, `server.js`). Mọi công cụ build hay rác trung gian ở Stage 1 đều bị hủy bỏ hoàn toàn.

---

## 4. Bảng So sánh Thực nghiệm: Single-stage vs Multi-stage Build

Số liệu được đo lường thực tế từ Docker Engine trên hệ thống:

| Tiêu chí kỹ thuật | `hw-backend:single` (Single-stage) | `hw-backend:multistage` (Multi-stage) | Nhận xét & Đánh giá |
| :--- | :--- | :--- | :--- |
| **Tổng dung lượng Image** | **135 MB** | **129 MB** | Giảm tổng thể ~6 MB. (Phần base image chiếm ~127 MB, phần app tối ưu đáng kể). |
| **Dung lượng Layer `node_modules`** | **7.73 MB** (bao gồm npm cache, temporary files) | **2.34 MB** (chỉ chứa pure production dependencies) | **Giảm tới 69.7% (~70%) dung lượng tầng ứng dụng!** |
| **Chỉ số an toàn bảo mật** | Thấp hơn (còn lưu cache, tệp log của npm) | **Rất cao (Zero npm cache, biến môi trường `NODE_ENV=production`)** | Giảm thiểu diện tích bề mặt tấn công (Attack Surface). |
| **Số lượng Layer tầng ứng dụng** | 3 layers (`WORKDIR`, `npm install`, `COPY . .`) | 4 layers (`WORKDIR`, `COPY package`, `COPY modules`, `COPY server.js`) | Các layers được tách bạch rõ ràng, tối đa hóa khả năng tái sử dụng Cache. |
| **Thời gian Re-build khi sửa code** | Nhanh nếu giữ cache | **Siêu nhanh (< 0.2s)** do chỉ copy file `server.js` vào runtime stage. |

### Chi tiết Phân tích Layer (Trích xuất từ `docker history`):

- **Image `hw-backend:single`:**
  ```text
  IMAGE          CREATED         CREATED BY                                      SIZE
  1054d911b169   2 minutes ago   CMD ["node" "server.js"]                        0B
  <missing>      2 minutes ago   COPY . . # buildkit                             2.24kB
  <missing>      2 minutes ago   RUN /bin/sh -c npm install # buildkit           7.73MB  <-- Tầng cài đặt phình to
  <missing>      2 minutes ago   COPY package*.json ./ # buildkit                271B
  ```

- **Image `hw-backend:multistage`:**
  ```text
  IMAGE          CREATED         CREATED BY                                      SIZE
  94b0adbbcb2c   2 minutes ago   CMD ["node" "server.js"]                        0B
  <missing>      2 minutes ago   COPY /app/server.js ./ # buildkit               754B
  <missing>      2 minutes ago   COPY /app/node_modules ./node_modules           2.34MB  <-- Tối ưu chỉ còn 2.34MB!
  <missing>      2 minutes ago   COPY /app/package*.json ./ # buildkit           29.8kB
  ```

---

## 5. Hướng dẫn Lệnh Build & Kiểm tra Thực tế

### 5.1. Build cả 2 Image để so sánh
```bash
# 1. Build Single-stage image
docker build -f Dockerfile.single -t hw-backend:single .

# 2. Build Multi-stage image
docker build -t hw-backend:multistage .
```

### 5.2. Kiểm tra danh sách Image và dung lượng
```bash
docker images | grep hw-backend
# Trên Windows PowerShell:
docker images | findstr hw-backend
```
*Kết quả thực tế:*
```text
hw-backend:multistage   94b0adbbcb2c   129MB
hw-backend:single       1054d911b169   135MB
```

### 5.3. Khởi chạy và kiểm tra API của Multi-stage Container
```bash
# Khởi chạy container
docker run -d --name app-multistage -p 8081:3000 hw-backend:multistage

# Gửi request kiểm tra
curl.exe -i http://localhost:8081/
```
*Kết quả trả về:*
```http
HTTP/1.1 200 OK
X-Powered-By: Express
Content-Type: application/json; charset=utf-8
Content-Length: 96

{"status":"success","message":"Hello from Docker Multi-stage Build!","environment":"production"}
```

```bash
# Dọn dẹp container kiểm tra
docker stop app-multistage && docker rm app-multistage
```
