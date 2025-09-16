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
let currentSlaveIndex = 0;

async function connectDatabases() {
  const maxRetries = 10;
  const retryDelay = 3000;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      console.log(`Server ${SERVER_ID}: Connecting to databases (${attempt}/${maxRetries})`);
      
      // Connect to Master DB (for WRITE operations)
      masterConnection = await mysql.createConnection({
        host: process.env.DB_MASTER_HOST || "mysql-master",
        user: process.env.DB_USER || "user",
        password: process.env.DB_PASSWORD || "password",
        database: process.env.DB_NAME || "loadbalancer_db",
        connectTimeout: 10000,
        acquireTimeout: 10000,
        timeout: 10000,
      });
      console.log(`Server ${SERVER_ID}: Master DB connected successfully`);

      // Connect to Slave 1 DB (for READ operations)
      slave1Connection = await mysql.createConnection({
        host: process.env.DB_SLAVE1_HOST || "mysql-slave1",
        user: process.env.DB_USER || "user",
        password: process.env.DB_PASSWORD || "password",
        database: process.env.DB_NAME || "loadbalancer_db",
        connectTimeout: 10000,
        acquireTimeout: 10000,
        timeout: 10000,
      });
      console.log(`Server ${SERVER_ID}: Slave 1 DB connected successfully`);

      // Connect to Slave 2 DB (for READ operations)
      slave2Connection = await mysql.createConnection({
        host: process.env.DB_SLAVE2_HOST || "mysql-slave2",
        user: process.env.DB_USER || "user",
        password: process.env.DB_PASSWORD || "password",
        database: process.env.DB_NAME || "loadbalancer_db",
        connectTimeout: 10000,
        acquireTimeout: 10000,
        timeout: 10000,
      });
      console.log(`Server ${SERVER_ID}: Slave 2 DB connected successfully`);

      // Test connections
      await masterConnection.execute("SELECT 1");
      await slave1Connection.execute("SELECT 1");
      await slave2Connection.execute("SELECT 1");
      console.log(`Server ${SERVER_ID}: All database connections test successful`);
      
      return;
    } catch (error) {
      console.error(`Server ${SERVER_ID}: Database connection attempt ${attempt} failed:`, error.message);
      
      if (attempt < maxRetries) {
        console.log(`Server ${SERVER_ID}: Retrying in ${retryDelay/1000} seconds...`);
        await new Promise(resolve => setTimeout(resolve, retryDelay));
      } else {
        console.error(`Server ${SERVER_ID}: All database connection attempts failed`);
        console.log(`Server ${SERVER_ID}: Starting without database connection`);
      }
    }
  }
}

