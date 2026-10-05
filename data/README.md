# data/

| Path | What | In git |
|---|---|---|
| `raw/netflix_titles_sample.csv` | 49 raw rows, original 12 columns, verbatim text. Rule in `scripts/make_sample.py`: the first title of every rating value, the first title added in each year, both rows of all 4 duplicate pairs, the 3 runtime-in-rating rows, missing and padded add dates, stray-comma countries, a missing country, a release-after-add row, and the shortest / longest movie outliers. | yes |
| `raw_full/netflix_titles.csv` | the full Kaggle file (8,807 rows, 3.4 MB), from `python scripts/download_full_data.py` | no (download) |
| `clean/cln_titles.csv` | the full cleaned catalogue after `sql/02_cleaning.sql` (8,803 rows, typed, repaired, de-duplicated, with DQ flags) | yes |
| `clean/star/` | star-schema CSVs from the full run (identical copies are in `powerbi/data/`) | no |
