const express = require("express");
const mysql = require("mysql2/promise");
const cors = require("cors");

const app = express();
const PORT = process.env.PORT || 3000;
const SERVER_ID = process.env.SERVER_ID || "unknown";

// Middleware
app.use(cors());
app.use(express.json());

// Database connection
let dbConnection;

async function connectDB() {
  try {
    dbConnection = await mysql.createConnection({
      host: process.env.DB_HOST || "localhost",
      user: process.env.DB_USER || "user",
      password: process.env.DB_PASSWORD || "password",
      database: process.env.DB_NAME || "loadbalancer_db",
    });
    console.log(`Server ${SERVER_ID}: Database connected successfully`);
  } catch (error) {
    console.error(`Server ${SERVER_ID}: Database connection failed:`, error);
  }
}

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({
    status: "healthy",
    server_id: SERVER_ID,
    timestamp: new Date().toISOString(),
  });
});

// Main endpoint that will be load balanced
app.get("/api/server-info", async (req, res) => {
  try {
    const clientIP = req.ip || req.connection.remoteAddress;
    const userAgent = req.get("User-Agent");

    // Log request to database
    if (dbConnection) {
      await dbConnection.execute(
        "INSERT INTO requests (server_id, client_ip, user_agent) VALUES (?, ?, ?)",
        [SERVER_ID, clientIP, userAgent]
      );
    }

    res.json({
      server_id: SERVER_ID,
      timestamp: new Date().toISOString(),
      message: `Request handled by Server ${SERVER_ID}`,
      client_ip: clientIP,
      database_status: dbConnection ? "connected" : "disconnected",
    });
  } catch (error) {
    console.error(`Server ${SERVER_ID}: Error:`, error);
    res.status(500).json({
      error: "Internal server error",
      server_id: SERVER_ID,
    });
  }
});

// Get request statistics
app.get("/api/stats", async (req, res) => {
  try {
    if (!dbConnection) {
      return res.status(500).json({ error: "Database not connected" });
    }

    const [rows] = await dbConnection.execute(
      "SELECT server_id, COUNT(*) as request_count FROM requests GROUP BY server_id"
    );

    res.json({
      server_id: SERVER_ID,
      statistics: rows,
      total_requests: rows.reduce((sum, row) => sum + row.request_count, 0),
    });
  } catch (error) {
    console.error(`Server ${SERVER_ID}: Error getting stats:`, error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Start server
app.listen(PORT, async () => {
  console.log(`Server ${SERVER_ID} is running on port ${PORT}`);
  await connectDB();
});

// Graceful shutdown
process.on("SIGTERM", async () => {
  console.log(`Server ${SERVER_ID}: Shutting down gracefully`);
  if (dbConnection) {
    await dbConnection.end();
  }
  process.exit(0);
});
