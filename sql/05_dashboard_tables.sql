-- 05. Small summary tables that feed the Data Studio dashboard (page 1)

-- 5a. Headline numbers
CREATE OR REPLACE TABLE `aha-moment-analysis.analysis.dash_kpis` AS
SELECT
  COUNT(*)                                                    AS new_users,
  COUNTIF(converted_30d)                                      AS buyers,
  ROUND(100 * COUNTIF(converted_30d) / COUNT(*), 2)           AS conversion_pct,
  ROUND(100 * COUNTIF(s1_items_viewed = 0) / COUNT(*), 1)     AS pct_never_viewed_product,
  1057                                                        AS bots_removed
FROM `aha-moment-analysis.analysis.user_features_clean`;

-- 5b. Conversion by products viewed (the main chart)
CREATE OR REPLACE TABLE `aha-moment-analysis.analysis.dash_products_viewed` AS
SELECT
  CASE
    WHEN s1_items_viewed = 0 THEN '0'
    WHEN s1_items_viewed = 1 THEN '1'
    WHEN s1_items_viewed = 2 THEN '2'
    WHEN s1_items_viewed <= 4 THEN '3-4'
    WHEN s1_items_viewed <= 9 THEN '5-9'
    ELSE '10+'
  END                                                AS products_viewed,
  MIN(LEAST(s1_items_viewed, 10))                    AS sort_order,
  COUNT(*)                                           AS users,
  COUNTIF(converted_30d)                             AS buyers,
  ROUND(100 * COUNTIF(converted_30d) / COUNT(*), 2)  AS conversion_pct
FROM `aha-moment-analysis.analysis.user_features_clean`
GROUP BY products_viewed;

-- 5c. Behaviour lift (clean data)
CREATE OR REPLACE TABLE `aha-moment-analysis.analysis.dash_behaviour_lift` AS
WITH t AS (SELECT * FROM `aha-moment-analysis.analysis.user_features_clean`),
flags AS (
  SELECT 'Viewed a product' AS behaviour, s1_items_viewed > 0 AS did_it, converted_30d FROM t UNION ALL
  SELECT 'Clicked a product',              s1_items_clicked > 0,          converted_30d FROM t UNION ALL
  SELECT 'Used search',                    s1_searches > 0,               converted_30d FROM t UNION ALL
  SELECT 'Saw a promotion',                s1_promo_views > 0,            converted_30d FROM t UNION ALL
  SELECT 'Clicked a promotion',            s1_promo_clicks > 0,           converted_30d FROM t
)
SELECT
  behaviour,
  ROUND(100 * COUNTIF(did_it) / COUNT(*), 1) AS pct_of_new_users,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(did_it AND converted_30d), COUNTIF(did_it)), 2)         AS conv_pct_if_did,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(NOT did_it AND converted_30d), COUNTIF(NOT did_it)), 2) AS conv_pct_if_not
FROM flags
GROUP BY behaviour;

-- 5d. Weekly trend
CREATE OR REPLACE TABLE `aha-moment-analysis.analysis.dash_weekly` AS
SELECT
  first_week,
  COUNT(*)                                                 AS new_users,
  ROUND(100 * COUNTIF(converted_30d) / COUNT(*), 2)        AS conversion_pct,
  ROUND(100 * COUNTIF(s1_items_viewed > 0) / COUNT(*), 1)  AS pct_viewed_product
FROM `aha-moment-analysis.analysis.user_features_clean`
GROUP BY first_week
ORDER BY first_week;
