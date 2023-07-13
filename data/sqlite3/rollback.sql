SAVEPOINT major;

INSERT INTO movie (name,year) VALUES('The Matrix Reloaded', 2003);
SELECT * FROM movie WHERE year=2003 ORDER BY mid;

ROLLBACK TO SAVEPOINT major;
SELECT * FROM movie WHERE year=2003 ORDER BY mid;

RELEASE SAVEPOINT major;
