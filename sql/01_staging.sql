-- 01_staging.sql  Land netflix_titles.csv as-is (every column as text). {{RAW_DIR}} is set by run_pipeline.py.
-- The committed sample (data/raw/netflix_titles_sample.csv) has the same columns; run_pipeline swaps the file name.
-- Spark/Databricks equivalent: SELECT * FROM read_files('<path>/netflix_titles.csv', format => 'csv', header => true, inferSchema => false)
CREATE OR REPLACE TABLE stg_titles AS
SELECT * FROM read_csv('{{RAW_DIR}}/netflix_titles.csv', header = true, all_varchar = true, quote = '"', escape = '"');
