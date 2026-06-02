# TÜİK Forecasting Project

## 1. Project Overview

This project forecasts monthly **Tourism Expenditure (Thousand USD)** of Turkish citizens
travelling abroad, using data obtained directly from the Turkish Statistical Institute (TÜİK)
through the `tuikr` R package. Ten quantitative forecasting methods are applied, compared
using standard accuracy and monitoring measures, and the structurally most appropriate method
is selected to produce a point forecast for the next unpublished period.

---

## 2. Data Source and TÜİK Connection

Data are accessed programmatically from the TÜİK Data Portal using the `tuikr` R package.
No manually downloaded, copied, or edited data file is used anywhere in this analysis.

| Field | Value |
|---|---|
| TÜİK dataset name | Tourism expenditures, number of visitors and average expenditure per capita by months |
| TÜİK theme / category | Tourism (Theme 14) |
| TÜİK table name | Tourism expenditures, number of visitors and average expenditure per capita by months, 2012–2026 |
| tuikr dataflow ID | Not applicable — istab table; URL accessed via `tuikr::statistical_tables("14")` |
| Selected variable | Tourism expenditures (Thousand $) |
| Data frequency | Monthly |
| Time coverage | 2012-01 / 2026-03 |
| Latest available observation | March 2026 |
| Forecast target period | April 2026 |
| Date of data access | 2026-05-30 |
| R package for data access | `tuikr` |
| Package source | https://github.com/emraher/tuikr |

---

## 3. Research Objective

Monthly tourism expenditure is an important macroeconomic indicator that reflects the
international travel behaviour of Turkish citizens. It is published by TÜİK on a quarterly
reporting cycle with monthly breakdowns, making it a suitable monthly time series for
forecasting. Producing a reliable one-month-ahead forecast is useful for travel industry
planning, foreign exchange revenue projections, and policy analysis.

---

## 4. Use of TÜİK Data in R

The TÜİK data are accessed inside the R notebook using the following reproducible steps:

1. `tuikr::statistical_tables("14")` retrieves the metadata (table names and download URLs)
   for all Tourism theme tables.
2. The monthly expenditure table is identified by a pattern match on the table name.
3. The Excel file is downloaded at runtime using `httr::GET()` with the URL provided by
   `statistical_tables()`.
4. The wide-format Excel is parsed and the tourism expenditure column is extracted for
   each year 2012–2026 (rows 6–17 = months Jan–Dec; columns `seq(2,44,by=3)` = years).
5. Missing values coded as `"-"` (COVID lockdown periods, 13 months) are imputed using
   `forecast::na.interp()` (seasonal linear interpolation).
6. The result is a clean monthly `ts` object starting January 2012 with 171 observations.

---

## 5. Exploratory Time Series Analysis

The series shows:

- **Trend**: Strong upward trend from 2012 to early 2020; near-zero during COVID (2020–2021);
  sharp recovery and continued growth from 2022 to 2026.
- **Seasonality**: Pronounced multiplicative monthly seasonal pattern. Peak months are
  July–September (summer international travel) and December–January (winter holidays).
  Trough months are typically February and November.
- **Cyclical movements**: The COVID structural break dominates any classical business cycle.
- **Random variation**: Moderate residual variation around the trend-seasonal component.
- **Missing values**: 13 COVID-period months imputed via `na.interp()`.
- **Outliers**: No single-observation outliers beyond the COVID period are visible.

---

## 6. Forecasting Methods Applied

All ten required methods are implemented in `forecasting_project.Rmd`:

