const express = require('express');
const app = express();

const PORT = process.env.PORT || 3000;

app.use(express.json());

// Endpoint chính phản hồi JSON cho môi trường Production Multi-stage
app.get('/', (req, res) => {
  res.json({
    status: 'success',
    message: 'Hello from Docker Multi-stage Build!',
    environment: process.env.NODE_ENV || 'development'
  });
});

// Endpoint kiểm tra tài nguyên và uptime
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    memoryUsage: process.memoryUsage(),
    nodeVersion: process.version
  });
});

app.listen(PORT, () => {
  console.log(`Optimized Server listening on port ${PORT} [${process.env.NODE_ENV || 'development'}]`);
});
