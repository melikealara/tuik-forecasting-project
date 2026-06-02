# =============================================================================
# data_import.R
# Downloads and prepares monthly tourism expenditure data from TÜİK.
# Data access: tuikr::statistical_tables("14") -> table_url -> httr::GET()
# =============================================================================

import_tuik_data <- function() {
  library(tuikr)
  library(httr)
  library(readxl)
  library(forecast)

  # Step 1: Retrieve all Tourism (theme 14) table metadata via tuikr
  tourism_tables <- statistical_tables("14")

  # Step 2: Identify the monthly expenditure table
  monthly_tbl <- tourism_tables[
    grepl("Tourism expenditures, number of visitors.*months", tourism_tables$table_name), ]

  if (nrow(monthly_tbl) == 0) stop("Monthly tourism table not found in TÜİK data.")

  # Step 3: Download the Excel file using the URL returned by statistical_tables()
  temp_file <- tempfile(fileext = ".xls")
  resp <- GET(
    monthly_tbl$table_url,
    add_headers(
      `User-Agent` = paste0("Mozilla/5.0 (Windows NT 10.0; Win64; x64) ",
                            "AppleWebKit/537.36 (KHTML, like Gecko) ",
                            "Chrome/124.0.0.0 Safari/537.36")
    ),
    write_disk(temp_file, overwrite = TRUE)
  )
  if (status_code(resp) != 200) stop("Download failed (HTTP ", status_code(resp), ").")

  # Step 4: Parse the wide-format Excel
  df_raw <- suppressMessages(read_excel(temp_file))

  # Table layout (wide format, 37 rows x 46 columns):
  #   Row 1 : bilingual title
  #   Row 2 : blank
  #   Row 3 : year labels (2012, NA, NA, 2013, ...)
  #   Row 4 : sub-column headers
  #   Row 5 : annual totals
  #   Rows 6-17: months Jan-Dec
  #   Column pattern: 1=month label, then groups of 3 per year
  #     col 2 = expenditure, col 3 = visitors, col 4 = per capita  (2012)
  #     col 5 = expenditure, col 6 = visitors, col 7 = per capita  (2013)  ...etc.

  # Step 5: Extract tourism expenditure columns (Thousand $) for years 2012-2026
  col_indices <- seq(2, 44, by = 3)   # 15 values: one column per year
  val_matrix  <- df_raw[6:17, col_indices]  # rows 6-17 = Jan through Dec

  # Step 6: Flatten to a chronological monthly vector (column-major = Jan2012 first)
  val_vector           <- as.vector(as.matrix(val_matrix))
  val_vector[val_vector == "-"] <- NA          # TÜİK marks unavailable periods with "-"
  val_numeric          <- suppressWarnings(as.numeric(val_vector))

  # Step 7: Trim to last published (non-NA) observation
  last_obs_idx <- max(which(!is.na(val_numeric)))
  val_clean    <- val_numeric[1:last_obs_idx]

  # Step 8: Build monthly ts object (Jan 2012 start, frequency = 12)
  ts_raw  <- ts(val_clean, start = c(2012, 1), frequency = 12)

  # Step 9: Impute COVID-period gaps via linear interpolation
  ts_data <- na.interp(ts_raw)

  # Determine latest observation and next period
  end_yr  <- end(ts_data)[1]
  end_mo  <- end(ts_data)[2]
  month_names <- c("January","February","March","April","May","June",
                   "July","August","September","October","November","December")
  latest_obs      <- paste(month_names[end_mo], end_yr)
  next_mo         <- if (end_mo == 12) 1L else end_mo + 1L
  next_yr         <- if (end_mo == 12) end_yr + 1L else end_yr
  forecast_target <- paste(month_names[next_mo], next_yr)

  list(
    ts_raw          = ts_raw,
    ts_data         = ts_data,
    table_name      = monthly_tbl$table_name,
    theme           = "Tourism (14)",
    selected_var    = "Tourism expenditures (Thousand $)",
    frequency       = "Monthly",
    time_coverage   = paste0(start(ts_data)[1], "-0", start(ts_data)[2],
                             " / ", end_yr, "-",
                             formatC(end_mo, width=2, flag="0")),
    latest_obs      = latest_obs,
    forecast_target = forecast_target,
    data_access_date= format(Sys.Date(), "%Y-%m-%d"),
    n_obs           = length(ts_data),
    n_na_raw        = sum(is.na(ts_raw))
  )
}
