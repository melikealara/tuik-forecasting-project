# =============================================================================
# plots.R
# Plot generation for all forecasting methods.
# =============================================================================

library(ggplot2)

# Shared ggplot2 theme for all plots
theme_tuik <- function() {
  theme_minimal(base_size = 12) +
    theme(
      plot.title    = element_text(face = "bold", size = 13),
      plot.subtitle = element_text(size = 10, colour = "grey40"),
      legend.position = "bottom",
      axis.text.x   = element_text(angle = 45, hjust = 1)
    )
}

# Build a long data frame from a ts object and a named fitted vector.
ts_to_df <- function(ts_obj, fitted_vals = NULL, method_name = "Fitted") {
  n    <- length(ts_obj)
  freq <- frequency(ts_obj)
  s    <- start(ts_obj)
  year <- s[1] + (s[2] - 1 + 0:(n - 1)) %/% freq
  mo   <- ((s[2] - 1 + 0:(n - 1)) %% freq) + 1
  date <- as.Date(paste(year, mo, "01", sep = "-"))

  df <- data.frame(Date = date, Actual = as.numeric(ts_obj))
  if (!is.null(fitted_vals)) {
    df[[method_name]] <- fitted_vals
  }
  df
}

# Extend date vector by h steps for forecast points.
extend_dates <- function(ts_obj, h = 1) {
  n    <- length(ts_obj)
  freq <- frequency(ts_obj)
  s    <- start(ts_obj)
  idx  <- s[2] - 1 + n:(n + h - 1)
  year <- s[1] + idx %/% freq
  mo   <- (idx %% freq) + 1
  as.Date(paste(year, mo, "01", sep = "-"))
}

#' Plot the raw (actual) time series.
plot_actual_series <- function(ts_obj, out_path) {
  df <- ts_to_df(ts_obj)
  p  <- ggplot(df, aes(x = Date, y = Actual)) +
    geom_line(colour = "#2c7bb6", linewidth = 0.7) +
    labs(title    = "Monthly Tourism Expenditure – Actual Series",
         subtitle = "TÜİK Theme 14 | Jan 2012 – Mar 2026",
         x = "Date", y = "Tourism Expenditure (Thousand $)") +
    scale_y_continuous(labels = scales::comma) +
    theme_tuik()
  ggsave(out_path, plot = p, width = 10, height = 5, dpi = 150)
  invisible(p)
}

#' Generic actual-vs-forecast plot.
plot_method <- function(ts_obj, fitted_vals, next_fcst, method_label, out_path) {
  df <- ts_to_df(ts_obj, fitted_vals, "Fitted")

  # Next-period point
  fcst_date <- extend_dates(ts_obj, h = 1)
  fcst_df   <- data.frame(Date = fcst_date, Fitted = next_fcst)

  # Reshape to long for legend
  df_long <- reshape(df, varying = c("Actual", "Fitted"),
                     v.names = "Value", timevar = "Series",
                     times = c("Actual", "Fitted"),
                     direction = "long")
  df_long$Series <- factor(df_long$Series, levels = c("Actual", "Fitted"))

  p <- ggplot() +
    geom_line(data = df_long[df_long$Series == "Actual", ],
              aes(x = Date, y = Value, colour = Series), linewidth = 0.65) +
    geom_line(data = df_long[df_long$Series == "Fitted", ],
              aes(x = Date, y = Value, colour = Series),
              linewidth = 0.65, na.rm = TRUE) +
    geom_point(data = fcst_df,
               aes(x = Date, y = Fitted), colour = "#d7191c",
               size = 3, shape = 18) +
    scale_colour_manual(values = c("Actual" = "#2c7bb6", "Fitted" = "#fdae61"),
                        name = NULL) +
    labs(title    = paste("Actual vs", method_label),
         subtitle = paste0("Next-period forecast (Apr 2026): ",
                           format(round(next_fcst, 0), big.mark = ",")),
         x = "Date", y = "Tourism Expenditure (Thousand $)") +
    scale_y_continuous(labels = scales::comma) +
    theme_tuik()

  ggsave(out_path, plot = p, width = 10, height = 5, dpi = 150)
  invisible(p)
}

#' Superior method final plot (actual + fitted + forecast point highlighted).
plot_superior <- function(ts_obj, fitted_vals, next_fcst, method_label, out_path) {
  df       <- ts_to_df(ts_obj, fitted_vals, "Fitted")
  df_long  <- reshape(df, varying = c("Actual", "Fitted"),
                      v.names = "Value", timevar = "Series",
                      times   = c("Actual", "Fitted"),
                      direction = "long")
  df_long$Series <- factor(df_long$Series, levels = c("Actual", "Fitted"))

  fcst_date <- extend_dates(ts_obj, h = 1)
  fcst_df   <- data.frame(Date = fcst_date, Value = next_fcst,
                          Series = "Next-Period Forecast")

  p <- ggplot() +
    geom_line(data = df_long[df_long$Series == "Actual", ],
              aes(x = Date, y = Value, colour = Series), linewidth = 0.7) +
    geom_line(data = df_long[df_long$Series == "Fitted", ],
              aes(x = Date, y = Value, colour = Series),
              linewidth = 0.7, na.rm = TRUE) +
    geom_point(data = fcst_df,
               aes(x = Date, y = Value, colour = Series), size = 4, shape = 18) +
    scale_colour_manual(
      values = c("Actual" = "#2c7bb6", "Fitted" = "#fdae61",
                 "Next-Period Forecast" = "#d7191c"),
      name = NULL) +
    labs(title    = paste("Superior Method:", method_label),
         subtitle = paste0("Apr 2026 Forecast: ",
                           format(round(next_fcst, 0), big.mark = ","), " Thousand $"),
         x = "Date", y = "Tourism Expenditure (Thousand $)") +
    scale_y_continuous(labels = scales::comma) +
    theme_tuik()

  ggsave(out_path, plot = p, width = 10, height = 5, dpi = 150)
  invisible(p)
}
