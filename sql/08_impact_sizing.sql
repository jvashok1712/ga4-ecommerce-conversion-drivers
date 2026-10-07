-- 3. Business impact: what is +5 percentage points of new users viewing a product worth per month?
WITH base AS (
  SELECT user_pseudo_id,
    IF(s1_items_viewed > 0, 1, 0) AS viewed,
    CAST(converted_30d AS INT64) AS conv
  FROM analysis.user_features_clean
),
first_visit AS (
  SELECT user_pseudo_id, MIN(event_timestamp) AS fv_ts
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name = 'first_visit'
  GROUP BY user_pseudo_id
),
rev AS (
  SELECT e.user_pseudo_id, SUM(e.ecommerce.purchase_revenue_in_usd) AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` AS e
  JOIN base USING (user_pseudo_id)
  JOIN first_visit AS f USING (user_pseudo_id)
  WHERE e.event_name = 'purchase'
    AND e.event_timestamp BETWEEN f.fv_ts AND f.fv_ts + 30 * 86400 * 1000000
  GROUP BY e.user_pseudo_id
),
s AS (
  SELECT
    COUNT(*) AS users,
    COUNT(*) / 2 AS users_per_month,  -- cohort = Nov + Dec 2020 = 2 months
    AVG(viewed) AS view_rate,
    SAFE_DIVIDE(COUNTIF(viewed = 1 AND conv = 1), COUNTIF(viewed = 1)) AS conv_v,
    SAFE_DIVIDE(COUNTIF(viewed = 0 AND conv = 1), COUNTIF(viewed = 0)) AS conv_nv,
    AVG(IF(conv = 1, r.revenue, NULL)) AS rev_per_buyer
  FROM base AS b
  LEFT JOIN rev AS r USING (user_pseudo_id)
)
SELECT
  users,
  ROUND(users_per_month) AS new_users_per_month,
  ROUND(100 * view_rate, 1) AS current_view_rate_pct,
  ROUND(100 * conv_v, 2) AS conv_if_viewed_pct,
  ROUND(100 * conv_nv, 2) AS conv_if_not_pct,
  ROUND(rev_per_buyer, 2) AS revenue_per_buyer_usd,
  -- Optimistic: newly nudged viewers convert like today's viewers
  ROUND(users_per_month * 0.05 * (conv_v - conv_nv)) AS extra_buyers_month_optimistic,
  ROUND(users_per_month * 0.05 * (conv_v - conv_nv) * rev_per_buyer) AS extra_revenue_month_usd_optimistic,
  -- Conservative: they convert at today's non-viewer rate x 2.16 (the model's adjusted odds ratio)
  ROUND(users_per_month * 0.05 * conv_nv * (2.16 - 1)) AS extra_buyers_month_conservative,
  ROUND(users_per_month * 0.05 * conv_nv * (2.16 - 1) * rev_per_buyer) AS extra_revenue_month_usd_conservative
FROM s;
