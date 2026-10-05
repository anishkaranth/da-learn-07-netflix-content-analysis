-- 02_cleaning.sql  Types, trimming, standardisation, repairs, DQ flags, dedupe, and the multi-value bridges.
-- Known issues in the Kaggle file (documented in dq_issues):
--   * 3 Louis C.K. specials have the runtime in `rating` and an empty `duration` -> runtime moved back, rating = NULL
--   * 88 date_added values carry a leading space; 10 are missing
--   * `country`, `listed_in`, `director` and `cast` are comma-separated multi-value lists (some with stray commas)
--   * 4 titles appear twice under different show_ids (same title, type, release year and director)

CREATE OR REPLACE TABLE cln_titles_typed AS
SELECT
  TRIM(show_id) AS show_id,
  CAST(SUBSTR(TRIM(show_id), 2) AS INT) AS show_num,
  TRIM(type) AS content_type,
  TRIM(title) AS title,
  NULLIF(TRIM(director), '') AS director,
  NULLIF(TRIM("cast"), '') AS cast_list,
  NULLIF(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(country), '^[ ,]+|[ ,]+$', ''), '\s*,\s*', ', '), '') AS country_list,
  date_added AS date_added_raw,
  to_date(TRIM(date_added), 'MMMM d, yyyy') AS date_added,
  CAST(release_year AS INT) AS release_year,
  CASE WHEN TRIM(rating) LIKE '% min' THEN NULL ELSE NULLIF(TRIM(rating), '') END AS rating_raw,
  COALESCE(NULLIF(TRIM(duration), ''), CASE WHEN TRIM(rating) LIKE '% min' THEN TRIM(rating) END) AS duration_txt,
  NULLIF(TRIM(listed_in), '') AS genre_list,
  NULLIF(TRIM(description), '') AS description,
  CASE WHEN TRIM(rating) LIKE '% min' THEN 1 ELSE 0 END AS dq_runtime_in_rating
FROM stg_titles;

CREATE OR REPLACE TABLE cln_titles_flagged AS
SELECT t.*,
  CAST(REGEXP_EXTRACT(duration_txt, '^([0-9]+)', 1) AS INT) AS duration_value,
  CASE WHEN content_type = 'Movie' THEN CAST(REGEXP_EXTRACT(duration_txt, '^([0-9]+)', 1) AS INT) END AS movie_minutes,
  CASE WHEN content_type = 'TV Show' THEN CAST(REGEXP_EXTRACT(duration_txt, '^([0-9]+)', 1) AS INT) END AS tv_seasons,
  CASE
    WHEN rating_raw IS NULL THEN 'Unknown'
    WHEN rating_raw IN ('NR', 'UR') THEN 'NR'
    ELSE rating_raw END AS rating,
  CASE
    WHEN rating_raw IN ('TV-Y', 'TV-Y7', 'TV-Y7-FV', 'TV-G', 'G') THEN '1 Kids'
    WHEN rating_raw IN ('TV-PG', 'PG') THEN '2 Older kids / family'
    WHEN rating_raw IN ('TV-14', 'PG-13') THEN '3 Teens'
    WHEN rating_raw IN ('TV-MA', 'R', 'NC-17') THEN '4 Adults'
    ELSE '5 Not rated / unknown' END AS audience,
  NULLIF(TRIM(split_part(country_list, ',', 1)), '') AS primary_country,
  CASE WHEN date_added IS NULL THEN 1 ELSE 0 END AS dq_missing_date_added,
  CASE WHEN date_added_raw <> TRIM(date_added_raw) THEN 1 ELSE 0 END AS dq_padded_date,
  CASE WHEN rating_raw IS NULL THEN 1 ELSE 0 END AS dq_missing_rating,
  CASE WHEN director IS NULL THEN 1 ELSE 0 END AS dq_missing_director,
  CASE WHEN cast_list IS NULL THEN 1 ELSE 0 END AS dq_missing_cast,
  CASE WHEN country_list IS NULL THEN 1 ELSE 0 END AS dq_missing_country,
  CASE WHEN date_added IS NOT NULL AND release_year > YEAR(date_added) THEN 1 ELSE 0 END AS dq_release_after_added,
  CASE WHEN content_type = 'Movie' AND (CAST(REGEXP_EXTRACT(duration_txt, '^([0-9]+)', 1) AS INT) < 20
                                     OR CAST(REGEXP_EXTRACT(duration_txt, '^([0-9]+)', 1) AS INT) > 240) THEN 1 ELSE 0 END AS dq_runtime_outlier,
  -- same title (case-insensitive), type, release year and director listed twice: keep the earliest add date, then lowest show number
  CASE WHEN ROW_NUMBER() OVER (PARTITION BY LOWER(title), content_type, release_year, COALESCE(director, '')
                               ORDER BY date_added NULLS LAST, show_num) > 1 THEN 1 ELSE 0 END AS dq_duplicate
FROM cln_titles_typed t;

CREATE OR REPLACE TABLE cln_titles AS
SELECT * FROM cln_titles_flagged WHERE dq_duplicate = 0;

-- multi-value bridges (one row per title x value), trimmed, empty pieces dropped, de-duplicated within a title
CREATE OR REPLACE TABLE cln_title_country AS
SELECT DISTINCT show_id, TRIM(c) AS country
FROM (SELECT show_id, explode(split(country_list, ',')) AS c FROM cln_titles) x WHERE TRIM(c) <> '';

CREATE OR REPLACE TABLE cln_title_genre AS
SELECT DISTINCT show_id, TRIM(g) AS genre
FROM (SELECT show_id, explode(split(genre_list, ',')) AS g FROM cln_titles) x WHERE TRIM(g) <> '';

CREATE OR REPLACE TABLE cln_title_director AS
SELECT DISTINCT show_id, TRIM(d) AS director_name
FROM (SELECT show_id, explode(split(director, ',')) AS d FROM cln_titles) x WHERE TRIM(d) <> '';

CREATE OR REPLACE TABLE cln_title_cast AS
SELECT DISTINCT show_id, TRIM(a) AS actor_name
FROM (SELECT show_id, explode(split(cast_list, ',')) AS a FROM cln_titles) x WHERE TRIM(a) <> '';
