#!/usr/bin/env python3
"""Build the git-sized raw sample data/raw/netflix_titles_sample.csv from data/raw_full/netflix_titles.csv (deterministic).

Rule (every pick is the lowest show number that matches): the first title of each raw rating value, the first title added in
each year, and the edge cases the cleaning handles: both rows of all 4 duplicate pairs, the 3 runtime-in-rating rows,
2 missing date_added, 2 padded date_added, 2 country lists with stray commas, 1 missing country, 1 release-after-added,
1 very short and 1 very long movie. Original columns, rows kept verbatim (all text)."""
import pathlib
import duckdb

ROOT = pathlib.Path(__file__).resolve().parents[1]
FULL, OUT = ROOT / "data/raw_full/netflix_titles.csv", ROOT / "data/raw"
OUT.mkdir(parents=True, exist_ok=True)
con = duckdb.connect()
con.execute(f"CREATE TABLE t AS SELECT *, CAST(SUBSTR(show_id, 2) AS INT) AS _n FROM read_csv('{FULL}', header = true, all_varchar = true)")
pick = lambda where, k=1: f"(SELECT * FROM t WHERE {where} ORDER BY _n LIMIT {k})"
mins = "TRY_CAST(REGEXP_EXTRACT(duration, '^([0-9]+)', 1) AS INT)"
parts = [
    "(SELECT * FROM t QUALIFY ROW_NUMBER() OVER (PARTITION BY rating ORDER BY _n) = 1)",
    "(SELECT * FROM t WHERE date_added IS NOT NULL QUALIFY ROW_NUMBER() OVER (PARTITION BY RIGHT(TRIM(date_added), 4) ORDER BY _n) = 1)",
    "(SELECT * FROM t QUALIFY COUNT(*) OVER (PARTITION BY LOWER(TRIM(title)), type, release_year, COALESCE(director, '')) > 1)",
    pick("rating LIKE '% min'", 3), pick("date_added IS NULL", 2), pick("date_added <> TRIM(date_added)", 2),
    pick("TRIM(country) LIKE '%,' OR TRIM(country) LIKE ',%'", 2), pick("country IS NULL"),
    pick("TRY_CAST(release_year AS INT) > CAST(RIGHT(TRIM(date_added), 4) AS INT)"),
    pick(f"type = 'Movie' AND {mins} < 20"), pick(f"type = 'Movie' AND {mins} > 240"),
]
con.execute("CREATE TABLE s AS SELECT DISTINCT * FROM (" + " UNION ALL ".join(parts) + ")")
con.execute(f"COPY (SELECT * EXCLUDE (_n) FROM s ORDER BY _n) TO '{OUT}/netflix_titles_sample.csv' (HEADER, QUOTE '\"', FORCE_QUOTE *)")
print(con.sql("SELECT COUNT(*) FROM s").fetchone()[0], "sample titles")