| Method | Applicable | Notes |
|---|---|---|
| Naïve Forecasting | Yes | Benchmark; forecast = last observation |
| Moving Average | Yes | k=12 spans one seasonal cycle |
| Weighted Moving Average | Yes | k=12, linearly increasing weights |
| Exponential Smoothing | Yes | SES; α optimised automatically |
| Trend-Adjusted ES (Holt's) | Yes | α and β optimised automatically |
| Linear Trend Projection | Yes | OLS regression on time index |
| Seasonal Indices | Yes | Ratio-to-moving-average method |
| Additive Decomposition | Yes | 2×12 centred MA trend |
| Multiplicative Decomposition | Yes | Preferred over additive given scaling seasonality |
| Regression (Trend + Seasonal Dummies) | Yes | 11 monthly dummies + time trend |

---

## 7. Forecast Accuracy Comparison

All methods are evaluated over the same 153-observation window (observations 13–165)
to ensure comparability. Accuracy measures reported:

- **Bias (Mean Error)**: signed average error — positive = systematic over-forecast
- **MAD**: Mean Absolute Deviation
- **MSE**: Mean Squared Error
- **MAPE**: Mean Absolute Percent Error (%)
- **RSFE**: Running Sum of Forecast Errors (cumulative bias)
- **Tracking Signal**: RSFE / MAD — values outside ±4 signal systematic bias

Full comparison table is saved to `outputs/tables/accuracy_comparison.csv`.

---

## 8. Selection of the Superior Method

**Selected superior method: Multiplicative Decomposition** (MAPE = 14.67%)

The method is selected on both quantitative accuracy results and structural suitability:

**Quantitative**: Multiplicative Decomposition achieves the lowest MAPE (14.67%) among
all ten candidate methods over the 153-observation evaluation period (obs 13–165).
MAD = 50,106 Thousand $. The Tracking Signal of 6.76 slightly exceeds the ±4 MAD
guideline but is largely explained by the post-COVID growth acceleration that
consistently outpaced historically calibrated forecasts across all methods.

**Structural**: The series exhibits both a long-run upward trend and a strong
multiplicative seasonal pattern — peak months (July–September) are substantially
larger in absolute terms in 2025 than in 2012, confirming that seasonal amplitude
scales with the level of the series. Multiplicative decomposition directly models
this structure as T × S × R, making it the most appropriate representation of the
data-generating process. Methods that ignore seasonality entirely (Naive, SES, Holt,
MA, WMA, Linear Trend) are structurally unsuitable for forecasting any specific
calendar month. The additive decomposition is structurally inferior to multiplicative
for a series with growing seasonal amplitude.

---

## 9. Final Next-Period Forecast

| Field | Value |
|---|---|
| Superior method | Multiplicative Decomposition |
| Date of data access | 2026-05-30 |
| Latest available TÜİK observation | March 2026 |
| Forecast target period | April 2026 |
| Forecasted value | **522,533 Thousand $** |
| MAPE | 14.67% |
| MAD | 50,106 Thousand $ |
| Tracking Signal | 6.76 |

The April 2026 forecast of **522,533 Thousand $** reflects the seasonal pattern
typical of April — a spring shoulder month that sits between the relatively low
February–March trough and the high summer peak. The ongoing post-COVID upward
trend in Turkish outbound travel expenditure supports an absolute level notably
higher than the same month in pre-2022 years.

---

## 10. Interpretation of Results

The April 2026 forecast indicates that outbound tourism expenditure will be consistent
with the seasonal transition from the low-expenditure winter months toward the higher
expenditure summer peak. The long-run upward trend observed since 2022 continues to
push the absolute level of the forecast upward relative to the same month in prior years.

---

## 11. Limitations

- COVID-19 structural break: 13 missing months imputed; pre- and post-COVID regimes differ.
- Linear trend assumption may underestimate the post-2022 acceleration.
- No explanatory variables (exchange rates, fuel prices, geopolitical events).
- TÜİK may revise published figures; results reflect data available on 2026-05-30.
- Only ~4 full seasonal cycles of post-COVID data available for seasonal estimation.

---

## 12. Reproducibility

1. Clone this repository from its public GitHub URL and open the project directory.

2. Open `tuik-forecasting-project.Rproj` in RStudio.

3. Restore the R package environment:
   ```r
   renv::restore()
   ```

4. Render the notebook (requires internet access to TÜİK portal):
   ```r
   rmarkdown::render("forecasting_project.Rmd")
   ```

The rendered HTML file (`forecasting_project.html`) and all output files in
`outputs/` are regenerated automatically. No manual data preparation steps are required.

---

## 13. Repository Structure

```
tuik-forecasting-project/
├── README.md                          # This documentation file
├── forecasting_project.Rmd            # Main R Markdown notebook
├── forecasting_project.html           # Rendered HTML output
├── outputs/
│   ├── tables/
│   │   ├── accuracy_comparison.csv    # Method comparison table
│   │   └── final_forecast.csv         # Final forecast result
│   └── figures/
│       ├── actual_series_plot.png
│       ├── naive_forecast_plot.png
│       ├── moving_average_plot.png
│       ├── weighted_moving_average_plot.png
│       ├── exponential_smoothing_plot.png
│       ├── trend_adjusted_smoothing_plot.png
│       ├── trend_projection_plot.png
│       ├── seasonal_indices_plot.png
│       ├── additive_decomposition_plot.png
│       ├── multiplicative_decomposition_plot.png
│       ├── regression_seasonal_dummy_plot.png
│       └── superior_method_plot.png
├── R/
│   ├── data_import.R                  # TÜİK data access via tuikr
│   ├── forecasting_methods.R          # All ten forecasting methods
│   ├── accuracy_measures.R            # Accuracy metric functions
│   └── plots.R                        # Plot utilities
├── renv.lock                          # Reproducible package environment
└── .gitignore
```

---

## 14. Author

- **Student Name**: Melike Alara Göler
- **Student Number**: 138722041
- **Course**: Quantitative Analysis and Decision Making 
