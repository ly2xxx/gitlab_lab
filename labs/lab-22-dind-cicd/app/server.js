const http = require('http');
const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(`
    <html>
      <head>
        <title>DinD Lab Demo</title>
      </head>
      <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white;">
        <h1>🐳 Hello from Docker!</h1>
        <p style="font-size: 1.2em;">Built with CI/CD using Docker-in-Docker</p>
        <div style="background: rgba(255,255,255,0.1); padding: 20px; border-radius: 10px; margin: 20px auto; max-width: 400px;">
          <p><strong>Environment:</strong> ${process.env.NODE_ENV || 'development'}</p>
          <p><strong>Container ID:</strong> ${require('os').hostname()}</p>
          <p><strong>Node Version:</strong> ${process.version}</p>
        </div>
        <p style="font-size: 0.9em; margin-top: 40px;">Lab 22: Docker-in-Docker CI/CD</p>
      </body>
    </html>
  `);
});

server.listen(port, () => {
  console.log(`✅ Server running on port ${port}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Container: ${require('os').hostname()}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
