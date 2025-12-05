-- https://console.cloud.google.com/bigquery?ws=!1m4!1m3!3m2!1sgdelt-bq!2sgdeltv2
-- applying this sql query to gdelt-bq.gdeltv2.gkg table on Google BigQuery

WITH ticker_keywords AS (
  SELECT 'AAPL' AS ticker, 'aapl' AS keyword UNION ALL
  SELECT 'AAPL', 'apple' UNION ALL

  SELECT 'AMZN', 'amzn' UNION ALL
  SELECT 'AMZN', 'amazon'
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
    DATE BETWEEN 20200101000000 AND 20221231235959
    AND DocumentIdentifier IS NOT NULL
    AND NOT REGEXP_CONTAINS(
      LOWER(SourceCommonName),
      r'(instagram|tiktok|youtube|reddit|twitter|x\.com)'
    )
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
