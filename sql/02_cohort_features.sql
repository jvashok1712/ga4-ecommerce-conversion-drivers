-- 02. New-user cohort + first-session features: one row per new user
-- Prerequisite: dataset `analysis` created in multi-region US (same location as the public data)

CREATE OR REPLACE TABLE `aha-moment-analysis.analysis.user_features` AS
WITH events AS (
  SELECT
    user_pseudo_id,
    event_name,
    TIMESTAMP_MICROS(event_timestamp) AS ts,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'engagement_time_msec') AS engagement_ms,
    device.category AS device,
    traffic_source.medium AS medium,
    geo.country AS country
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),

-- each new user's first visit (the session they joined in)
first_visit AS (
  SELECT
    user_pseudo_id,
    ARRAY_AGG(STRUCT(ts, session_id, device, medium, country) ORDER BY ts LIMIT 1)[OFFSET(0)] AS fv
  FROM events
  WHERE event_name = 'first_visit'
  GROUP BY user_pseudo_id
),

-- keep users who joined by Dec 31, so everyone has a full 30-day window
cohort AS (
  SELECT
    user_pseudo_id,
    fv.ts AS first_ts,
    fv.session_id AS first_session_id,
    fv.device, fv.medium, fv.country
  FROM first_visit
  WHERE fv.ts < TIMESTAMP('2021-01-01')
),

-- behaviour inside the FIRST session only
s1 AS (
  SELECT
    e.user_pseudo_id,
    COUNTIF(e.event_name = 'page_view')           AS s1_page_views,
    COUNTIF(e.event_name = 'scroll')              AS s1_scrolls,
    COUNTIF(e.event_name = 'view_item')           AS s1_items_viewed,
    COUNTIF(e.event_name = 'select_item')         AS s1_items_clicked,
    COUNTIF(e.event_name = 'view_search_results') AS s1_searches,
    COUNTIF(e.event_name = 'view_promotion')      AS s1_promo_views,
    COUNTIF(e.event_name = 'select_promotion')    AS s1_promo_clicks,
    ROUND(SUM(IFNULL(e.engagement_ms, 0)) / 1000, 1) AS s1_engaged_sec,
    COUNTIF(e.event_name = 'add_to_cart') > 0     AS s1_added_to_cart,  -- reference only, NOT a predictor
    COUNTIF(e.event_name = 'purchase') > 0        AS s1_purchased
  FROM events e
  JOIN cohort c
    ON e.user_pseudo_id = c.user_pseudo_id
   AND e.session_id = c.first_session_id
  GROUP BY e.user_pseudo_id
),

first_purchase AS (
  SELECT user_pseudo_id, MIN(ts) AS purchase_ts
  FROM events
  WHERE event_name = 'purchase'
  GROUP BY user_pseudo_id
)

SELECT
  c.user_pseudo_id,
  c.first_ts,
  DATE_TRUNC(DATE(c.first_ts), WEEK) AS first_week,
  EXTRACT(DAYOFWEEK FROM c.first_ts) AS first_dow,
  c.device, c.medium, c.country,
  s1.* EXCEPT (user_pseudo_id),
  IFNULL(p.purchase_ts <= TIMESTAMP_ADD(c.first_ts, INTERVAL 30 DAY), FALSE) AS converted_30d
FROM cohort c
LEFT JOIN s1 USING (user_pseudo_id)
LEFT JOIN first_purchase p USING (user_pseudo_id);
