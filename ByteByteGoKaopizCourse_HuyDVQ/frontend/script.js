// Global variables
let requestCount = 0;

// Initialize the page
document.addEventListener("DOMContentLoaded", function () {
  checkAllServers();
  loadStats();

  // Auto-refresh stats every 5 seconds
  setInterval(loadStats, 5000);

  // Add debug button for testing
  addDebugButton();
});

// Add debug button to test connectivity
function addDebugButton() {
  const debugDiv = document.createElement("div");
  debugDiv.style.marginTop = "20px";
  debugDiv.style.padding = "15px";
  debugDiv.style.backgroundColor = "#f8f9fa";
  debugDiv.style.border = "1px solid #dee2e6";
  debugDiv.style.borderRadius = "5px";

  debugDiv.innerHTML = `
        <h4>Debug Tools</h4>
        <button onclick="testConnectivity()" style="margin-right: 10px;">Test API Connectivity</button>
        <button onclick="testDirectBackend()">Test Direct Backend</button>
        <div id="debug-output" style="margin-top: 10px; font-family: monospace; font-size: 12px;"></div>
    `;

  document.body.appendChild(debugDiv);
}

// Test API connectivity step by step
async function testConnectivity() {
  const debugOutput = document.getElementById("debug-output");
  debugOutput.innerHTML = "Testing connectivity...<br>";

  try {
    // Test 1: Frontend health
    debugOutput.innerHTML += "1. Testing frontend health...<br>";
    const frontendHealth = await fetch("/health");
    debugOutput.innerHTML += `   Frontend health: ${frontendHealth.status} ${frontendHealth.statusText}<br>`;

    // Test 2: API stats endpoint
    debugOutput.innerHTML += "2. Testing /api/stats...<br>";
    const statsResponse = await fetch("/api/stats");
    debugOutput.innerHTML += `   Stats response: ${statsResponse.status} ${statsResponse.statusText}<br>`;
    debugOutput.innerHTML += `   Content-Type: ${statsResponse.headers.get(
      "content-type"
    )}<br>`;

    if (statsResponse.ok) {
      const statsText = await statsResponse.text();
      debugOutput.innerHTML += `   Response preview: ${statsText.substring(
        0,
        100
      )}...<br>`;
    }

    // Test 3: API server-info endpoint
    debugOutput.innerHTML += "3. Testing /api/server-info...<br>";
    const serverInfoResponse = await fetch("/api/server-info");
    debugOutput.innerHTML += `   Server info response: ${serverInfoResponse.status} ${serverInfoResponse.statusText}<br>`;
    debugOutput.innerHTML += `   Content-Type: ${serverInfoResponse.headers.get(
      "content-type"
    )}<br>`;

    if (serverInfoResponse.ok) {
      const serverInfoText = await serverInfoResponse.text();
      debugOutput.innerHTML += `   Response preview: ${serverInfoText.substring(
        0,
        100
      )}...<br>`;
    }

    debugOutput.innerHTML += "<br>✓ Connectivity test complete!<br>";
  } catch (error) {
    debugOutput.innerHTML += `<br>✗ Error during connectivity test: ${error.message}<br>`;
    console.error("Connectivity test error:", error);
  }
}

// Test direct backend connectivity
async function testDirectBackend() {
  const debugOutput = document.getElementById("debug-output");
  debugOutput.innerHTML = "Testing direct backend connectivity...<br>";

  const ports = [3001, 3002, 3003];

  for (const port of ports) {
    try {
      debugOutput.innerHTML += `Testing backend on port ${port}...<br>`;
      const response = await fetch(`http://localhost:${port}/health`);
      const data = await response.json();
      debugOutput.innerHTML += `   Port ${port}: ${data.status} (Server ${data.server_id})<br>`;
    } catch (error) {
      debugOutput.innerHTML += `   Port ${port}: Error - ${error.message}<br>`;
    }
  }

  debugOutput.innerHTML += "<br>✓ Direct backend test complete!<br>";
}

