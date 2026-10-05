-- 04_analysis.sql  KPIs and business questions over the cleaned catalogue (one row per title in fact_titles).
-- "Added" = the date the title appeared on Netflix (date_added); the snapshot ends 2021-09-25, so 2021 is a partial year.

CREATE OR REPLACE TABLE a_kpi_headline AS
SELECT COUNT(*) AS titles,
  SUM(CASE WHEN content_type = 'Movie' THEN 1 ELSE 0 END) AS movies,
  SUM(CASE WHEN content_type = 'TV Show' THEN 1 ELSE 0 END) AS tv_shows,
  ROUND(100.0 * AVG(CASE WHEN content_type = 'Movie' THEN 1.0 ELSE 0.0 END), 2) AS movie_pct,
  (SELECT COUNT(*) FROM dim_country) AS countries,
  (SELECT COUNT(*) FROM dim_genre) AS genres,
  (SELECT COUNT(DISTINCT director_name) FROM bridge_title_director) AS directors,
  (SELECT COUNT(DISTINCT actor_name) FROM bridge_title_cast) AS cast_members,
  ROUND(AVG(movie_minutes), 1) AS avg_movie_minutes,
  percentile_approx(movie_minutes, 0.5) AS median_movie_minutes,
  ROUND(AVG(tv_seasons), 2) AS avg_tv_seasons,
  ROUND(100.0 * SUM(CASE WHEN tv_seasons = 1 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN content_type = 'TV Show' THEN 1 ELSE 0 END), 0), 2) AS single_season_show_pct,
  ROUND(100.0 * AVG(CASE WHEN rating IN ('TV-MA', 'R', 'NC-17') THEN 1.0 ELSE 0.0 END), 2) AS adult_rated_pct,
  ROUND(100.0 * SUM(CASE WHEN primary_country = 'United States' THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN primary_country <> 'Unknown' THEN 1 ELSE 0 END), 0), 2) AS us_primary_pct_of_known,
  ROUND(100.0 * AVG(CASE WHEN years_release_to_add <= 0 THEN 1.0 WHEN years_release_to_add IS NULL THEN NULL ELSE 0.0 END), 2) AS added_same_year_pct,
  percentile_approx(years_release_to_add, 0.5) AS median_years_release_to_add,
  ROUND(100.0 * AVG(CASE WHEN date_added_key BETWEEN 20180101 AND 20211231 THEN 1.0 ELSE 0.0 END), 2) AS added_2018_2021_pct,
  MIN(CASE WHEN date_added_key > 0 THEN date_added_key END) AS first_added_key,
  MAX(date_added_key) AS last_added_key,
  MIN(release_year) AS oldest_release_year
FROM fact_titles;

-- Q1: how fast did the catalogue grow, and when did TV catch up?
CREATE OR REPLACE TABLE a_added_by_year AS
SELECT d.year AS year_added, f.content_type, COUNT(*) AS titles
FROM fact_titles f JOIN dim_date d ON d.date_key = f.date_added_key
WHERE d.year IS NOT NULL GROUP BY d.year, f.content_type;

CREATE OR REPLACE TABLE a_added_year_summary AS
SELECT d.year AS year_added, COUNT(*) AS titles,
  SUM(CASE WHEN f.content_type = 'Movie' THEN 1 ELSE 0 END) AS movies,
  SUM(CASE WHEN f.content_type = 'TV Show' THEN 1 ELSE 0 END) AS tv_shows,
  ROUND(100.0 * AVG(CASE WHEN f.content_type = 'TV Show' THEN 1.0 ELSE 0.0 END), 2) AS tv_share_pct,
  ROUND(100.0 * AVG(CASE WHEN f.primary_country NOT IN ('United States', 'Unknown') THEN 1.0 ELSE 0.0 END), 2) AS non_us_primary_pct,
  ROUND(100.0 * AVG(CASE WHEN f.years_release_to_add <= 0 THEN 1.0 ELSE 0.0 END), 2) AS same_year_release_pct
FROM fact_titles f JOIN dim_date d ON d.date_key = f.date_added_key
WHERE d.year IS NOT NULL GROUP BY d.year;

-- Q2: is there a release calendar?
CREATE OR REPLACE TABLE a_added_by_month AS
SELECT d.month, d.month_label, COUNT(*) AS titles,
  ROUND(100.0 * SUM(d.is_first_of_month) / COUNT(*), 2) AS on_first_of_month_pct
FROM fact_titles f JOIN dim_date d ON d.date_key = f.date_added_key
WHERE d.month IS NOT NULL GROUP BY d.month, d.month_label;

-- Q3: where does the content come from? (a co-production counts once for every country listed)
CREATE OR REPLACE TABLE a_top_countries AS
SELECT c.country, COUNT(*) AS titles,
  SUM(CASE WHEN f.content_type = 'Movie' THEN 1 ELSE 0 END) AS movies,
  SUM(CASE WHEN f.content_type = 'TV Show' THEN 1 ELSE 0 END) AS tv_shows,
  ROUND(100.0 * AVG(CASE WHEN f.content_type = 'Movie' THEN 1.0 ELSE 0.0 END), 2) AS movie_pct,
  SUM(b.is_primary) AS as_primary_country
