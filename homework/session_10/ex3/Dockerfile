# ==========================================
# STAGE 1: BUILDER STAGE
# ==========================================
FROM node:18-alpine AS builder

WORKDIR /app

# Tận dụng tối đa Docker Layer Caching:
# Chỉ sao chép package*.json trước để cache bước npm install
COPY package*.json ./

# Cài đặt thư viện production và dọn dẹp cache của npm
RUN npm install --omit=dev && npm cache clean --force

# Sao chép mã nguồn ứng dụng
COPY . .

# ==========================================
# STAGE 2: RUNTIME STAGE (PRODUCTION)
# ==========================================
FROM node:18-alpine

WORKDIR /app

# Cấu hình môi trường Production
ENV NODE_ENV=production
ENV PORT=3000

# Khai báo cổng ứng dụng lắng nghe
EXPOSE 3000

# Chỉ sao chép các tệp thực sự cần thiết từ builder stage sang runtime
# Loại bỏ hoàn toàn npm cache, build tools trung gian và các tệp rác
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/server.js ./

# Khởi chạy ứng dụng với exec form
CMD ["node", "server.js"]