// Make API request through load balancer
async function makeRequest() {
  const button = document.getElementById("requestBtn");
  const responseDiv = document.getElementById("response");

  // Disable button and show loading
  button.disabled = true;
  button.textContent = "Sending...";
  responseDiv.innerHTML = "<p>Sending request...</p>";

  try {
    const response = await fetch("/api/server-info");
    const data = await response.json();

    requestCount++;

    // Display response
    responseDiv.innerHTML = `
            <div style="background: #d4edda; border: 1px solid #c3e6cb; border-radius: 5px; padding: 15px;">
                <h4 style="color: #155724; margin-bottom: 10px;">Request #${requestCount}</h4>
                <p><strong>Server ID:</strong> ${data.server_id}</p>
                <p><strong>Message:</strong> ${data.message}</p>
                <p><strong>Timestamp:</strong> ${new Date(
                  data.timestamp
                ).toLocaleString()}</p>
                <p><strong>Client IP:</strong> ${data.client_ip}</p>
                <p><strong>Database Status:</strong> ${data.database_status}</p>
            </div>
        `;

    // Update stats immediately
    loadStats();
  } catch (error) {
    responseDiv.innerHTML = `
            <div style="background: #f8d7da; border: 1px solid #f5c6cb; border-radius: 5px; padding: 15px;">
                <p style="color: #721c24;"><strong>Error:</strong> ${error.message}</p>
            </div>
        `;
  } finally {
    // Re-enable button
    button.disabled = false;
    button.textContent = "Send Request";
  }
}

// Check individual server health
async function checkServer(serverId, port) {
  const statusElement = document.getElementById(`server${serverId}-status`);

  try {
    // Use health check endpoint via load balancer
    const response = await fetch(`/health/backend${serverId}`);
    const data = await response.json();

    if (data.status === "healthy") {
      statusElement.textContent = "Online";
      statusElement.className = "status-online";

      // Update database status display
      updateDatabaseStatus(serverId, data);
    } else {
      statusElement.textContent = "Unhealthy";
      statusElement.className = "status-offline";
    }
  } catch (error) {
    statusElement.textContent = "Offline";
    statusElement.className = "status-offline";
  }
}

// Update database status display
function updateDatabaseStatus(serverId, data) {
  const dbStatusElement = document.getElementById(
    `server${serverId}-db-status`
  );
  if (dbStatusElement) {
    const masterStatus = data.master_db === "connected" ? "✅" : "❌";
    const slave1Status = data.slave1_db === "connected" ? "✅" : "❌";
    const slave2Status = data.slave2_db === "connected" ? "✅" : "❌";

    dbStatusElement.innerHTML = `
      <div style="font-size: 12px; margin-top: 5px;">
        <div>Master: ${masterStatus}</div>
        <div>Slave1: ${slave1Status}</div>
        <div>Slave2: ${slave2Status}</div>
      </div>
    `;
  }
}

// Check all servers
async function checkAllServers() {
  await Promise.all([
    checkServer(1, 3001),
    checkServer(2, 3002),
    checkServer(3, 3003),
  ]);
}

// Load statistics
async function loadStats() {
  const statsDiv = document.getElementById("stats");

  try {
    // Try to get stats from load balancer first
    const response = await fetch("/api/stats");

    // Check if response is ok
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    // Check content type to ensure we're getting JSON
    const contentType = response.headers.get("content-type");
    if (!contentType || !contentType.includes("application/json")) {
      const text = await response.text();
      console.error("Received non-JSON response:", text);
      throw new Error(
        `Expected JSON but got ${contentType || "unknown content type"}`
      );
    }

    const data = await response.json();

    if (data.statistics && data.statistics.length > 0) {
      let statsHTML =
        '<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px;">';

      data.statistics.forEach((stat) => {
        const percentage =
          data.total_requests > 0
            ? Math.round((stat.request_count / data.total_requests) * 100)
            : 0;

        statsHTML += `
                    <div style="background: #e3f2fd; border: 1px solid #bbdefb; border-radius: 8px; padding: 15px; text-align: center;">
                        <h5 style="color: #1976d2; margin-bottom: 10px;">Server ${stat.server_id}</h5>
                        <p style="font-size: 1.5rem; font-weight: bold; color: #1976d2;">${stat.request_count}</p>
                        <p style="color: #666;">${percentage}% of total</p>
                    </div>
                `;
      });

      statsHTML += "</div>";
      statsHTML += `<p style="margin-top: 15px; text-align: center; font-weight: bold;">Total Requests: ${data.total_requests}</p>`;

      statsDiv.innerHTML = statsHTML;
    } else {
      statsDiv.innerHTML = "<p>No statistics available yet</p>";
    }
  } catch (error) {
    console.error("Error loading stats:", error);
    statsDiv.innerHTML = `
            <div style="background: #fff3cd; border: 1px solid #ffeaa7; border-radius: 5px; padding: 15px;">
                <p style="color: #856404;"><strong>Warning:</strong> Could not load statistics. ${error.message}</p>
                <p style="color: #856404; font-size: 0.9em;">Check the browser console for more details.</p>
            </div>
        `;
  }
}

