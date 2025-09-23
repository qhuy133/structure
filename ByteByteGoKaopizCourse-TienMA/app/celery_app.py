from celery import Celery
import os
import pymysql
import random
from datetime import datetime

# Redis configuration
REDIS_HOST = os.getenv('REDIS_HOST', 'redis')
REDIS_PORT = os.getenv('REDIS_PORT', '6379')
REDIS_DB = os.getenv('REDIS_DB', '0')

# Database configuration
DB_CONFIG = {
    'user': os.getenv('DB_USER', 'user'),
    'password': os.getenv('DB_PASSWORD', 'password'),
    'database': os.getenv('DB_NAME', 'loadbalancer_db'),
    'charset': 'utf8mb4'
}

# Database hosts
MASTER_HOST = os.getenv('DB_MASTER_HOST', 'mysql-master')

# Create Celery instance
celery_app = Celery(
    'worker',
    broker=f'redis://{REDIS_HOST}:{REDIS_PORT}/{REDIS_DB}',
    backend=f'redis://{REDIS_HOST}:{REDIS_PORT}/{REDIS_DB}',
    include=['celery_app']
)

# Celery configuration
celery_app.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
    task_track_started=True,
    task_time_limit=30 * 60,  # 30 minutes
    task_soft_time_limit=25 * 60,  # 25 minutes
    worker_prefetch_multiplier=1,
    worker_max_tasks_per_child=1000,
)

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

def execute_write_query(query: str, params: tuple = None) -> int:
    """Execute write query on master database"""
    connection = get_master_connection()
    if not connection:
        raise Exception("Could not connect to master database")
    
    try:
        with connection.cursor() as cursor:
            cursor.execute(query, params)
            connection.commit()
            return cursor.lastrowid or cursor.rowcount
    except Exception as e:
        connection.rollback()
        raise Exception(f"Database write error: {str(e)}")
    finally:
        connection.close()

@celery_app.task(bind=True)
def create_product_from_user(self, user_name: str, user_id: int):
    """
    Worker task để tạo sản phẩm dựa trên tên user
    """
    try:
        # Tạo tên sản phẩm dựa trên tên user
        product_name = f"Product for {user_name}"
        
        # Tạo mô tả sản phẩm
        product_description = f"Custom product created for user {user_name} at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
        
        # Giá ngẫu nhiên từ 10.00 đến 1000.00
        price = round(random.uniform(10.0, 1000.0), 2)
        
        # Số lượng tồn kho ngẫu nhiên từ 1 đến 100
        stock_quantity = random.randint(1, 100)
        
        # Danh mục ngẫu nhiên
        categories = ['Electronics', 'Clothing', 'Books', 'Home & Garden', 'Sports', 'Toys']
        category = random.choice(categories)
        
        # Insert sản phẩm vào database
        query = """
        INSERT INTO products (name, description, price, stock_quantity, category)
        VALUES (%s, %s, %s, %s, %s)
        """
        product_id = execute_write_query(query, (
            product_name,
            product_description,
            price,
            stock_quantity,
            category
        ))
        
        # Log task completion
        log_query = """
        INSERT INTO requests (server_id, endpoint, method, client_ip, user_agent, response_time_ms)
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        execute_write_query(log_query, (
            "celery-worker",
            f"/worker/create-product/{user_id}",
            "TASK",
            "worker",
            f"Celery Task: {self.request.id}",
            0
        ))
        
        return {
            "status": "success",
            "message": f"Product created successfully for user {user_name}",
            "product_id": product_id,
            "product_name": product_name,
            "price": price,
            "stock_quantity": stock_quantity,
            "category": category,
            "task_id": self.request.id,
            "created_at": datetime.now().isoformat()
        }
        
    except Exception as e:
        # Log error
        try:
            log_query = """
            INSERT INTO requests (server_id, endpoint, method, client_ip, user_agent, response_time_ms)
            VALUES (%s, %s, %s, %s, %s, %s)
            """
            execute_write_query(log_query, (
                "celery-worker",
                f"/worker/create-product/{user_id}",
                "TASK_ERROR",
                "worker",
                f"Celery Task Error: {self.request.id} - {str(e)}",
                0
            ))
        except:
            pass
            
        raise self.retry(exc=e, countdown=60, max_retries=3)

@celery_app.task
def test_worker_connection():
    """Test task để kiểm tra worker hoạt động"""
    return {
        "status": "success",
        "message": "Worker is running",
        "timestamp": datetime.now().isoformat()
    }

if __name__ == '__main__':
    celery_app.start()
