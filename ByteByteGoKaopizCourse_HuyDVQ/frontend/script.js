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
    const response = await fetch(`http://localhost:${port}/health`);
    const data = await response.json();

    if (data.status === "healthy") {
      statusElement.textContent = "Online";
      statusElement.className = "status-online";
    } else {
      statusElement.textContent = "Unhealthy";
      statusElement.className = "status-offline";
    }
  } catch (error) {
    statusElement.textContent = "Offline";
    statusElement.className = "status-offline";
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

