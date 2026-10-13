# Sử dụng Base Image chính thức của Node.js bản Alpine siêu nhẹ
FROM node:18-alpine

# Thiết lập thư mục làm việc trong container
WORKDIR /app

# Thiết lập biến môi trường cổng dịch vụ
ENV PORT=3000

# Khai báo cổng mà container sẽ lắng nghe khi chạy
EXPOSE 3000

# Sao chép file khai báo phụ thuộc trước để tối ưu hóa Layer Caching
COPY package*.json ./

# Cài đặt các dependencies cần thiết cho ứng dụng
RUN npm install

# Sao chép toàn bộ mã nguồn ứng dụng vào container
COPY . .

# Lệnh khởi chạy ứng dụng dưới dạng exec form
CMD ["node", "server.js"]
