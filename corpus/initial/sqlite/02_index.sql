CREATE TABLE users(id INTEGER PRIMARY KEY, email TEXT, active INTEGER);
CREATE INDEX idx_users_email ON users(email);
INSERT INTO users(email, active) VALUES('a@example.com', 1);
SELECT id FROM users WHERE email = 'a@example.com';
