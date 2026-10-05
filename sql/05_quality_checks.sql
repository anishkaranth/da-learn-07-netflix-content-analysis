-- 05_quality_checks.sql  before/after counts, DQ issue counts and hard assertions

CREATE OR REPLACE TABLE dq_row_counts AS
SELECT 'titles' AS entity, (SELECT COUNT(*) FROM stg_titles) AS raw_rows, (SELECT COUNT(*) FROM cln_titles) AS clean_rows,
       (SELECT COUNT(*) FROM stg_titles) - (SELECT COUNT(*) FROM cln_titles) AS removed_rows, 'catalogue title' AS grain
UNION ALL SELECT 'fact_titles', NULL, (SELECT COUNT(*) FROM fact_titles), NULL, 'catalogue title'
UNION ALL SELECT 'dim_date', NULL, (SELECT COUNT(*) FROM dim_date), NULL, 'date added (+ -1 unknown)'
UNION ALL SELECT 'dim_rating', NULL, (SELECT COUNT(*) FROM dim_rating), NULL, 'rating'
UNION ALL SELECT 'dim_country', NULL, (SELECT COUNT(*) FROM dim_country), NULL, 'country'
UNION ALL SELECT 'dim_genre', NULL, (SELECT COUNT(*) FROM dim_genre), NULL, 'genre'
UNION ALL SELECT 'bridge_title_country', NULL, (SELECT COUNT(*) FROM bridge_title_country), NULL, 'title x country'
UNION ALL SELECT 'bridge_title_genre', NULL, (SELECT COUNT(*) FROM bridge_title_genre), NULL, 'title x genre'
UNION ALL SELECT 'bridge_title_director', NULL, (SELECT COUNT(*) FROM bridge_title_director), NULL, 'title x director'
UNION ALL SELECT 'bridge_title_cast', NULL, (SELECT COUNT(*) FROM bridge_title_cast), NULL, 'title x cast member';

-- flags overlap, so each count is "rows with this flag" (on the raw, pre-dedupe rows)
CREATE OR REPLACE TABLE dq_issues AS
SELECT 'duplicate title (same title, type, release year, director) - removed' AS check_name, (SELECT SUM(dq_duplicate) FROM cln_titles_flagged) AS affected_rows
UNION ALL SELECT 'runtime stored in rating column - moved to duration, rating set Unknown', (SELECT SUM(dq_runtime_in_rating) FROM cln_titles_flagged)
UNION ALL SELECT 'rating missing (incl. the 3 repaired) - Unknown', (SELECT SUM(dq_missing_rating) FROM cln_titles_flagged)
UNION ALL SELECT 'date_added with leading/trailing spaces - trimmed', (SELECT SUM(dq_padded_date) FROM cln_titles_flagged)
UNION ALL SELECT 'date_added missing - kept, date key -1', (SELECT SUM(dq_missing_date_added) FROM cln_titles_flagged)
UNION ALL SELECT 'date_added present but unparseable', (SELECT COUNT(*) FROM cln_titles_flagged WHERE date_added IS NULL AND date_added_raw IS NOT NULL AND date_added_raw <> '')
UNION ALL SELECT 'director missing (kept)', (SELECT SUM(dq_missing_director) FROM cln_titles_flagged)
UNION ALL SELECT 'cast missing (kept)', (SELECT SUM(dq_missing_cast) FROM cln_titles_flagged)
UNION ALL SELECT 'country missing (kept, Unknown)', (SELECT SUM(dq_missing_country) FROM cln_titles_flagged)
UNION ALL SELECT 'country list with stray leading/trailing comma - fixed', (SELECT COUNT(*) FROM stg_titles WHERE TRIM(country) LIKE '%,' OR TRIM(country) LIKE ',%')
UNION ALL SELECT 'release year later than year added (kept, flagged)', (SELECT SUM(dq_release_after_added) FROM cln_titles_flagged)
UNION ALL SELECT 'movie runtime < 20 or > 240 min (kept, flagged)', (SELECT SUM(dq_runtime_outlier) FROM cln_titles_flagged)
UNION ALL SELECT 'NR and UR merged into NR', (SELECT COUNT(*) FROM cln_titles_flagged WHERE rating_raw IN ('NR', 'UR'))
UNION ALL SELECT 'total rows removed', (SELECT COUNT(*) FROM stg_titles) - (SELECT COUNT(*) FROM cln_titles);

