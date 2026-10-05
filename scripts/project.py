"""Project config shared by run_pipeline.py (DuckDB runner, charts, metrics)."""
REPO = "da-learn-07-netflix-content-analysis"
NN = "07"
DASH_TITLE = "Netflix catalogue - movies and TV shows (snapshot to Sep 2021)"
CURRENCY = None
DATASET = "Netflix Movies and TV Shows (Kaggle shivamb/netflix-shows, netflix_titles.csv): 8,807 titles listed on Netflix as of 2021-09-25"
RAW = {"stg_titles": {"file": "netflix_titles.csv", "format": "csv"}}
RAW_FILES = [v["file"] for v in RAW.values()]
SAMPLE_FILES = {"netflix_titles.csv": "netflix_titles_sample.csv"}
CLEAN = ["cln_titles_typed", "cln_titles_flagged", "cln_titles", "cln_title_country", "cln_title_genre", "cln_title_director", "cln_title_cast"]
STAR = ["fact_titles", "dim_date", "dim_rating", "dim_country", "dim_genre",
        "bridge_title_country", "bridge_title_genre", "bridge_title_director", "bridge_title_cast"]
PBI_CAP = {}
PBI_SAMPLE_FILTER = {}
SHOT_CONFIG = {"engine": "duckdb (local, full data); Databricks skipped - workspace resource quota",
               "sql_dialect": "Spark/Databricks SQL + DuckDB shims (sql/00)",
               "snapshot": "titles on Netflix (global catalogue as scraped) up to 2021-09-25; 2021 is a partial year",
               "multi_value": "country / genre / director / cast split into bridge tables; co-productions count once per country",
               "dedupe": "same lower(title) + type + release year + director -> keep earliest date_added",
               "repair": "3 rows with runtime in rating moved back to duration",
               "sample_rule": "data/raw = first title of every rating + per-year first adds + edge cases (duplicates, runtime-in-rating, missing date, stray comma country), CSV"}
SHOT_QUERIES = {
    "top_countries": "SELECT country, titles FROM a_top_countries ORDER BY titles DESC LIMIT 5",
    "top_genres": "SELECT genre, titles FROM a_top_genres ORDER BY titles DESC LIMIT 5",
    "peak_add_years": "SELECT year_added, titles, tv_share_pct FROM a_added_year_summary ORDER BY titles DESC LIMIT 3",
    "audience": "SELECT audience, pct_of_titles FROM a_audience ORDER BY audience",
    "content_age": "SELECT age_at_add_band, pct_of_titles FROM a_content_age ORDER BY age_at_add_band",
}
METRIC_QUERIES = {
    "added_year_summary": "SELECT * FROM a_added_year_summary ORDER BY year_added",
    "added_by_month": "SELECT * FROM a_added_by_month ORDER BY month",
    "top15_countries": "SELECT * FROM a_top_countries ORDER BY titles DESC, country LIMIT 15",
    "top15_genres": "SELECT * FROM a_top_genres ORDER BY titles DESC, genre LIMIT 15",
    "rating_mix": "SELECT * FROM a_rating_mix ORDER BY titles DESC",
    "audience": "SELECT * FROM a_audience ORDER BY audience",
    "country_audience": "SELECT * FROM a_country_audience ORDER BY titles DESC",
    "runtime_bands": "SELECT * FROM a_runtime_bands ORDER BY runtime_band",
    "runtime_by_decade": "SELECT * FROM a_runtime_by_decade ORDER BY release_decade",
    "tv_seasons": "SELECT * FROM a_tv_seasons ORDER BY seasons",
    "content_age": "SELECT * FROM a_content_age ORDER BY age_at_add_band",
    "release_decade": "SELECT * FROM a_release_decade ORDER BY release_decade",
    "top10_directors": "SELECT * FROM a_top_directors ORDER BY titles DESC, director_name LIMIT 10",
    "top10_cast": "SELECT * FROM a_top_cast ORDER BY titles DESC, actor_name LIMIT 10",
}
CARDS = [("titles", "Titles", "{:,}"), ("movie_pct", "Movies share", "{:.1f}%"), ("countries", "Countries", "{:,}"),
         ("added_2018_2021_pct", "Added 2018-21", "{:.1f}%"), ("adult_rated_pct", "Adult-rated (TV-MA/R)", "{:.1f}%"),
         ("median_movie_minutes", "Median movie (min)", "{:.0f}"), ("single_season_show_pct", "1-season shows", "{:.1f}%")]
VIZ = [
    {"name": "titles_added_by_year", "title": "Titles added per year, by type (2021 = Jan-Sep)", "kind": "line", "x": "year_added", "y": "titles", "color": "content_type", "fmt": "{:,.0f}",
     "sql": "SELECT CAST(year_added AS VARCHAR) AS year_added, content_type, titles FROM {S}a_added_by_year WHERE year_added >= 2008 ORDER BY year_added"},
    {"name": "top_countries", "title": "Top 12 countries by titles (co-productions count per country)", "kind": "hbar", "x": "country", "y": "titles", "fmt": "{:,.0f}",
     "sql": "SELECT country, titles FROM {S}a_top_countries ORDER BY titles DESC, country LIMIT 12"},
    {"name": "top_genres", "title": "Top 12 genres (a title can have up to 3)", "kind": "hbar", "x": "genre", "y": "titles", "fmt": "{:,.0f}",
     "sql": "SELECT genre, titles FROM {S}a_top_genres ORDER BY titles DESC, genre LIMIT 12"},
    {"name": "rating_mix", "title": "Titles by maturity rating", "kind": "bar", "x": "rating", "y": "titles", "fmt": "{:,.0f}",
     "sql": "SELECT rating, titles FROM {S}a_rating_mix ORDER BY titles DESC"},
    {"name": "content_age_at_add", "title": "Age of title when added (years since release, %)", "kind": "bar", "x": "band", "y": "pct_of_titles", "fmt": "{:.1f}%",
     "sql": "SELECT SUBSTR(age_at_add_band, 3) AS band, pct_of_titles FROM {S}a_content_age WHERE age_at_add_band <> '9 Unknown' ORDER BY age_at_add_band"},
    {"name": "movie_runtime_bands", "title": "Movie runtimes (% of movies)", "kind": "bar", "x": "band", "y": "pct_of_movies", "fmt": "{:.1f}%",
     "sql": "SELECT SUBSTR(runtime_band, 3) AS band, pct_of_movies FROM {S}a_runtime_bands ORDER BY runtime_band"},
    {"name": "tv_seasons", "title": "TV shows by number of seasons", "kind": "bar", "x": "seasons", "y": "shows", "fmt": "{:,.0f}",
     "sql": "SELECT seasons, shows FROM {S}a_tv_seasons ORDER BY seasons"},
    {"name": "tv_share_by_year", "title": "TV share of titles added each year (%)", "kind": "line", "x": "year_added", "y": "tv_share_pct", "fmt": "{:.0f}%",
     "sql": "SELECT CAST(year_added AS VARCHAR) AS year_added, tv_share_pct FROM {S}a_added_year_summary WHERE year_added >= 2014 ORDER BY year_added"},
]
