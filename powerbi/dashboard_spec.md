# Dashboard spec - "da-learn-07 Netflix catalogue"

One page, 16:9. Filters: content type, year added (dim_date[year]), audience (dim_rating[audience]), country (dim_country), genre (dim_genre).

| # | Visual | Fields | Expected (full data, no filters) |
|---|---|---|---|
| 1 | KPI cards | Titles, Movie Share %, Countries, Adult Rated %, Median Movie Minutes, Single Season Shows % | 8,803 / 69.6% / 122 / 45.5% / 98 / 67.0% |
| 2 | Line: titles added per year by type | dim_date[year], [Titles], legend content_type | peak 2019 = 2,015 titles (1,423 movies, 592 shows) |
| 3 | Bar: top countries | dim_country[country], [Country Titles], Top N 12 | United States 3,689, India 1,046, United Kingdom 806 |
| 4 | Bar: top genres | dim_genre[genre], [Genre Titles], Top N 12 | International Movies 2,749, Dramas 2,425, Comedies 1,672 |
| 5 | Column: maturity ratings | fact_titles[rating], [Titles] | TV-MA 3,203, TV-14 2,160, TV-PG 863 |
| 6 | Column: age at add | fact_titles[age_at_add_band], % of [Titles] | Same year 37.0%, 1-2 yrs 26.1% |
| 7 | Column: movie runtimes | fact_titles[runtime_band], [Movies] | 90-119 min = 50.4% of movies |
| 8 | Column: seasons | fact_titles[tv_seasons] (5+ grouped), [TV Shows] | 1 season = 1,793 shows (67.0%) |
| 9 | 100% stacked bar: audience by country | dim_country[country] (top 10), dim_rating[audience], [Titles] | India 55.7% teen-rated; Spain 79.3% adult |

Reference render of the same visuals (from DuckDB): `results/images/dashboard.png`.
