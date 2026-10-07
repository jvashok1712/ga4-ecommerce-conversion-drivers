-- 5. Time to purchase: how many days after the first visit do buyers make their first purchase?
CREATE OR REPLACE TABLE analysis.dash_time_to_purchase AS
WITH cohort AS (
  SELECT user_pseudo_id FROM analysis.user_features_clean
),
first_visit AS (
  SELECT user_pseudo_id, MIN(event_timestamp) AS fv_ts
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name = 'first_visit'
  GROUP BY user_pseudo_id
),
first_purchase AS (
  SELECT e.user_pseudo_id, MIN(e.event_timestamp) AS p_ts
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` AS e
  JOIN cohort USING (user_pseudo_id)
  JOIN first_visit AS f USING (user_pseudo_id)
  WHERE e.event_name = 'purchase'
    AND e.event_timestamp BETWEEN f.fv_ts AND f.fv_ts + 30 * 86400 * 1000000
  GROUP BY e.user_pseudo_id
),
d AS (
  SELECT DIV(p.p_ts - f.fv_ts, 86400 * 1000000) AS days
  FROM first_purchase AS p
  JOIN first_visit AS f USING (user_pseudo_id)
)
SELECT
  CASE
    WHEN days = 0 THEN 'Same day'
    WHEN days = 1 THEN '1 day'
    WHEN days <= 3 THEN '2-3 days'
    WHEN days <= 7 THEN '4-7 days'
    WHEN days <= 14 THEN '8-14 days'
    ELSE '15-30 days'
  END AS days_to_purchase,
  MIN(days) AS sort_order,
  COUNT(*) AS buyers,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_buyers,
  ROUND(100 * SUM(COUNT(*)) OVER (ORDER BY MIN(days)) / SUM(COUNT(*)) OVER (), 1) AS cumulative_pct
FROM d
GROUP BY days_to_purchase;

SELECT * FROM analysis.dash_time_to_purchase ORDER BY sort_order;
