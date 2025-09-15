-- Initialize database
USE loadbalancer_db;

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create requests table to track API requests
CREATE TABLE IF NOT EXISTS requests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    server_id VARCHAR(50) NOT NULL,
    endpoint VARCHAR(255) NOT NULL,
    method VARCHAR(10) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    client_ip VARCHAR(45),
    user_agent TEXT,
    response_time_ms INT
);

-- Insert sample users
INSERT INTO users (name, email) VALUES 
('John Doe', 'john.doe@example.com'),
('Jane Smith', 'jane.smith@example.com'),
('Bob Johnson', 'bob.johnson@example.com'),
('Alice Brown', 'alice.brown@example.com'),
('Charlie Wilson', 'charlie.wilson@example.com'),
('Diana Prince', 'diana.prince@example.com'),
('Edward Clark', 'edward.clark@example.com'),
('Fiona Green', 'fiona.green@example.com'),
('George Davis', 'george.davis@example.com'),
('Helen White', 'helen.white@example.com');

-- Insert sample request data
INSERT INTO requests (server_id, endpoint, method, client_ip, user_agent, response_time_ms) VALUES 
('server-1', '/api/', 'GET', '127.0.0.1', 'Mozilla/5.0', 150),
('server-2', '/api/users', 'GET', '127.0.0.1', 'Mozilla/5.0', 200),
('server-3', '/api/slow', 'GET', '127.0.0.1', 'Mozilla/5.0', 2000),
('server-1', '/health', 'GET', '127.0.0.1', 'Health Check', 50),
('server-2', '/api/', 'GET', '192.168.1.100', 'Chrome/91.0', 120);

-- Create products table for demo purposes
CREATE TABLE IF NOT EXISTS products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INT DEFAULT 0,
    category VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Insert sample products
INSERT INTO products (name, description, price, stock_quantity, category) VALUES 
('Laptop HP', 'High performance laptop for business', 15000000.00, 10, 'Electronics'),
('iPhone 14', 'Latest Apple smartphone', 25000000.00, 5, 'Electronics'),
('Samsung Galaxy S23', 'Android flagship phone', 20000000.00, 8, 'Electronics'),
('MacBook Pro', 'Professional laptop for developers', 35000000.00, 3, 'Electronics'),
('Dell Monitor 24"', 'Full HD monitor for office work', 5000000.00, 15, 'Electronics'),
('Wireless Mouse', 'Ergonomic wireless mouse', 500000.00, 50, 'Accessories'),
('Mechanical Keyboard', 'RGB mechanical gaming keyboard', 2000000.00, 20, 'Accessories'),
('Headphones Sony', 'Noise cancelling headphones', 3000000.00, 12, 'Audio'),
('Bluetooth Speaker', 'Portable wireless speaker', 1500000.00, 25, 'Audio'),
('Tablet iPad', 'Apple iPad for creative work', 18000000.00, 7, 'Electronics');
