-- 2. Funnel: how many new users reach each step within 30 days of their first visit?
CREATE OR REPLACE TABLE analysis.dash_funnel AS
WITH cohort AS (
  SELECT user_pseudo_id FROM analysis.user_features_clean
),
first_visit AS (
  SELECT user_pseudo_id, MIN(event_timestamp) AS fv_ts
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name = 'first_visit'
  GROUP BY user_pseudo_id
),
ev AS (
  SELECT e.user_pseudo_id, e.event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` AS e
  JOIN cohort USING (user_pseudo_id)
  JOIN first_visit AS f USING (user_pseudo_id)
  WHERE e.event_name IN ('view_item', 'add_to_cart', 'begin_checkout', 'add_payment_info', 'purchase')
    AND e.event_timestamp BETWEEN f.fv_ts AND f.fv_ts + 30 * 86400 * 1000000
),
steps AS (
  SELECT 1 AS step_order, 'Visited site' AS step, (SELECT COUNT(*) FROM cohort) AS users
  UNION ALL SELECT 2, 'Viewed a product',      COUNT(DISTINCT IF(event_name = 'view_item',        user_pseudo_id, NULL)) FROM ev
  UNION ALL SELECT 3, 'Added to cart',         COUNT(DISTINCT IF(event_name = 'add_to_cart',      user_pseudo_id, NULL)) FROM ev
  UNION ALL SELECT 4, 'Started checkout',      COUNT(DISTINCT IF(event_name = 'begin_checkout',   user_pseudo_id, NULL)) FROM ev
  UNION ALL SELECT 5, 'Added payment info',    COUNT(DISTINCT IF(event_name = 'add_payment_info', user_pseudo_id, NULL)) FROM ev
  UNION ALL SELECT 6, 'Purchased',             COUNT(DISTINCT IF(event_name = 'purchase',         user_pseudo_id, NULL)) FROM ev
)
SELECT
  step_order,
  step,
  users,
  ROUND(100 * users / FIRST_VALUE(users) OVER (ORDER BY step_order), 2) AS pct_of_visitors,
  ROUND(100 * users / LAG(users) OVER (ORDER BY step_order), 1) AS pct_of_previous_step
FROM steps;

SELECT * FROM analysis.dash_funnel ORDER BY step_order;
