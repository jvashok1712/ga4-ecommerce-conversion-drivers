-- 1. Segment deep-dive: does the "view a product" effect hold by device, traffic source and country?
CREATE OR REPLACE TABLE analysis.dash_segments AS
WITH base AS (
  SELECT *,
    CAST(converted_30d AS INT64) AS conv,
    IF(s1_items_viewed > 0, 1, 0) AS viewed
  FROM analysis.user_features_clean
),
top_countries AS (
  SELECT country FROM base GROUP BY country ORDER BY COUNT(*) DESC LIMIT 5
),
cuts AS (
  SELECT 'Device' AS cut, device AS segment, viewed, conv FROM base
  UNION ALL
  SELECT 'Traffic source', medium, viewed, conv FROM base
  UNION ALL
  SELECT 'Country',
    IF(country IN (SELECT country FROM top_countries), country, 'Other countries'),
    viewed, conv
  FROM base
)
SELECT
  cut,
  segment,
  COUNT(*) AS users,
  ROUND(100 * AVG(viewed), 1) AS pct_viewed_product,
  ROUND(100 * AVG(conv), 2) AS conversion_pct,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(viewed = 1 AND conv = 1), COUNTIF(viewed = 1)), 2) AS conv_pct_if_viewed,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(viewed = 0 AND conv = 1), COUNTIF(viewed = 0)), 2) AS conv_pct_if_not,
  ROUND(SAFE_DIVIDE(
    SAFE_DIVIDE(COUNTIF(viewed = 1 AND conv = 1), COUNTIF(viewed = 1)),
    SAFE_DIVIDE(COUNTIF(viewed = 0 AND conv = 1), COUNTIF(viewed = 0))), 1) AS lift_x
FROM cuts
GROUP BY cut, segment
HAVING COUNT(*) >= 500;

SELECT * FROM analysis.dash_segments ORDER BY cut, users DESC;
