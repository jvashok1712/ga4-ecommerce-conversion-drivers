-- 01. Explore the raw GA4 data: size, date range, event types, conversion signal
-- Dataset: bigquery-public-data.ga4_obfuscated_sample_ecommerce (Google Merchandise Store)

-- 1a. Users and date range  -> 270,154 users, 2020-11-01 to 2021-01-31
SELECT
  COUNT(DISTINCT user_pseudo_id) AS users,
  MIN(event_date) AS start_date,
  MAX(event_date) AS end_date
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`;

-- 1b. Which events exist (candidate behaviours)
SELECT
  event_name,
  COUNT(*) AS events,
  COUNT(DISTINCT user_pseudo_id) AS users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY event_name
ORDER BY users DESC;

-- 1c. Is there enough conversion signal?
-- -> 168,498 new users, 2,624 bought within 30 days (1.56%), 1,775 within 1 day
WITH first_visit AS (
  SELECT user_pseudo_id,
         MIN(TIMESTAMP_MICROS(event_timestamp)) AS first_ts
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name = 'first_visit'
  GROUP BY user_pseudo_id
),
first_purchase AS (
  SELECT user_pseudo_id,
         MIN(TIMESTAMP_MICROS(event_timestamp)) AS purchase_ts
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name = 'purchase'
  GROUP BY user_pseudo_id
),
cohort AS (
  -- only users who joined by Dec 31, so everyone gets a full 30-day window
  SELECT f.user_pseudo_id, f.first_ts, p.purchase_ts
  FROM first_visit f
  LEFT JOIN first_purchase p USING (user_pseudo_id)
  WHERE f.first_ts < TIMESTAMP('2021-01-01')
)
SELECT
  COUNT(*) AS new_users,
  COUNTIF(purchase_ts <= TIMESTAMP_ADD(first_ts, INTERVAL 30 DAY)) AS bought_in_30d,
  COUNTIF(purchase_ts <= TIMESTAMP_ADD(first_ts, INTERVAL 1 DAY)) AS bought_in_day1,
  ROUND(100 * COUNTIF(purchase_ts <= TIMESTAMP_ADD(first_ts, INTERVAL 30 DAY)) / COUNT(*), 2) AS conv_30d_pct
FROM cohort;
