-- https://console.cloud.google.com/bigquery?ws=!1m4!1m3!3m2!1sgdelt-bq!2sgdeltv2
-- applying this sql query to gdelt-bq.gdeltv2.gkg table on Google BigQuery

WITH ticker_keywords AS (
  SELECT 'GME' AS ticker, 'gme' AS keyword UNION ALL
  SELECT 'GME', 'gamestop' UNION ALL

  SELECT 'AMC', 'amc' UNION ALL
  SELECT 'AMC', 'amc entertainment' UNION ALL

  SELECT 'HTZ', 'hertz' UNION ALL

  SELECT 'HOOD', 'robinhood' UNION ALL

  SELECT 'KOSS', 'koss' UNION ALL

  SELECT 'BB', 'blackberry' UNION ALL
  SELECT 'BB', 'bb' UNION ALL

  SELECT 'NOK', 'nokia' UNION ALL

  SELECT 'BBYQ', 'bed bath' UNION ALL
  SELECT 'BBYQ', 'bed bath & beyond' UNION ALL

  SELECT 'OPEN', 'opendoor' UNION ALL

  SELECT 'KSS', 'kohls' UNION ALL

  SELECT 'DNUT', 'krispy kreme' UNION ALL

  SELECT 'RKLB', 'rocket lab' UNION ALL

  SELECT 'CVNA', 'carvana' UNION ALL

  SELECT 'SOUN', 'soundhound' UNION ALL

  SELECT 'RIVN', 'rivian' UNION ALL

  SELECT 'PLTR', 'palantir'
),

base AS (
  SELECT
    PARSE_DATE('%Y%m%d', SUBSTR(CAST(DATE AS STRING), 1, 8)) AS date,
    LOWER(DocumentIdentifier) AS url,
    LOWER(SourceCommonName) AS domain,
    V2Tone
  FROM
    `gdelt-bq.gdeltv2.gkg`
  WHERE
    DATE BETWEEN 20200101000000 AND 20241231235959
    AND DocumentIdentifier IS NOT NULL
    AND NOT REGEXP_CONTAINS(LOWER(SourceCommonName),
          r'(instagram|tiktok|youtube|reddit|twitter|x\.com)')
),

matched AS (
  SELECT
    b.date,
    t.ticker,
    b.url,
    CAST(SPLIT(b.V2Tone, ',')[SAFE_OFFSET(0)] AS FLOAT64) / 100 AS tone
  FROM
    base b
  JOIN
    ticker_keywords t
  ON
    REGEXP_CONTAINS(b.url, r'(' || t.keyword || ')')
)

SELECT
  date,
  ticker,
  COUNT(*) AS NewsCount,
  AVG(tone) AS NewsTone
FROM
  matched
GROUP BY
  date, ticker
ORDER BY
  date, ticker;
