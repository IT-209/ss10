const express = require('express');
const app = express();

const PORT = process.env.PORT || 3000;

app.use(express.json());

// Endpoint chính trả về JSON đúng yêu cầu bài tập
app.get('/', (req, res) => {
  res.json({
    status: 'success',
    message: 'Hello from Docker Single-stage!'
  });
});

// Endpoint kiểm tra sức khỏe container
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
