ALTER TABLE movie ADD COLUMN mtime date;

CREATE TRIGGER movie_update_trg AFTER UPDATE ON movie
BEGIN
UPDATE movie SET mtime = datetime('NOW') WHERE rowid = new.rowid;
END;

CREATE VIEW cinema AS SELECT m.name, m.year, GROUP_CONCAT(d.name, '+')
AS directors
FROM movie m JOIN director_movie dm
ON m.mid=dm.mid JOIN director d ON dm.did=d.did GROUP by m.mid;

