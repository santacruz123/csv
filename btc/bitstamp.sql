DROP TABLE IF EXISTS raw_bitstamp CASCADE;
DROP TABLE IF EXISTS time_bitstamp CASCADE;
DROP TABLE IF EXISTS ohlc_bitstamp CASCADE;

CREATE TABLE raw_bitstamp (
  epoch  INTEGER,
  price  REAL,
  volume REAL
);

CREATE TABLE time_bitstamp (
  dt     TIMESTAMPTZ,
  price  REAL,
  volume REAL
);

CREATE INDEX ON time_bitstamp (dt);

CREATE TABLE ohlc_bitstamp (
  date   TIMESTAMPTZ,
  open   REAL,
  high   REAL
  low    DECIMAL(12, 2),
  close  DECIMAL(12, 2),
  volume INTEGER
);

CREATE INDEX ON ohlc_bitstamp (date);

TRUNCATE raw_bitstamp;

COPY raw_bitstamp FROM '/tmp/bitstampUSD.csv' DELIMITER ',' CSV;

TRUNCATE time_bitstamp;

INSERT INTO time_bitstamp
  SELECT
    to_timestamp(epoch) "dt",
    price,
    volume
  FROM
    raw_bitstamp;

TRUNCATE ohlc_bitstamp;

INSERT INTO ohlc_bitstamp
  WITH lines AS (SELECT
                   date_trunc('hour', dt) + INTERVAL '1 minute' * floor(EXTRACT(MINUTE FROM dt) / 30) * 30 AS "date",
                   first_value(price)
                   OVER w                                                                                  AS "open",
                   MAX(price)
                   OVER w                                                                                  AS "high",
                   MIN(price)
                   OVER w                                                                                  AS "low",
                   last_value(price)
                   OVER w                                                                                  AS "close",
                   SUM(volume)
                   OVER w                                                                                  AS "volume"
                 FROM
                   time_bitstamp
                 WINDOW
                     w AS (
                     PARTITION BY date_trunc('hour', dt) +
                                  INTERVAL '1 minute' * floor(EXTRACT(MINUTE FROM dt) / 30) * 30
                     ORDER BY dt
                     ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING )
  )
  SELECT DISTINCT *
  FROM lines
  ORDER BY date;

COPY (
SELECT
  date   "Date",
  open   "Open",
  high   "High",
  low    "Low",
  close  "Close",
  volume "Volume"
FROM
  ohlc_bitstamp
) TO '/tmp/BTCUSD.csv' WITH CSV;

TRUNCATE ohlc_bitstamp,raw_bitstamp,ohlc_bitstamp;
