-- Insert sample data (only run on master)
-- This data will be replicated to slaves automatically

USE loadbalancer_db;

-- Insert sample users (using INSERT IGNORE to avoid conflicts)
INSERT IGNORE INTO users (name, email) VALUES 
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
INSERT IGNORE INTO requests (server_id, endpoint, method, client_ip, user_agent, response_time_ms) VALUES 
('server-1', '/api/', 'GET', '127.0.0.1', 'Mozilla/5.0', 150),
('server-2', '/api/users', 'GET', '127.0.0.1', 'Mozilla/5.0', 200),
('server-3', '/api/slow', 'GET', '127.0.0.1', 'Mozilla/5.0', 2000),
('server-1', '/health', 'GET', '127.0.0.1', 'Health Check', 50),
('server-2', '/api/', 'GET', '192.168.1.100', 'Chrome/91.0', 120);

-- Insert sample products
INSERT IGNORE INTO products (name, description, price, stock_quantity, category) VALUES 
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
