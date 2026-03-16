CREATE TABLE src(
  id INTEGER PRIMARY KEY,
  value TEXT
);

CREATE TABLE log(
  msg TEXT
);

CREATE TRIGGER trg_after_insert
AFTER INSERT ON src
BEGIN
  INSERT INTO log(msg) VALUES (NEW.value);
END;

INSERT INTO src(value) VALUES('hello');
SELECT * FROM log;