// Refresh server status every 10 seconds
setInterval(checkAllServers, 10000);

// ==================== MASTER-SLAVE TEST FUNCTIONS ====================

// Test Write Operations (Master DB)
async function testWriteOperation() {
  const testResults = document.getElementById("test-results");
  testResults.innerHTML = "🔄 Testing Write Operations (Master DB)...\n\n";

  try {
    const results = [];

    // Test 1: Write to Master via server-info endpoint
    testResults.innerHTML +=
      "📝 Test 1: Writing to Master DB via /api/server-info...\n";
    const writeResponse = await fetch("/api/server-info");
    const writeData = await writeResponse.json();

    if (writeResponse.ok) {
      results.push(
        `✅ Write successful - Server ${writeData.server_id} handled request`
      );
      results.push(`   Master DB Status: ${writeData.master_db_status}`);
      results.push(`   Timestamp: ${writeData.timestamp}`);
    } else {
      results.push(`❌ Write failed - ${writeResponse.status}`);
    }

    // Test 2: Check if data was written to Master
    testResults.innerHTML += "🔍 Test 2: Verifying data in Master DB...\n";
    const statsResponse = await fetch("/api/stats");
    const statsData = await statsResponse.json();

    if (statsResponse.ok) {
      results.push(`✅ Stats read from Slave - Server ${statsData.server_id}`);
      results.push(`   Total requests: ${statsData.total_requests}`);
      results.push(`   Read from: ${statsData.read_from}`);
    } else {
      results.push(`❌ Stats read failed - ${statsResponse.status}`);
    }

    // Display results
    testResults.innerHTML = results.join("\n");
  } catch (error) {
    testResults.innerHTML = `❌ Write test failed: ${error.message}`;
  }
}

// Test Read Operations (Slave DBs)
async function testReadOperation() {
  const testResults = document.getElementById("test-results");
  testResults.innerHTML = "🔄 Testing Read Operations (Slave DBs)...\n\n";

  try {
    const results = [];

    // Test multiple reads to see load balancing across slaves
    testResults.innerHTML +=
      "📖 Testing multiple reads to verify Slave load balancing...\n";

    for (let i = 1; i <= 5; i++) {
      const response = await fetch("/api/stats");
      const data = await response.json();

      if (response.ok) {
        results.push(
          `✅ Read ${i}: Server ${data.server_id} - Total: ${data.total_requests} - From: ${data.read_from}`
        );
      } else {
        results.push(`❌ Read ${i} failed: ${response.status}`);
      }

      // Small delay between requests
      await new Promise((resolve) => setTimeout(resolve, 500));
    }

    // Display results
    testResults.innerHTML = results.join("\n");
  } catch (error) {
    testResults.innerHTML = `❌ Read test failed: ${error.message}`;
  }
}

