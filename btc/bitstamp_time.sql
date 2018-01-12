CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
DROP TABLE IF EXISTS raw_bitstamp CASCADE;
DROP TABLE IF EXISTS time_bitstamp CASCADE;

CREATE TABLE raw_bitstamp (
  epoch  INT,
  price  REAL,
  volume REAL
);

CREATE TABLE time_bitstamp (
  dt     TIMESTAMPTZ,
  price  REAL,
  volume REAL
);

SELECT create_hypertable('time_bitstamp', 'dt');
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

COPY (
  SELECT
      time_bucket('5 minute', dt AT TIME ZONE 'UTC') AS "Date",
      first(price, dt AT TIME ZONE 'UTC') AS "Open",
      max(price) AS "High",
      min(price) AS "Low",
      last(price, dt AT TIME ZONE 'UTC') AS "Close",
      ROUND(sum(volume)) AS "Volume"
  FROM time_bitstamp
  GROUP BY 1
  ORDER BY 1 DESC
) TO '/tmp/BTCUSD.csv' WITH CSV HEADER;
