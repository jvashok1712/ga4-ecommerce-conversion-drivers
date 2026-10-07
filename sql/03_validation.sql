-- 03. Sanity check: the feature table must match the raw-event counts from 01 (1c)
-- Expected -> users 168,498 | converted_30d 2,624 | bought_in_first_session 1,314 | missing_session_data 0
SELECT
  COUNT(*)                         AS users,
  COUNTIF(converted_30d)           AS converted_30d,
  COUNTIF(s1_purchased)            AS bought_in_first_session,
  COUNTIF(s1_page_views IS NULL)   AS missing_session_data
FROM `aha-moment-analysis.analysis.user_features`;
