CREATE TABLE items(
  id INTEGER PRIMARY KEY,
  value TEXT UNIQUE
);

INSERT INTO items(value) VALUES('a');

INSERT INTO items(value)
VALUES('a')
ON CONFLICT(value) DO UPDATE SET value = excluded.value;

SELECT * FROM items;
