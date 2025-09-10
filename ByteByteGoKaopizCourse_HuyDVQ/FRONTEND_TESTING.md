# Frontend Master-Slave Testing Interface

## 🎯 Overview

Frontend đã được implement với các tính năng test toàn diện để kiểm tra MySQL Master-Slave Replication và Load Balancing.

## 🚀 Access

- **Frontend**: http://localhost
- **Load Balancer**: http://localhost:8080

## 🧪 Test Functions

### 1. **Test Write (Master)** 🟢

- **Mục đích**: Test write operations đến Master DB
- **Chức năng**:
  - Gửi request đến `/api/server-info` (write to Master)
  - Kiểm tra Master DB connection status
  - Verify data được write thành công
  - Đọc stats từ Slave để confirm replication

### 2. **Test Read (Slave)** 🔵

- **Mục đích**: Test read operations từ Slave DBs
- **Chức năng**:
  - Gửi 5 requests đến `/api/stats` (read from Slaves)
  - Kiểm tra load balancing giữa các Slaves
  - Verify data consistency
  - Hiển thị server nào handle mỗi request

### 3. **Test Replication** 🟡

- **Mục đích**: Test MySQL Master-Slave replication
- **Chức năng**:
  - Kiểm tra database connections của tất cả backends
  - Test write data và verify replication
  - Check Master DB status
  - Check Slave DB status
  - Verify data consistency

### 4. **Test Load Balancing** 🟣

- **Mục đích**: Test Round Robin load balancing
- **Chức năng**:
  - Gửi 10 requests và track distribution
  - Phân tích load distribution
  - Tính toán deviation từ expected distribution
  - Đánh giá quality của load balancing

### 5. **Run All Tests** 🔴

- **Mục đích**: Chạy complete test suite
- **Chức năng**:
  - Chạy tất cả 5 tests
  - Tổng hợp kết quả
  - Đưa ra overall assessment
  - Hiển thị test summary

## 📊 Test Results Display

### Visual Indicators

- ✅ **Success**: Test passed
- ❌ **Error**: Test failed
- ⚠️ **Warning**: Test passed with issues
- 🔄 **In Progress**: Test đang chạy

### Color Coding

- 🟢 **Green**: Write operations (Master)
- 🔵 **Blue**: Read operations (Slave)
- 🟡 **Yellow**: Replication tests
- 🟣 **Purple**: Load balancing tests
- 🔴 **Red**: Complete test suite

## 🔍 What Each Test Validates

### Write Test

- Master DB connection status
- Data write success
- Request handling by correct server
- Timestamp accuracy

### Read Test

- Slave DB connection status
- Load balancing between Slaves
- Data consistency
- Response accuracy

### Replication Test

- All backend database connections
- Master-Slave replication working
- Data propagation
- Connection health

### Load Balancing Test

- Round Robin distribution
- Server rotation
- Load distribution analysis
- Performance metrics

### Complete Test Suite

- Overall system health
- All components working
- Integration testing
- Performance assessment

## 🛠️ Technical Details

### API Endpoints Used

- `/api/server-info` - Write to Master DB
- `/api/stats` - Read from Slave DBs
- `/health/backend1` - Backend 1 health
- `/health/backend2` - Backend 2 health
- `/health/backend3` - Backend 3 health

### Database Operations

- **Write**: INSERT vào `requests` table (Master)
- **Read**: SELECT từ `requests` table (Slaves)
- **Health**: Check connection status

### Load Balancing

- **Algorithm**: Round Robin
- **Backends**: 3 servers (backend1, backend2, backend3)
- **Distribution**: Equal distribution expected

## 🎮 How to Use

1. **Open Browser**: Navigate to http://localhost
2. **Choose Test**: Click on desired test button
3. **View Results**: Results appear in "Master-Slave Test Results" section
4. **Analyze**: Review test output for any issues
5. **Repeat**: Run tests multiple times to verify consistency

## 📈 Expected Results

### Successful System

- All database connections: `connected`
- Load balancing: Even distribution (33% each server)
- Replication: Data appears in stats after write
- Health checks: All backends healthy

### Common Issues

- **Database disconnected**: Check MySQL containers
- **Load balancing uneven**: Check nginx config
- **Replication not working**: Check MySQL replication status
- **API errors**: Check backend containers

## 🔧 Troubleshooting

### If Tests Fail

1. Check Docker containers: `docker compose ps`
2. Check logs: `docker compose logs [service]`
3. Verify database connections
4. Check nginx configuration
5. Restart services if needed

### Quick Fixes

```bash
# Restart all services
docker compose restart

# Check replication
./check-replication.sh

# Test API directly
curl http://localhost/api/server-info
curl http://localhost/api/stats
```

## 🎉 Success Criteria

A working Master-Slave system should show:

- ✅ All database connections healthy
- ✅ Write operations successful
- ✅ Read operations from Slaves
- ✅ Load balancing working
- ✅ Replication functioning
- ✅ All tests passing

---

**Happy Testing!** 🚀