CREATE OR REPLACE TABLE dq_assertions AS
WITH c AS (
  SELECT 'every clean title is in fact_titles' AS check_name, (SELECT COUNT(*) FROM cln_titles) - (SELECT COUNT(*) FROM fact_titles) AS failed_rows
  UNION ALL SELECT 'show_id unique in fact', (SELECT COUNT(*) - COUNT(DISTINCT show_id) FROM fact_titles)
  UNION ALL SELECT 'no duplicate title key left', (SELECT COUNT(*) FROM (SELECT LOWER(t.title) AS k FROM fact_titles f
      JOIN cln_titles t ON t.show_id = f.show_id GROUP BY LOWER(t.title), t.content_type, t.release_year, COALESCE(t.director, '') HAVING COUNT(*) > 1) x)
  UNION ALL SELECT 'content type is Movie or TV Show', (SELECT COUNT(*) FROM fact_titles WHERE content_type NOT IN ('Movie', 'TV Show'))
  UNION ALL SELECT 'every movie has minutes, every show has seasons', (SELECT COUNT(*) FROM fact_titles
      WHERE (content_type = 'Movie' AND movie_minutes IS NULL) OR (content_type = 'TV Show' AND tv_seasons IS NULL))
  UNION ALL SELECT 'no runtime left in rating', (SELECT COUNT(*) FROM fact_titles WHERE rating LIKE '% min')
  UNION ALL SELECT 'date key exists in dim_date', (SELECT COUNT(*) FROM fact_titles f LEFT JOIN dim_date d ON d.date_key = f.date_added_key WHERE d.date_key IS NULL)
  UNION ALL SELECT 'rating exists in dim_rating', (SELECT COUNT(*) FROM fact_titles f LEFT JOIN dim_rating r ON r.rating = f.rating WHERE r.rating IS NULL)
  UNION ALL SELECT 'bridge countries exist in fact + dim', (SELECT COUNT(*) FROM bridge_title_country b LEFT JOIN fact_titles f ON f.show_id = b.show_id
      LEFT JOIN dim_country c ON c.country_key = b.country_key WHERE f.show_id IS NULL OR c.country_key IS NULL)
  UNION ALL SELECT 'bridge genres exist in fact + dim', (SELECT COUNT(*) FROM bridge_title_genre b LEFT JOIN fact_titles f ON f.show_id = b.show_id
      LEFT JOIN dim_genre g ON g.genre_key = b.genre_key WHERE f.show_id IS NULL OR g.genre_key IS NULL)
  UNION ALL SELECT 'at most one primary country per title', (SELECT COUNT(*) FROM (SELECT show_id FROM bridge_title_country GROUP BY show_id HAVING SUM(is_primary) > 1) x)
  UNION ALL SELECT 'every title with a country has a primary', (SELECT COUNT(*) FROM fact_titles WHERE primary_country <> 'Unknown'
      AND show_id NOT IN (SELECT show_id FROM bridge_title_country WHERE is_primary = 1))
  UNION ALL SELECT 'every title has at least one genre', (SELECT COUNT(*) FROM fact_titles WHERE n_genres = 0)
  UNION ALL SELECT 'yearly adds sum = titles with a date', (SELECT ABS((SELECT SUM(titles) FROM a_added_by_year) - (SELECT COUNT(*) FROM fact_titles WHERE date_added_key > 0)))
  UNION ALL SELECT 'rating mix sums to fact rows', (SELECT ABS((SELECT SUM(titles) FROM a_rating_mix) - (SELECT COUNT(*) FROM fact_titles)))
  UNION ALL SELECT 'release year in 1900..2021', (SELECT COUNT(*) FROM fact_titles WHERE release_year NOT BETWEEN 1900 AND 2021)
  UNION ALL SELECT 'no blank country / genre names', (SELECT COUNT(*) FROM dim_country WHERE TRIM(country) = '') + (SELECT COUNT(*) FROM dim_genre WHERE TRIM(genre) = '')
)
SELECT check_name, failed_rows, CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END AS status FROM c;
