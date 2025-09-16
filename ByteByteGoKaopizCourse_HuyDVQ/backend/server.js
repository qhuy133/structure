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
let masterConnection;

async function connectDatabase() {
  const maxRetries = 10;
  const retryDelay = 3000;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      console.log(
        `Server ${SERVER_ID}: Connecting to database (${attempt}/${maxRetries})`
      );

      // Connect to Master DB (for WRITE operations)
      masterConnection = await mysql.createConnection({
        host: "mysql-master",
        user: "user",
        password: "password",
        database: "loadbalancer_db",
        connectTimeout: 10000,
        acquireTimeout: 10000,
        timeout: 10000,
      });
      console.log(`Server ${SERVER_ID}: Master DB connected successfully`);


      // Test connections
      await masterConnection.execute("SELECT 1");
      console.log(`Server ${SERVER_ID}: Database connections test successful`);

      return;
    } catch (error) {
      console.error(
        `Server ${SERVER_ID}: Database connection attempt ${attempt} failed:`,
        error.message
      );

      if (attempt < maxRetries) {
        console.log(
          `Server ${SERVER_ID}: Retrying in ${retryDelay / 1000} seconds...`
        );
        await new Promise((resolve) => setTimeout(resolve, retryDelay));
      } else {
        console.error(
          `Server ${SERVER_ID}: All database connection attempts failed`
        );
        console.log(
          `Server ${SERVER_ID}: Starting without database connection`
        );
      }
    }
  }
}

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({
    status: "healthy",
    server_id: SERVER_ID,
    master_db: masterConnection ? "connected" : "disconnected",
    timestamp: new Date().toISOString(),
  });
});

// Main endpoint
app.get("/api/server-info", async (req, res) => {
  try {
    const clientIP = req.ip || req.connection.remoteAddress;
    const userAgent = req.get("User-Agent");

    // Write to database if available
    if (masterConnection) {
      try {
        await masterConnection.execute(
          "INSERT INTO requests (server_id, client_ip, user_agent) VALUES (?, ?, ?)",
          [SERVER_ID, clientIP, userAgent]
        );
      } catch (dbError) {
        console.warn(
          `Server ${SERVER_ID}: Database write failed:`,
          dbError.message
        );
      }
    }

    res.json({
      server_id: SERVER_ID,
      timestamp: new Date().toISOString(),
      message: `Request handled by Server ${SERVER_ID}`,
      client_ip: clientIP,
      database_status: masterConnection ? "connected" : "disconnected",
    });
  } catch (error) {
    console.error(`Server ${SERVER_ID}: Error:`, error);
    res.status(500).json({
      error: "Internal server error",
      server_id: SERVER_ID,
    });
  }
});

// Get statistics
app.get("/api/stats", async (req, res) => {
  try {
    if (!masterConnection) {
      return res.status(500).json({
        error: "Database not connected",
        server_id: SERVER_ID,
      });
    }

    const [rows] = await masterConnection.execute(
      "SELECT server_id, COUNT(*) as request_count FROM requests GROUP BY server_id"
    );

    res.json({
      server_id: SERVER_ID,
      statistics: rows,
      total_requests: rows.reduce((sum, row) => sum + row.request_count, 0),
    });
  } catch (error) {
    console.error(`Server ${SERVER_ID}: Error getting stats:`, error);
    res.status(500).json({
      error: "Database error",
      server_id: SERVER_ID,
    });
  }
});

// Get all requests
app.get("/api/requests", async (req, res) => {
  try {
    if (!masterConnection) {
      return res.status(500).json({
        error: "Database not connected",
        server_id: SERVER_ID,
      });
    }

    const [rows] = await masterConnection.execute(
      "SELECT * FROM requests ORDER BY timestamp DESC LIMIT 10"
    );

    res.json({
      success: true,
      data: rows,
      server_id: SERVER_ID,
    });
  } catch (error) {
    console.error(`Server ${SERVER_ID}: Error getting requests:`, error);
    res.status(500).json({
      error: "Database error",
      server_id: SERVER_ID,
    });
  }
});

// Start server
app.listen(PORT, async () => {
  console.log(`Server ${SERVER_ID} is running on port ${PORT}`);
  await connectDatabase();
});

// Graceful shutdown
process.on("SIGTERM", async () => {
  console.log(`Server ${SERVER_ID}: Shutting down gracefully`);
  if (masterConnection) {
    await masterConnection.end();
  }
  process.exit(0);
});
