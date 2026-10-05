# Build guide (Power BI Desktop, Windows)

No `.pbix` is committed: this repo is built on Linux and Power BI Desktop runs on Windows only.

1. `python scripts/download_full_data.py` then `python run_pipeline.py --source full` (or use the committed `powerbi/data/*.csv`, which are already full size).
2. Power BI Desktop > Get data > Text/CSV: load the nine CSVs in `powerbi/data/`. In Power Query set `date_key`, `date_added_key`, `release_year`, `movie_minutes`, `tv_seasons`, `years_release_to_add` to Whole number and `full_date` to Date.
3. Model view: create the relationships in `model.md`. Set `bridge_title_country -> fact_titles` and `bridge_title_genre -> fact_titles` to cross-filter **Both**.
4. Mark nothing as a date table (date_key -1 is a placeholder); sort `month_label` by `month`.
5. New measures: paste `measures.dax` one measure at a time into the fact_titles table.
6. Build the page in `dashboard_spec.md` and check the cards against the "Expected" column; they come from `results/metrics.json`.
7. Save as `da-learn-07-netflix.pbix` locally (do not commit the binary unless you want to).
