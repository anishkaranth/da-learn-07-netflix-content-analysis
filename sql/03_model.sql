-- 03_model.sql  star schema: fact_titles (one row per catalogue title) + dim_date (date added), dim_rating,
-- dim_country / dim_genre with many-to-many bridges, and person bridges for directors and cast.

CREATE OR REPLACE TABLE dim_date AS
SELECT DISTINCT
  YEAR(date_added) * 10000 + MONTH(date_added) * 100 + DAY(date_added) AS date_key, date_added AS full_date,
  YEAR(date_added) AS year, MONTH(date_added) AS month,
  CASE MONTH(date_added) WHEN 1 THEN '01 Jan' WHEN 2 THEN '02 Feb' WHEN 3 THEN '03 Mar' WHEN 4 THEN '04 Apr' WHEN 5 THEN '05 May'
       WHEN 6 THEN '06 Jun' WHEN 7 THEN '07 Jul' WHEN 8 THEN '08 Aug' WHEN 9 THEN '09 Sep' WHEN 10 THEN '10 Oct'
       WHEN 11 THEN '11 Nov' ELSE '12 Dec' END AS month_label,
  CAST(FLOOR((MONTH(date_added) - 1) / 3) AS INT) + 1 AS quarter,
  DAY(date_added) AS day_of_month,
  CASE WHEN DAY(date_added) = 1 THEN 1 ELSE 0 END AS is_first_of_month
FROM cln_titles WHERE date_added IS NOT NULL
UNION ALL
SELECT -1, NULL, NULL, NULL, 'Unknown', NULL, NULL, 0;

CREATE OR REPLACE TABLE dim_rating AS
SELECT rating, audience,
  CASE WHEN rating LIKE 'TV-%' THEN 'TV guideline' WHEN rating IN ('G', 'PG', 'PG-13', 'R', 'NC-17') THEN 'MPA film rating' ELSE 'Not rated' END AS rating_system
FROM (SELECT DISTINCT rating, audience FROM cln_titles) r;

CREATE OR REPLACE TABLE dim_country AS
SELECT ROW_NUMBER() OVER (ORDER BY country) AS country_key, country FROM (SELECT DISTINCT country FROM cln_title_country) c;

-- genre_family is data-driven: a genre is a 'TV genre' when most of its titles are TV shows
CREATE OR REPLACE TABLE dim_genre AS
SELECT ROW_NUMBER() OVER (ORDER BY g.genre) AS genre_key, g.genre,
  CASE WHEN AVG(CASE WHEN t.content_type = 'TV Show' THEN 1.0 ELSE 0.0 END) > 0.5 THEN 'TV genre' ELSE 'Movie genre' END AS genre_family
FROM cln_title_genre g JOIN cln_titles t ON t.show_id = g.show_id
GROUP BY g.genre;

CREATE OR REPLACE TABLE bridge_title_country AS
SELECT b.show_id, c.country_key, CASE WHEN b.country = t.primary_country THEN 1 ELSE 0 END AS is_primary
FROM cln_title_country b JOIN dim_country c ON c.country = b.country JOIN cln_titles t ON t.show_id = b.show_id;

CREATE OR REPLACE TABLE bridge_title_genre AS
SELECT b.show_id, g.genre_key FROM cln_title_genre b JOIN dim_genre g ON g.genre = b.genre;

CREATE OR REPLACE TABLE bridge_title_director AS SELECT show_id, director_name FROM cln_title_director;
CREATE OR REPLACE TABLE bridge_title_cast AS SELECT show_id, actor_name FROM cln_title_cast;

CREATE OR REPLACE TABLE fact_titles AS
SELECT t.show_id, t.show_num, t.content_type, t.title,
  COALESCE(YEAR(t.date_added) * 10000 + MONTH(t.date_added) * 100 + DAY(t.date_added), -1) AS date_added_key,
  t.release_year, CAST(FLOOR(t.release_year / 10) * 10 AS INT) AS release_decade,
  CASE WHEN t.date_added IS NULL THEN NULL ELSE YEAR(t.date_added) - t.release_year END AS years_release_to_add,
  CASE WHEN t.date_added IS NULL THEN '9 Unknown'
       WHEN YEAR(t.date_added) - t.release_year <= 0 THEN '1 Same year'
       WHEN YEAR(t.date_added) - t.release_year <= 2 THEN '2 1-2 yrs'
       WHEN YEAR(t.date_added) - t.release_year <= 5 THEN '3 3-5 yrs'
       WHEN YEAR(t.date_added) - t.release_year <= 10 THEN '4 6-10 yrs'
       WHEN YEAR(t.date_added) - t.release_year <= 20 THEN '5 11-20 yrs'
       ELSE '6 20+ yrs' END AS age_at_add_band,
  t.rating, t.movie_minutes, t.tv_seasons,
  CASE WHEN t.movie_minutes IS NULL THEN NULL
       WHEN t.movie_minutes < 60 THEN '1 <60 min' WHEN t.movie_minutes < 90 THEN '2 60-89 min'
       WHEN t.movie_minutes < 120 THEN '3 90-119 min' WHEN t.movie_minutes < 150 THEN '4 120-149 min'
       ELSE '5 150+ min' END AS runtime_band,
  COALESCE(t.primary_country, 'Unknown') AS primary_country,
  (SELECT COUNT(*) FROM cln_title_country c WHERE c.show_id = t.show_id) AS n_countries,
  (SELECT COUNT(*) FROM cln_title_genre g WHERE g.show_id = t.show_id) AS n_genres,
  (SELECT COUNT(*) FROM cln_title_cast a WHERE a.show_id = t.show_id) AS n_cast,
  t.dq_missing_director, t.dq_missing_cast, t.dq_missing_country, t.dq_runtime_outlier, t.dq_release_after_added
FROM cln_titles t;