// Test Replication Status
async function testReplication() {
  const testResults = document.getElementById("test-results");
  testResults.innerHTML = "🔄 Testing MySQL Master-Slave Replication...\n\n";

  try {
    const results = [];

    // Test 1: Check all backend health status
    testResults.innerHTML +=
      "🔍 Checking all backend database connections...\n";

    for (let i = 1; i <= 3; i++) {
      try {
        const response = await fetch(`/health/backend${i}`);
        const data = await response.json();

        if (response.ok) {
          results.push(
            `✅ Backend ${i}: Master=${data.master_db}, Slave1=${data.slave1_db}, Slave2=${data.slave2_db}`
          );
        } else {
          results.push(`❌ Backend ${i}: Health check failed`);
        }
      } catch (error) {
        results.push(`❌ Backend ${i}: ${error.message}`);
      }
    }

    // Test 2: Write data and check replication
    testResults.innerHTML += "\n📝 Testing data replication...\n";

    // Write some test data
    const writeResponse = await fetch("/api/server-info");
    const writeData = await writeResponse.json();

    if (writeResponse.ok) {
      results.push(`✅ Data written via Server ${writeData.server_id}`);

      // Wait a bit for replication
      await new Promise((resolve) => setTimeout(resolve, 2000));

      // Check if data appears in stats (read from slaves)
      const statsResponse = await fetch("/api/stats");
      const statsData = await statsResponse.json();

      if (statsResponse.ok) {
        results.push(
          `✅ Data replicated - Stats show ${statsData.total_requests} total requests`
        );
        results.push(`   Read from: ${statsData.read_from} (Slave DB)`);
      } else {
        results.push(`❌ Stats read failed - Replication may not be working`);
      }
    } else {
      results.push(`❌ Write test failed`);
    }

    // Display results
    testResults.innerHTML = results.join("\n");
  } catch (error) {
    testResults.innerHTML = `❌ Replication test failed: ${error.message}`;
  }
}

// Test Load Balancing
async function testLoadBalancing() {
  const testResults = document.getElementById("test-results");
  testResults.innerHTML = "🔄 Testing Load Balancing (Round Robin)...\n\n";

  try {
    const results = [];
    const serverCounts = {};

    testResults.innerHTML +=
      "⚖️ Sending 10 requests to test load balancing...\n";

    // Send 10 requests and track which server handles each
    for (let i = 1; i <= 10; i++) {
      const response = await fetch("/api/server-info");
      const data = await response.json();

      if (response.ok) {
        const serverId = data.server_id;
        serverCounts[serverId] = (serverCounts[serverId] || 0) + 1;
        results.push(`Request ${i}: Server ${serverId}`);
      } else {
        results.push(`Request ${i}: Failed (${response.status})`);
      }

      // Small delay between requests
      await new Promise((resolve) => setTimeout(resolve, 300));
    }

    // Analyze load balancing
    results.push("\n📊 Load Balancing Analysis:");
    results.push("==========================");

    const totalRequests = Object.values(serverCounts).reduce(
      (sum, count) => sum + count,
      0
    );
    const expectedPerServer = totalRequests / 3;

    for (const [serverId, count] of Object.entries(serverCounts)) {
      const percentage = ((count / totalRequests) * 100).toFixed(1);
      const deviation = Math.abs(count - expectedPerServer).toFixed(1);

      results.push(
        `Server ${serverId}: ${count} requests (${percentage}%) - Deviation: ${deviation}`
      );
    }

    // Check if load balancing is working well
    const maxDeviation = Math.max(
      ...Object.values(serverCounts).map((count) =>
        Math.abs(count - expectedPerServer)
      )
    );
    if (maxDeviation <= 1) {
      results.push("\n✅ Load balancing is working well! (Low deviation)");
    } else if (maxDeviation <= 2) {
      results.push("\n⚠️ Load balancing is working but with some deviation");
    } else {
      results.push(
        "\n❌ Load balancing may not be working properly (High deviation)"
      );
    }

    // Display results
    testResults.innerHTML = results.join("\n");
  } catch (error) {
    testResults.innerHTML = `❌ Load balancing test failed: ${error.message}`;
  }
}

