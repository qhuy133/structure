from fastapi import FastAPI
import os
import socket
import time
from datetime import datetime

app = FastAPI(title="Load Balancer Demo API")

# Lấy thông tin server
SERVER_ID = os.getenv("SERVER_ID", "unknown")
HOSTNAME = socket.gethostname()

@app.get("/")
async def root():
    return {
        "message": "Hello from Load Balancer Demo!",
        "server_id": SERVER_ID,
        "hostname": HOSTNAME,
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "server_id": SERVER_ID,
        "hostname": HOSTNAME
    }

@app.get("/api/users")
async def get_users():
    # Giả lập data users
    users = [
        {"id": 1, "name": "John Doe", "email": "john@example.com"},
        {"id": 2, "name": "Jane Smith", "email": "jane@example.com"},
        {"id": 3, "name": "Bob Johnson", "email": "bob@example.com"}
    ]
    return {
        "users": users,
        "served_by": SERVER_ID,
        "hostname": HOSTNAME
    }

@app.get("/api/slow")
async def slow_endpoint():
    # Endpoint chậm để test load balancing
    import asyncio
    await asyncio.sleep(2)
    return {
        "message": "This is a slow endpoint",
        "served_by": SERVER_ID,
        "processing_time": "2 seconds"
    }

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port) 