from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import os
import socket
import time
import pymysql
import random
from datetime import datetime
from typing import List, Dict, Any
try:
    from celery_app import celery_app, create_product_from_user, test_worker_connection
except ImportError:
    # Fallback for when celery_app is not available
    celery_app = None
    create_product_from_user = None
    test_worker_connection = None

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

        # Gửi task vào Celery queue
        if not create_product_from_user:
            raise HTTPException(status_code=503, detail="Worker system not available")
        
        task = create_product_from_user.delay(name, user_id)
        
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
            "task_id": task.id,
            "task_status": "PENDING",
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

@app.post("/api/users/{user_id}/create-product")
async def create_product_for_user(user_id: int):
    """
    Gửi message vào queue để worker tạo sản phẩm cho user
    """
    if not create_product_from_user:
        raise HTTPException(status_code=503, detail="Worker system not available")
    
    try:
        # Lấy thông tin user từ database
        query = "SELECT id, name, email FROM users WHERE id = %s"
        users, slave_host = execute_read_query(query, (user_id,))
        
        if not users:
            raise HTTPException(status_code=404, detail="User not found")
        
        user = users[0]
        user_name = user['name']
        
        # Gửi task vào Celery queue
        task = create_product_from_user.delay(user_name, user_id)
        
        # Log this request to master
        log_query = """
        INSERT INTO requests (server_id, endpoint, method, client_ip, user_agent, response_time_ms)
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        execute_write_query(log_query, (SERVER_ID, f"/api/users/{user_id}/create-product", "POST", "unknown", "API call", 50))
        
        return {
            "message": f"Product creation task queued for user {user_name}",
            "user_id": user_id,
            "user_name": user_name,
            "task_id": task.id,
            "task_status": "PENDING",
            "served_by": SERVER_ID,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to queue product creation: {str(e)}")

@app.get("/api/tasks/{task_id}")
async def get_task_status(task_id: str):
    """
    Kiểm tra trạng thái của task
    """
    if not celery_app:
        raise HTTPException(status_code=503, detail="Worker system not available")
    
    try:
        task = celery_app.AsyncResult(task_id)
        
        if task.state == 'PENDING':
            response = {
                'task_id': task_id,
                'state': task.state,
                'status': 'Task is waiting to be processed'
            }
        elif task.state == 'SUCCESS':
            response = {
                'task_id': task_id,
                'state': task.state,
                'result': task.result
            }
        elif task.state == 'FAILURE':
            response = {
                'task_id': task_id,
                'state': task.state,
                'error': str(task.info)
            }
        else:
            response = {
                'task_id': task_id,
                'state': task.state,
                'status': 'Task is being processed'
            }
        
        return response
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get task status: {str(e)}")

@app.post("/api/worker/test")
async def test_worker():
    """
    Test worker connection
    """
    if not test_worker_connection:
        raise HTTPException(status_code=503, detail="Worker system not available")
    
    try:
        # Gửi test task vào queue
        task = test_worker_connection.delay()
        
        # Log this request to master
        log_query = """
        INSERT INTO requests (server_id, endpoint, method, client_ip, user_agent, response_time_ms)
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        execute_write_query(log_query, (SERVER_ID, "/api/worker/test", "POST", "unknown", "API call", 30))
        
        return {
            "message": "Worker test task queued",
            "task_id": task.id,
            "task_status": "PENDING",
            "served_by": SERVER_ID,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to test worker: {str(e)}")

@app.get("/api/worker/status")
async def get_worker_status():
    """
    Kiểm tra trạng thái worker và Redis connection
    """
    if not celery_app:
        return {
            "worker_status": "not_available",
            "error": "Worker system not available",
            "served_by": SERVER_ID,
            "timestamp": datetime.now().isoformat()
        }
    
    try:
        # Test Redis connection
        inspect = celery_app.control.inspect()
        
        # Get active workers
        active_workers = inspect.active()
        registered_tasks = inspect.registered()
        
        # Log this request to master
        log_query = """
        INSERT INTO requests (server_id, endpoint, method, client_ip, user_agent, response_time_ms)
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        execute_write_query(log_query, (SERVER_ID, "/api/worker/status", "GET", "unknown", "API call", 40))
        
        return {
            "worker_status": "connected" if active_workers else "no_workers",
            "active_workers": active_workers,
            "registered_tasks": registered_tasks,
            "served_by": SERVER_ID,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        return {
            "worker_status": "error",
            "error": str(e),
            "served_by": SERVER_ID,
            "timestamp": datetime.now().isoformat()
        }

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port) 