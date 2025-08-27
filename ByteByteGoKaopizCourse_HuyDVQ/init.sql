-- Initialize database
USE loadbalancer_db;

-- Create table to track requests
CREATE TABLE IF NOT EXISTS requests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    server_id INT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    client_ip VARCHAR(45),
    user_agent TEXT
);

-- Insert some sample data
INSERT INTO requests (server_id, client_ip, user_agent) VALUES 
(1, "127.0.0.1", "Sample Request"),
(2, "127.0.0.1", "Sample Request"),
(3, "127.0.0.1", "Sample Request");
