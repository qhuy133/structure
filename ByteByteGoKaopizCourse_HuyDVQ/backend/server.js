const express = require("express");
const mysql = require("mysql2/promise");
const cors = require("cors");

const app = express();
const PORT = process.env.PORT || 3000;
const SERVER_ID = process.env.SERVER_ID || "unknown";

// Middleware
app.use(cors());
app.use(express.json());

// Database connections
let masterConnection;
let slave1Connection;
let slave2Connection;
let currentSlaveIndex = 0; // For round-robin read operations

async function connectDatabases() {
  try {
    // Connect to Master DB (for WRITE operations)
    masterConnection = await mysql.createConnection({
      host: process.env.DB_MASTER_HOST || "mysql-master",
      user: process.env.DB_USER || "user",
      password: process.env.DB_PASSWORD || "password",
      database: process.env.DB_NAME || "loadbalancer_db",
    });
    console.log(`Server ${SERVER_ID}: Master DB connected successfully`);

    // Connect to Slave1 DB (for READ operations)
    slave1Connection = await mysql.createConnection({
      host: process.env.DB_SLAVE1_HOST || "mysql-slave1",
      user: process.env.DB_USER || "user",
      password: process.env.DB_PASSWORD || "password",
      database: process.env.DB_NAME || "loadbalancer_db",
    });
    console.log(`Server ${SERVER_ID}: Slave1 DB connected successfully`);

    // Connect to Slave2 DB (for READ operations)
    slave2Connection = await mysql.createConnection({
      host: process.env.DB_SLAVE2_HOST || "mysql-slave2",
      user: process.env.DB_USER || "user",
      password: process.env.DB_PASSWORD || "password",
      database: process.env.DB_NAME || "loadbalancer_db",
    });
    console.log(`Server ${SERVER_ID}: Slave2 DB connected successfully`);
  } catch (error) {
    console.error(`Server ${SERVER_ID}: Database connection failed:`, error);
  }
}

// Function to get next slave for read operations (round-robin)
function getNextSlaveConnection() {
  const slaves = [slave1Connection, slave2Connection].filter((conn) => conn);
  if (slaves.length === 0) {
    throw new Error("No slave connections available");
  }

  const selectedSlave = slaves[currentSlaveIndex % slaves.length];
  currentSlaveIndex++;
  return selectedSlave;
}

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({
    status: "healthy",
    server_id: SERVER_ID,
    master_db: masterConnection ? "connected" : "disconnected",
    slave1_db: slave1Connection ? "connected" : "disconnected",
    slave2_db: slave2Connection ? "connected" : "disconnected",
    timestamp: new Date().toISOString(),
  });
});

// Main endpoint that will be load balanced
app.get("/api/server-info", async (req, res) => {
  try {
    const clientIP = req.ip || req.connection.remoteAddress;
    const userAgent = req.get("User-Agent");

    // Write to Master DB
    if (masterConnection) {
      await masterConnection.execute(
        "INSERT INTO requests (server_id, client_ip, user_agent) VALUES (?, ?, ?)",
        [SERVER_ID, clientIP, userAgent]
      );
    }

    res.json({
      server_id: SERVER_ID,
      timestamp: new Date().toISOString(),
      message: `Request handled by Server ${SERVER_ID}`,
      client_ip: clientIP,
      master_db_status: masterConnection ? "connected" : "disconnected",
      slave1_db_status: slave1Connection ? "connected" : "disconnected",
      slave2_db_status: slave2Connection ? "connected" : "disconnected",
    });
  } catch (error) {
    console.error(`Server ${SERVER_ID}: Error:`, error);
    res.status(500).json({
      error: "Internal server error",
      server_id: SERVER_ID,
    });
  }
});

// Get request statistics (READ operation - use Slave DB)
app.get("/api/stats", async (req, res) => {
  try {
    const slaveConnection = getNextSlaveConnection();
    if (!slaveConnection) {
      return res.status(500).json({ error: "No slave database available" });
    }

    const [rows] = await slaveConnection.execute(
      "SELECT server_id, COUNT(*) as request_count FROM requests GROUP BY server_id"
    );

    res.json({
      server_id: SERVER_ID,
      statistics: rows,
      total_requests: rows.reduce((sum, row) => sum + row.request_count, 0),
      read_from: "slave",
    });
  } catch (error) {
    console.error(`Server ${SERVER_ID}: Error getting stats:`, error);
    res.status(500).json({
      error: "Internal server error",
      server_id: SERVER_ID,
    });
  }
});

// Create new request (WRITE operation - use Master DB)
app.post("/api/requests", async (req, res) => {
  try {
    if (!masterConnection) {
      return res.status(500).json({ error: "Master database not connected" });
    }

    const { client_ip, user_agent } = req.body;
    const [result] = await masterConnection.execute(
      "INSERT INTO requests (server_id, client_ip, user_agent) VALUES (?, ?, ?)",
      [SERVER_ID, client_ip || req.ip, user_agent || req.get("User-Agent")]
    );

    res.json({
      success: true,
      data: { id: result.insertId },
      server_id: SERVER_ID,
      written_to: "master",
    });
  } catch (error) {
    console.error(`Server ${SERVER_ID}: Error creating request:`, error);
    res.status(500).json({
      error: "Database error",
      server_id: SERVER_ID,
    });
  }
});

// Get all requests (READ operation - use Slave DB)
app.get("/api/requests", async (req, res) => {
  try {
    const slaveConnection = getNextSlaveConnection();
    if (!slaveConnection) {
      return res.status(500).json({ error: "No slave database available" });
    }

    const [rows] = await slaveConnection.execute(
      "SELECT * FROM requests ORDER BY timestamp DESC LIMIT 10"
    );

    res.json({
      success: true,
      data: rows,
      server_id: SERVER_ID,
      read_from: "slave",
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
  await connectDatabases();
});

// Graceful shutdown
process.on("SIGTERM", async () => {
  console.log(`Server ${SERVER_ID}: Shutting down gracefully`);
  if (masterConnection) {
    await masterConnection.end();
  }
  if (slave1Connection) {
    await slave1Connection.end();
  }
  if (slave2Connection) {
    await slave2Connection.end();
  }
  process.exit(0);
});