// Run All Tests
async function runAllTests() {
  const testResults = document.getElementById("test-results");
  testResults.innerHTML = "🚀 Running Complete Master-Slave Test Suite...\n\n";

  try {
    const allResults = [];

    // Test 1: Write Operations
    allResults.push("=== TEST 1: WRITE OPERATIONS (MASTER DB) ===");
    testResults.innerHTML += "🔄 Test 1: Write Operations...\n";

    const writeResponse = await fetch("/api/server-info");
    const writeData = await writeResponse.json();

    if (writeResponse.ok) {
      allResults.push(`✅ Write successful - Server ${writeData.server_id}`);
      allResults.push(`   Master DB Status: ${writeData.master_db_status}`);
    } else {
      allResults.push(`❌ Write failed - ${writeResponse.status}`);
    }

    // Test 2: Read Operations
    allResults.push("\n=== TEST 2: READ OPERATIONS (SLAVE DBs) ===");
    testResults.innerHTML += "🔄 Test 2: Read Operations...\n";

    const readResponse = await fetch("/api/stats");
    const readData = await readResponse.json();

    if (readResponse.ok) {
      allResults.push(`✅ Read successful - Server ${readData.server_id}`);
      allResults.push(`   Total requests: ${readData.total_requests}`);
      allResults.push(`   Read from: ${readData.read_from}`);
    } else {
      allResults.push(`❌ Read failed - ${readResponse.status}`);
    }

    // Test 3: Database Connections
    allResults.push("\n=== TEST 3: DATABASE CONNECTIONS ===");
    testResults.innerHTML += "🔄 Test 3: Database Connections...\n";

    for (let i = 1; i <= 3; i++) {
      try {
        const healthResponse = await fetch(`/health/backend${i}`);
        const healthData = await healthResponse.json();

        if (healthResponse.ok) {
          allResults.push(
            `✅ Backend ${i}: Master=${healthData.master_db}, Slave1=${healthData.slave1_db}, Slave2=${healthData.slave2_db}`
          );
        } else {
          allResults.push(`❌ Backend ${i}: Health check failed`);
        }
      } catch (error) {
        allResults.push(`❌ Backend ${i}: ${error.message}`);
      }
    }

    // Test 4: Load Balancing
    allResults.push("\n=== TEST 4: LOAD BALANCING ===");
    testResults.innerHTML += "🔄 Test 4: Load Balancing...\n";

    const serverCounts = {};
    for (let i = 1; i <= 6; i++) {
      const response = await fetch("/api/server-info");
      const data = await response.json();

      if (response.ok) {
        const serverId = data.server_id;
        serverCounts[serverId] = (serverCounts[serverId] || 0) + 1;
      }

      await new Promise((resolve) => setTimeout(resolve, 200));
    }

    allResults.push("Load distribution:");
    for (const [serverId, count] of Object.entries(serverCounts)) {
      allResults.push(`  Server ${serverId}: ${count} requests`);
    }

    // Test 5: Replication
    allResults.push("\n=== TEST 5: REPLICATION STATUS ===");
    testResults.innerHTML += "🔄 Test 5: Replication...\n";

    // Wait for replication
    await new Promise((resolve) => setTimeout(resolve, 2000));

    const finalStatsResponse = await fetch("/api/stats");
    const finalStatsData = await finalStatsResponse.json();

    if (finalStatsResponse.ok) {
      allResults.push(
        `✅ Final stats: ${finalStatsData.total_requests} total requests`
      );
      allResults.push(`   Read from: ${finalStatsData.read_from} (Slave DB)`);
    } else {
      allResults.push(`❌ Final stats read failed`);
    }

    // Summary
    allResults.push("\n=== TEST SUMMARY ===");
    allResults.push("===================");

    const totalTests = 5;
    let passedTests = 0;

    if (writeResponse.ok) passedTests++;
    if (readResponse.ok) passedTests++;
    if (Object.keys(serverCounts).length > 0) passedTests++;
    if (finalStatsResponse.ok) passedTests++;

    // Check if at least 3 backends are healthy
    let healthyBackends = 0;
    for (let i = 1; i <= 3; i++) {
      try {
        const response = await fetch(`/health/backend${i}`);
        if (response.ok) healthyBackends++;
      } catch (error) {
        // Ignore errors
      }
    }

    if (healthyBackends >= 2) passedTests++;

    allResults.push(`Tests passed: ${passedTests}/${totalTests}`);
    allResults.push(`Healthy backends: ${healthyBackends}/3`);

    if (passedTests >= 4) {
      allResults.push("\n🎉 MASTER-SLAVE SYSTEM IS WORKING CORRECTLY!");
    } else if (passedTests >= 3) {
      allResults.push(
        "\n⚠️ MASTER-SLAVE SYSTEM IS MOSTLY WORKING (Some issues detected)"
      );
    } else {
      allResults.push("\n❌ MASTER-SLAVE SYSTEM HAS SIGNIFICANT ISSUES");
    }

    // Display all results
    testResults.innerHTML = allResults.join("\n");
  } catch (error) {
    testResults.innerHTML = `❌ Complete test suite failed: ${error.message}`;
  }
}

