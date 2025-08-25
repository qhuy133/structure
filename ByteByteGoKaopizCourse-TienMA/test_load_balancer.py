import requests
import time
import asyncio
import aiohttp
from collections import Counter
import concurrent.futures

def test_basic_load_balancing():
    """Test cơ bản để kiểm tra load balancing"""
    print("=== Testing Basic Load Balancing ===")
    
    servers_hit = []
    
    for i in range(15):
        try:
            response = requests.get("http://localhost/", timeout=5)
            if response.status_code == 200:
                data = response.json()
                server_id = data.get("server_id", "unknown")
                servers_hit.append(server_id)
                print(f"Request {i+1}: {server_id}")
            time.sleep(0.1)
        except Exception as e:
            print(f"Request {i+1} failed: {e}")
    
    # Thống kê phân phối requests
    counter = Counter(servers_hit)
    print(f"\nDistribution: {dict(counter)}")
    
    return counter

def test_concurrent_requests():
    """Test với nhiều requests đồng thời"""
    print("\n=== Testing Concurrent Requests ===")
    
    def make_request():
        try:
            response = requests.get("http://localhost/api/users", timeout=10)
            if response.status_code == 200:
                return response.json().get("served_by", "unknown")
        except:
            return "failed"
    
    # Gửi 50 requests đồng thời
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(make_request) for _ in range(50)]
        results = [future.result() for future in concurrent.futures.as_completed(futures)]
    
    counter = Counter(results)
    print(f"Concurrent requests distribution: {dict(counter)}")
    
    return counter

def test_server_failure_simulation():
    """Test khi một server fail"""
    print("\n=== Testing Server Failure Handling ===")
    print("Manually stop one container with: docker compose stop fastapi_server_1")
    print("Then run this test again to see failover behavior")
    
    test_basic_load_balancing()

def test_health_checks():
    """Test health check endpoints"""
    print("\n=== Testing Health Checks ===")
    
    try:
        # Test Nginx health
        response = requests.get("http://localhost/nginx-health")
        print(f"Nginx health: {response.status_code} - {response.text.strip()}")
        
        # Test application health
        response = requests.get("http://localhost/health")
        if response.status_code == 200:
            data = response.json()
            print(f"App health: {data}")
    except Exception as e:
        print(f"Health check failed: {e}")

def test_performance():
    """Test hiệu suất của load balancer"""
    print("\n=== Testing Performance ===")
    
    start_time = time.time()
    success_count = 0
    
    def make_fast_request():
        try:
            response = requests.get("http://localhost/api/users", timeout=5)
            return response.status_code == 200
        except:
            return False
    
    # Test 100 requests đồng thời
    with concurrent.futures.ThreadPoolExecutor(max_workers=20) as executor:
        futures = [executor.submit(make_fast_request) for _ in range(100)]
        results = [future.result() for future in concurrent.futures.as_completed(futures)]
        success_count = sum(results)
    
    end_time = time.time()
    duration = end_time - start_time
    
    print(f"Processed 100 requests in {duration:.2f} seconds")
    print(f"Success rate: {success_count}/100 ({success_count}%)")
    print(f"Requests per second: {100/duration:.2f}")

if __name__ == "__main__":
    print("Load Balancer Testing Script")
    print("=" * 40)
    
    # Chờ hệ thống khởi động
    print("Waiting for services to start...")
    time.sleep(5)
    
    test_health_checks()
    test_basic_load_balancing()
    test_concurrent_requests()
    test_performance()
    test_server_failure_simulation() 