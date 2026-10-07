-- 04. Driver analysis, threshold buckets, bot detection and the clean table

-- 4a. Conversion lift per first-session behaviour (run on user_features, then on user_features_clean)
WITH t AS (
  SELECT * FROM `aha-moment-analysis.analysis.user_features`
  -- Bonus variant: add  WHERE NOT s1_purchased  to see what brings non-buyers back
),
flags AS (
  SELECT 'Viewed a product'    AS behaviour, s1_items_viewed  > 0   AS did_it, converted_30d FROM t UNION ALL
  SELECT 'Clicked a product',                s1_items_clicked > 0,            converted_30d FROM t UNION ALL
  SELECT 'Used search',                      s1_searches      > 0,            converted_30d FROM t UNION ALL
  SELECT 'Saw a promotion',                  s1_promo_views   > 0,            converted_30d FROM t UNION ALL
  SELECT 'Clicked a promotion',              s1_promo_clicks  > 0,            converted_30d FROM t UNION ALL
  SELECT 'Scrolled a page',                  s1_scrolls       > 0,            converted_30d FROM t UNION ALL
  SELECT '5+ page views',                    s1_page_views   >= 5,            converted_30d FROM t UNION ALL
  SELECT 'Engaged 2+ minutes',               s1_engaged_sec  >= 120,          converted_30d FROM t
)
SELECT
  behaviour,
  COUNTIF(did_it)                                    AS users_did_it,
  ROUND(100 * COUNTIF(did_it) / COUNT(*), 1)         AS pct_of_new_users,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(did_it AND converted_30d), COUNTIF(did_it)), 2)         AS conv_pct_if_did,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(NOT did_it AND converted_30d), COUNTIF(NOT did_it)), 2) AS conv_pct_if_not,
  ROUND(SAFE_DIVIDE(
          SAFE_DIVIDE(COUNTIF(did_it AND converted_30d), COUNTIF(did_it)),
          SAFE_DIVIDE(COUNTIF(NOT did_it AND converted_30d), COUNTIF(NOT did_it))
        ), 1)                                        AS lift_x
FROM flags
GROUP BY behaviour
ORDER BY lift_x DESC;

-- 4b. Threshold: conversion by number of products viewed in session 1
SELECT
  CASE
    WHEN s1_items_viewed = 0 THEN '0'
    WHEN s1_items_viewed = 1 THEN '1'
    WHEN s1_items_viewed = 2 THEN '2'
    WHEN s1_items_viewed <= 4 THEN '3-4'
    WHEN s1_items_viewed <= 9 THEN '5-9'
    ELSE '10+'
  END                                   AS products_viewed_in_session1,
  COUNT(*)                              AS users,
  COUNTIF(converted_30d)                AS converters,
  ROUND(100 * COUNTIF(converted_30d) / COUNT(*), 2) AS conv_pct
FROM `aha-moment-analysis.analysis.user_features`
GROUP BY products_viewed_in_session1
ORDER BY MIN(s1_items_viewed);

-- 4c. Bot check: scripted pattern (50+ page views, <=1 scroll)
-- -> 1,057 users, 0 conversions, avg 113.8 page views, 52.3 items viewed, 1.0 scroll
SELECT
  COUNT(*)                         AS suspicious_users,
  COUNTIF(converted_30d)           AS converted,
  ROUND(AVG(s1_page_views), 1)     AS avg_page_views,
  ROUND(AVG(s1_items_viewed), 1)   AS avg_items_viewed,
  ROUND(AVG(s1_scrolls), 1)        AS avg_scrolls
FROM `aha-moment-analysis.analysis.user_features`
WHERE s1_page_views >= 50
  AND s1_scrolls <= 1;

-- 4d. Clean table without bots -> 167,441 rows (168,498 - 1,057)
CREATE OR REPLACE TABLE `aha-moment-analysis.analysis.user_features_clean` AS
SELECT *
FROM `aha-moment-analysis.analysis.user_features`
WHERE NOT (s1_page_views >= 50 AND s1_scrolls <= 1);