FROM bridge_title_country b JOIN dim_country c ON c.country_key = b.country_key JOIN fact_titles f ON f.show_id = b.show_id
GROUP BY c.country;

-- Q4: what is in the catalogue? genres and audience ratings
CREATE OR REPLACE TABLE a_top_genres AS
SELECT g.genre, g.genre_family, COUNT(*) AS titles,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fact_titles), 2) AS pct_of_titles
FROM bridge_title_genre b JOIN dim_genre g ON g.genre_key = b.genre_key
GROUP BY g.genre, g.genre_family;

CREATE OR REPLACE TABLE a_rating_mix AS
SELECT r.rating, r.audience, r.rating_system, COUNT(*) AS titles,
  SUM(CASE WHEN f.content_type = 'Movie' THEN 1 ELSE 0 END) AS movies,
  SUM(CASE WHEN f.content_type = 'TV Show' THEN 1 ELSE 0 END) AS tv_shows,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fact_titles), 2) AS pct_of_titles
FROM fact_titles f JOIN dim_rating r ON r.rating = f.rating
GROUP BY r.rating, r.audience, r.rating_system;

CREATE OR REPLACE TABLE a_audience AS
SELECT r.audience, COUNT(*) AS titles, ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fact_titles), 2) AS pct_of_titles
FROM fact_titles f JOIN dim_rating r ON r.rating = f.rating GROUP BY r.audience;

-- audience mix by country (top 10 countries by titles)
CREATE OR REPLACE TABLE a_country_audience AS
SELECT c.country,
  COUNT(*) AS titles,
  ROUND(100.0 * AVG(CASE WHEN r.audience = '4 Adults' THEN 1.0 ELSE 0.0 END), 2) AS adults_pct,
  ROUND(100.0 * AVG(CASE WHEN r.audience = '3 Teens' THEN 1.0 ELSE 0.0 END), 2) AS teens_pct,
  ROUND(100.0 * AVG(CASE WHEN r.audience IN ('1 Kids', '2 Older kids / family') THEN 1.0 ELSE 0.0 END), 2) AS kids_family_pct
FROM bridge_title_country b JOIN dim_country c ON c.country_key = b.country_key
JOIN fact_titles f ON f.show_id = b.show_id JOIN dim_rating r ON r.rating = f.rating
WHERE c.country IN (SELECT country FROM a_top_countries ORDER BY titles DESC LIMIT 10)
GROUP BY c.country;

-- Q5: how long are movies, how long do shows last?
CREATE OR REPLACE TABLE a_runtime_bands AS
SELECT runtime_band, COUNT(*) AS movies, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_movies
FROM fact_titles WHERE content_type = 'Movie' AND runtime_band IS NOT NULL GROUP BY runtime_band;

CREATE OR REPLACE TABLE a_runtime_by_decade AS
SELECT release_decade, COUNT(*) AS movies, ROUND(AVG(movie_minutes), 1) AS avg_minutes
FROM fact_titles WHERE content_type = 'Movie' GROUP BY release_decade;

CREATE OR REPLACE TABLE a_tv_seasons AS
SELECT CASE WHEN tv_seasons >= 5 THEN '5+' ELSE CAST(tv_seasons AS STRING) END AS seasons, COUNT(*) AS shows,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_shows
FROM fact_titles WHERE content_type = 'TV Show' GROUP BY 1;

-- Q6: new releases or back catalogue?
CREATE OR REPLACE TABLE a_content_age AS
SELECT age_at_add_band, COUNT(*) AS titles,
  SUM(CASE WHEN content_type = 'Movie' THEN 1 ELSE 0 END) AS movies,
  SUM(CASE WHEN content_type = 'TV Show' THEN 1 ELSE 0 END) AS tv_shows,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_titles
FROM fact_titles GROUP BY age_at_add_band;

CREATE OR REPLACE TABLE a_release_decade AS
SELECT release_decade, COUNT(*) AS titles,
  SUM(CASE WHEN content_type = 'Movie' THEN 1 ELSE 0 END) AS movies,
  SUM(CASE WHEN content_type = 'TV Show' THEN 1 ELSE 0 END) AS tv_shows
FROM fact_titles GROUP BY release_decade;

-- Q7: who appears most?
CREATE OR REPLACE TABLE a_top_directors AS
SELECT d.director_name, COUNT(*) AS titles,
  SUM(CASE WHEN f.content_type = 'Movie' THEN 1 ELSE 0 END) AS movies,
  MIN(f.release_year) AS first_release, MAX(f.release_year) AS last_release
FROM bridge_title_director d JOIN fact_titles f ON f.show_id = d.show_id
GROUP BY d.director_name;

CREATE OR REPLACE TABLE a_top_cast AS
SELECT a.actor_name, COUNT(*) AS titles,
  SUM(CASE WHEN f.content_type = 'Movie' THEN 1 ELSE 0 END) AS movies,
  SUM(CASE WHEN f.content_type = 'TV Show' THEN 1 ELSE 0 END) AS tv_shows
FROM bridge_title_cast a JOIN fact_titles f ON f.show_id = a.show_id
GROUP BY a.actor_name;
