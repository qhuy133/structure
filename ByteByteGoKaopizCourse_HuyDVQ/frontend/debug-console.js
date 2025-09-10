// Debug script để chạy trong browser console
// Paste code này vào browser console để debug

async function debugAPI() {
  console.log("=== Debug API Responses ===");

  try {
    // Test 1: Frontend health
    console.log("1. Testing frontend health...");
    const frontendHealth = await fetch("/health");
    console.log("Status:", frontendHealth.status);
    console.log("Content-Type:", frontendHealth.headers.get("content-type"));
    const frontendText = await frontendHealth.text();
    console.log("Response:", frontendText);

    // Test 2: Load balancer health (direct)
    console.log("2. Testing load balancer health (direct)...");
    try {
      const lbHealth = await fetch("http://localhost:8080/health");
      console.log("Status:", lbHealth.status);
      console.log("Content-Type:", lbHealth.headers.get("content-type"));
      const lbText = await lbHealth.text();
      console.log("Response:", lbText);
    } catch (error) {
      console.log("Load balancer error:", error.message);
    }

    // Test 3: API stats
    console.log("3. Testing /api/stats...");
    const statsResponse = await fetch("/api/stats");
    console.log("Status:", statsResponse.status);
    console.log("Content-Type:", statsResponse.headers.get("content-type"));
    const statsText = await statsResponse.text();
    console.log("Response:", statsText);

    // Test 4: Direct backend
    console.log("4. Testing direct backend...");
    try {
      const backendResponse = await fetch("http://localhost:3001/health");
      console.log("Status:", backendResponse.status);
      console.log("Content-Type:", backendResponse.headers.get("content-type"));
      const backendText = await backendResponse.text();
      console.log("Response:", backendText);
    } catch (error) {
      console.log("Backend error:", error.message);
    }

    // Test 5: API server-info
    console.log("5. Testing /api/server-info...");
    const serverInfoResponse = await fetch("/api/server-info");
    console.log("Status:", serverInfoResponse.status);
    console.log(
      "Content-Type:",
      serverInfoResponse.headers.get("content-type")
    );
    const serverInfoText = await serverInfoResponse.text();
    console.log("Response:", serverInfoText);
  } catch (error) {
    console.error("Debug error:", error);
  }
}

// Chạy debug
debugAPI();
