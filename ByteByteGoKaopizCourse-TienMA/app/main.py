from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import os
import socket
import time
import pymysql
import random
from datetime import datetime
from typing import List, Dict, Any

app = FastAPI(title="Load Balancer Demo API with MySQL")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

# Lấy thông tin server
SERVER_ID = os.getenv("SERVER_ID", "unknown")
HOSTNAME = socket.gethostname()

# Database configuration
DB_CONFIG = {
    'user': os.getenv('DB_USER', 'user'),
    'password': os.getenv('DB_PASSWORD', 'password'),
    'database': os.getenv('DB_NAME', 'loadbalancer_db'),
    'charset': 'utf8mb4'
}

# Database hosts
MASTER_HOST = os.getenv('DB_MASTER_HOST', 'mysql-master')
SLAVE_HOSTS = [
    os.getenv('DB_SLAVE1_HOST', 'mysql-slave1'),
    os.getenv('DB_SLAVE2_HOST', 'mysql-slave2')
]

def get_master_connection():
    """Get connection to master database for write operations"""
    try:
        config = DB_CONFIG.copy()
        config['host'] = MASTER_HOST
        config['port'] = 3306
        return pymysql.connect(**config)
    except Exception as e:
        print(f"Error connecting to master: {e}")
        return None

def get_slave_connection():
    """Get connection to slave database for read operations"""
    try:
        # Load balance between slaves
        slave_host = random.choice(SLAVE_HOSTS)
        config = DB_CONFIG.copy()
        config['host'] = slave_host
        config['port'] = 3306
        return pymysql.connect(**config), slave_host
    except Exception as e:
        print(f"Error connecting to slave: {e}")
        return None, None

def execute_read_query(query: str, params: tuple = None) -> List[Dict[str, Any]]:
    """Execute read query on slave database"""
    connection, slave_host = get_slave_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Could not connect to slave database")
    
    try:
        with connection.cursor(pymysql.cursors.DictCursor) as cursor:
            cursor.execute(query, params)
            result = cursor.fetchall()
            return result, slave_host
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database read error: {str(e)}")
    finally:
        connection.close()

def execute_write_query(query: str, params: tuple = None) -> int:
    """Execute write query on master database"""
    connection = get_master_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Could not connect to master database")
    
    try:
        with connection.cursor() as cursor:
            cursor.execute(query, params)
            connection.commit()
            return cursor.lastrowid or cursor.rowcount
    except Exception as e:
        connection.rollback()
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")
    finally:
        connection.close()

@app.get("/api/")
async def root():
    # Log this request to master database
    try:
        query = """
        INSERT INTO requests (server_id, endpoint, method, client_ip, user_agent, response_time_ms)
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        execute_write_query(query, (SERVER_ID, "/api/", "GET", "unknown", "API call", 100))
    except Exception as e:
        print(f"Failed to log request: {e}")

    return {
        "message": "Hello from Load Balancer Demo with MySQL!",
        "server_id": SERVER_ID,
        "hostname": HOSTNAME,
        "timestamp": datetime.now().isoformat(),
        "database_status": "Connected with Master-Slave replication"
    }

@app.get("/health")
async def health_check():
    # Test database connectivity
    db_status = "healthy"
    try:
        # Test slave connection
        connection, slave_host = get_slave_connection()
        if connection:
            connection.close()
        else:
            db_status = "slave_connection_failed"
        
        # Test master connection  
        master_conn = get_master_connection()
        if master_conn:
            master_conn.close()
        else:
            db_status = "master_connection_failed"
    except Exception as e:
        db_status = f"error: {str(e)}"

    return {
        "status": "healthy",
        "server_id": SERVER_ID,
        "hostname": HOSTNAME,
        "database_status": db_status
    }

@app.get("/api/users")
async def get_users():
    """Get users from slave database (read operation)"""
    try:
        query = "SELECT id, name, email, created_at FROM users ORDER BY created_at DESC LIMIT 20"
        users, slave_host = execute_read_query(query)
        
        # Log this request to master
        log_query = """
        INSERT INTO requests (server_id, endpoint, method, client_ip, user_agent, response_time_ms)
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        execute_write_query(log_query, (SERVER_ID, "/api/users", "GET", "unknown", "API call", 200))
        
        return {
            "users": users,
            "total_count": len(users),
            "served_by": SERVER_ID,
            "hostname": HOSTNAME,
            "read_from_slave": slave_host,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch users: {str(e)}")

@app.post("/api/users")
async def create_user(user_data: dict):
    """Create new user (write operation to master)"""
    try:
        name = user_data.get("name")
        email = user_data.get("email")
        
        if not name or not email:
            raise HTTPException(status_code=400, detail="Name and email are required")
        
        query = "INSERT INTO users (name, email) VALUES (%s, %s)"
        user_id = execute_write_query(query, (name, email))
        
        # Log this request
        log_query = """
        INSERT INTO requests (server_id, endpoint, method, client_ip, user_agent, response_time_ms)
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        execute_write_query(log_query, (SERVER_ID, "/api/users", "POST", "unknown", "API call", 150))
        
        return {
            "message": "User created successfully",
            "user_id": user_id,
            "name": name,
            "email": email,
            "served_by": SERVER_ID,
            "written_to_master": MASTER_HOST,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create user: {str(e)}")

@app.get("/api/products")
async def get_products():
    """Get products from slave database (read operation)"""
    try:
        query = """
        SELECT id, name, description, price, stock_quantity, category, created_at 
        FROM products 
        ORDER BY created_at DESC 
        LIMIT 20
        """
        products, slave_host = execute_read_query(query)
        
        # Log this request to master
        log_query = """
        INSERT INTO requests (server_id, endpoint, method, client_ip, user_agent, response_time_ms)
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        execute_write_query(log_query, (SERVER_ID, "/api/products", "GET", "unknown", "API call", 180))
        
        return {
            "products": products,
            "total_count": len(products),
            "served_by": SERVER_ID,
            "hostname": HOSTNAME,
            "read_from_slave": slave_host,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch products: {str(e)}")

@app.get("/api/requests-log")
async def get_requests_log():
    """Get recent API requests log from slave database"""
    try:
        query = """
        SELECT id, server_id, endpoint, method, timestamp, client_ip, response_time_ms
        FROM requests 
        ORDER BY timestamp DESC 
        LIMIT 50
        """
        requests_log, slave_host = execute_read_query(query)
        
        return {
            "requests": requests_log,
            "total_count": len(requests_log),
            "served_by": SERVER_ID,
            "hostname": HOSTNAME,
            "read_from_slave": slave_host,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch requests log: {str(e)}")

@app.get("/api/slow")
async def slow_endpoint():
    """Endpoint chậm để test load balancing"""
    import asyncio
    start_time = time.time()
    await asyncio.sleep(2)
    end_time = time.time()
    processing_time = int((end_time - start_time) * 1000)
    
    # Log this request to master
    try:
        log_query = """
        INSERT INTO requests (server_id, endpoint, method, client_ip, user_agent, response_time_ms)
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        execute_write_query(log_query, (SERVER_ID, "/api/slow", "GET", "unknown", "API call", processing_time))
    except Exception as e:
        print(f"Failed to log slow request: {e}")
    
    return {
        "message": "This is a slow endpoint",
        "served_by": SERVER_ID,
        "processing_time_ms": processing_time,
        "written_to_master": MASTER_HOST
    }

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port) 