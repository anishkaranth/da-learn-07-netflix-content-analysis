-- 00_duckdb_compat.sql  (DuckDB ONLY - skip on Databricks/Spark, where these functions are built in)
-- to_date(str, 'MMMM d, yyyy') -> DuckDB strptime with the equivalent format; explode(array) -> unnest
CREATE OR REPLACE MACRO to_date(s, fmt) AS CAST(try_strptime(s, '%B %d, %Y') AS DATE);
CREATE OR REPLACE MACRO explode(l) AS unnest(l);
CREATE OR REPLACE MACRO percentile_approx(x, p) AS quantile_cont(x, p);