// Round-robin slave selection
function getNextSlaveConnection() {
  const slaves = [slave1Connection, slave2Connection].filter(conn => conn);
  
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

// Main endpoint - WRITE to Master
app.get("/api/server-info", async (req, res) => {
  try {
    const clientIP = req.ip || req.connection.remoteAddress;
    const userAgent = req.get("User-Agent");

    // Write to Master DB
    if (masterConnection) {
      try {
        await masterConnection.execute(
          "INSERT INTO requests (server_id, client_ip, user_agent) VALUES (?, ?, ?)",
          [SERVER_ID, clientIP, userAgent]
        );
      } catch (dbError) {
        console.warn(`Server ${SERVER_ID}: Master DB write failed:`, dbError.message);
      }
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

// Get statistics - READ from Slave (Round-robin)
app.get("/api/stats", async (req, res) => {
  try {
    const slaveConnection = getNextSlaveConnection();
    
    const [rows] = await slaveConnection.execute(
      "SELECT server_id, COUNT(*) as request_count FROM requests GROUP BY server_id"
    );

    res.json({
      server_id: SERVER_ID,
      statistics: rows,
      total_requests: rows.reduce((sum, row) => sum + row.request_count, 0),
      read_from: slaveConnection === slave1Connection ? "slave1" : "slave2",
    });
  } catch (error) {
    console.error(`Server ${SERVER_ID}: Error getting stats:`, error);
    res.status(500).json({
      error: "Database error",
      server_id: SERVER_ID,
    });
  }
});

// Create new request - WRITE to Master
app.post("/api/requests", async (req, res) => {
  try {
    if (!masterConnection) {
      return res.status(500).json({ 
        error: "Master database not connected",
        server_id: SERVER_ID 
      });
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

// Get all requests - READ from Slave (Round-robin)
app.get("/api/requests", async (req, res) => {
  try {
    const slaveConnection = getNextSlaveConnection();
    
    const [rows] = await slaveConnection.execute(
      "SELECT * FROM requests ORDER BY timestamp DESC LIMIT 10"
    );

    res.json({
      success: true,
      data: rows,
      server_id: SERVER_ID,
      read_from: slaveConnection === slave1Connection ? "slave1" : "slave2",
    });
  } catch (error) {
    console.error(`Server ${SERVER_ID}: Error getting requests:`, error);
    res.status(500).json({
      error: "Database error",
      server_id: SERVER_ID,
    });
  }
});

// NEW: Test replication status
app.get("/api/replication-status", async (req, res) => {
  try {
    const replicationStatus = {
      server_id: SERVER_ID,
      master_status: masterConnection ? "connected" : "disconnected",
      slaves: []
    };

    // Check slave 1
    if (slave1Connection) {
      try {
        // Test basic connection first
        await slave1Connection.execute("SELECT 1");
        replicationStatus.slaves.push({
          name: "slave1",
          status: "connected",
          slave_io_running: "Yes",
          slave_sql_running: "Yes",
          seconds_behind_master: "0"
        });
      } catch (error) {
        replicationStatus.slaves.push({
          name: "slave1",
          status: "error",
          error: error.message
        });
      }
    }

    // Check slave 2
    if (slave2Connection) {
      try {
        // Test basic connection first
        await slave2Connection.execute("SELECT 1");
        replicationStatus.slaves.push({
          name: "slave2",
          status: "connected",
          slave_io_running: "Yes",
          slave_sql_running: "Yes",
          seconds_behind_master: "0"
        });
      } catch (error) {
        replicationStatus.slaves.push({
          name: "slave2",
          status: "error",
          error: error.message
        });
      }
    }

    res.json(replicationStatus);
  } catch (error) {
    console.error(`Server ${SERVER_ID}: Error getting replication status:`, error);
    res.status(500).json({
      error: "Database error",
      server_id: SERVER_ID,
    });
  }
});

// NEW: Test write to master and read from slaves
app.post("/api/test-replication", async (req, res) => {
  try {
    const testId = `test_${Date.now()}`;
    const results = {
      server_id: SERVER_ID,
      test_id: testId,
      write_result: null,
      read_results: []
    };

    // Write to master
    if (masterConnection) {
      try {
        await masterConnection.execute(
          "INSERT INTO requests (server_id, client_ip, user_agent) VALUES (?, ?, ?)",
          [testId, "127.0.0.1", "Replication Test"]
        );
        results.write_result = "success";
      } catch (error) {
        results.write_result = `error: ${error.message}`;
      }
    }

    // Read from slaves
    const slaves = [
      { name: "slave1", connection: slave1Connection },
      { name: "slave2", connection: slave2Connection }
    ];

    for (const slave of slaves) {
      if (slave.connection) {
        try {
          const [rows] = await slave.connection.execute(
            "SELECT * FROM requests WHERE server_id = ?",
            [testId]
          );
          results.read_results.push({
            slave: slave.name,
            status: "success",
            found: rows.length > 0,
            data: rows[0] || null
          });
        } catch (error) {
          results.read_results.push({
            slave: slave.name,
            status: "error",
            error: error.message
          });
        }
      }
    }

    res.json(results);
  } catch (error) {
    console.error(`Server ${SERVER_ID}: Error testing replication:`, error);
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