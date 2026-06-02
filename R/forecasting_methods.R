# =============================================================================
# forecasting_methods.R
# All ten required forecasting methods applied to a monthly ts object.
# Each function returns list(actual, fitted, next_fcst, method_label).
# =============================================================================

# ---------------------------------------------------------------------------
# 1. Naive Forecasting
#    One-step-ahead forecast = previous observation.
# ---------------------------------------------------------------------------
method_naive <- function(ts_obj) {
  n      <- length(ts_obj)
  actual <- as.numeric(ts_obj)
  fitted <- c(NA, actual[-n])          # fitted[t] = actual[t-1]
  list(actual     = actual,
       fitted     = fitted,
       next_fcst  = actual[n],         # last observation becomes next forecast
       method_label = "Naive")
}

# ---------------------------------------------------------------------------
# 2. Moving Average (k = 12)
#    k=12 spans exactly one seasonal cycle, eliminating seasonal variation.
# ---------------------------------------------------------------------------
method_ma <- function(ts_obj, k = 12) {
  n      <- length(ts_obj)
  actual <- as.numeric(ts_obj)
  fitted <- rep(NA_real_, n)
  for (t in (k + 1):n) {
    fitted[t] <- mean(actual[(t - k):(t - 1)])
  }
  next_fcst <- mean(actual[(n - k + 1):n])
  list(actual = actual, fitted = fitted, next_fcst = next_fcst,
       method_label = paste0("Moving Average (k=", k, ")"))
}

# ---------------------------------------------------------------------------
# 3. Weighted Moving Average (k = 12, linearly increasing weights)
#    Weights 1:12 normalised to sum to 1; most recent month gets highest weight.
# ---------------------------------------------------------------------------
method_wma <- function(ts_obj, k = 12) {
  n      <- length(ts_obj)
  actual <- as.numeric(ts_obj)
  w      <- (1:k) / sum(1:k)         # weights: oldest = 1/78, newest = 12/78
  fitted <- rep(NA_real_, n)
  for (t in (k + 1):n) {
    fitted[t] <- sum(w * actual[(t - k):(t - 1)])
  }
  next_fcst <- sum(w * actual[(n - k + 1):n])
  list(actual = actual, fitted = fitted, next_fcst = next_fcst,
       method_label = paste0("Weighted MA (k=", k, ")"))
}

# ---------------------------------------------------------------------------
# 4. Simple Exponential Smoothing
#    Alpha selected by minimising SSE (via ets ANN model).
# ---------------------------------------------------------------------------
method_ses <- function(ts_obj) {
  library(forecast)
  fit    <- ets(ts_obj, model = "ANN")
  alpha  <- fit$par["alpha"]
  actual <- as.numeric(ts_obj)
  fitted <- as.numeric(fitted(fit))
  next_fcst <- as.numeric(forecast(fit, h = 1)$mean)
  list(actual = actual, fitted = fitted, next_fcst = next_fcst,
       alpha = alpha,
       method_label = paste0("Exponential Smoothing (alpha=",
                             round(alpha, 3), ")"))
}

# ---------------------------------------------------------------------------
# 5. Trend-Adjusted Exponential Smoothing (Holt's)
#    Captures both level and trend; alpha and beta optimised.
# ---------------------------------------------------------------------------
method_holt <- function(ts_obj) {
  library(forecast)
  fit    <- ets(ts_obj, model = "AAN")
  alpha  <- fit$par["alpha"]
  beta   <- fit$par["beta"]
  actual <- as.numeric(ts_obj)
  fitted <- as.numeric(fitted(fit))
  next_fcst <- as.numeric(forecast(fit, h = 1)$mean)
  list(actual = actual, fitted = fitted, next_fcst = next_fcst,
       alpha = alpha, beta = beta,
       method_label = paste0("Holt's (alpha=", round(alpha, 3),
                             ", beta=", round(beta, 3), ")"))
}

# ---------------------------------------------------------------------------
# 6. Linear Trend Projection
#    OLS regression of values on a time index.
# ---------------------------------------------------------------------------
method_linear_trend <- function(ts_obj) {
  n      <- length(ts_obj)
  actual <- as.numeric(ts_obj)
  t_idx  <- 1:n
  fit    <- lm(actual ~ t_idx)
  fitted <- as.numeric(fitted(fit))
  next_fcst <- as.numeric(predict(fit, newdata = data.frame(t_idx = n + 1)))
  list(actual = actual, fitted = fitted, next_fcst = next_fcst,
       coef_intercept = coef(fit)[1],
       coef_slope     = coef(fit)[2],
       method_label   = "Linear Trend Projection")
}

# ---------------------------------------------------------------------------
# 7. Seasonal Indices (ratio-to-moving-average method)
#    Deseasonalises with multiplicative seasonal indices, fits a trend,
#    then re-seasonalises to produce forecasts.
# ---------------------------------------------------------------------------
method_seasonal_indices <- function(ts_obj) {
  n      <- length(ts_obj)
  actual <- as.numeric(ts_obj)
  freq   <- frequency(ts_obj)

  # Centered 2x12 moving average
  cma <- stats::filter(actual, filter = c(0.5, rep(1, freq - 1), 0.5) / freq,
                       method = "convolution", sides = 2)

  # Raw seasonal ratios
  si_raw <- actual / cma

  # Average ratio by month (accounting for NA at boundaries)
  month_idx <- cycle(ts_obj)
  si_by_month <- tapply(si_raw, month_idx, mean, na.rm = TRUE)

  # Normalise so that mean of 12 indices = 1
  si_by_month <- si_by_month / mean(si_by_month)

  # Deseasonalised series
  si_vec   <- si_by_month[month_idx]
  deseas   <- actual / si_vec

  # Fit linear trend on deseasonalised values
  t_idx    <- 1:n
  trend_fit <- lm(deseas ~ t_idx)
  trend_fv  <- as.numeric(fitted(trend_fit))

  # Re-seasonalise
  fitted_vals <- trend_fv * si_vec

  # Next-period forecast (April 2026 = month 4)
  end_mo      <- end(ts_obj)[2]
  next_month  <- if (end_mo == 12) 1L else end_mo + 1L
  t_next      <- n + 1
  trend_next  <- as.numeric(predict(trend_fit, newdata = data.frame(t_idx = t_next)))
  next_fcst   <- trend_next * si_by_month[next_month]

  list(actual = actual, fitted = fitted_vals, next_fcst = next_fcst,
       si = si_by_month,
       method_label = "Seasonal Indices")
}

# ---------------------------------------------------------------------------
# 8. Additive Decomposition
#    In-sample fitted = trend + seasonal (irregular dropped).
# ---------------------------------------------------------------------------
method_additive_decomp <- function(ts_obj) {
  library(forecast)
  decomp <- decompose(ts_obj, type = "additive")

  trend_comp    <- as.numeric(decomp$trend)
  seasonal_comp <- as.numeric(decomp$seasonal)

  # Fitted values where trend is available
  fitted_vals <- trend_comp + seasonal_comp

  actual <- as.numeric(ts_obj)
  n      <- length(actual)

  # Extrapolate trend to next period using a linear fit on available trend values
  t_idx      <- 1:n
  valid_t    <- !is.na(trend_comp)
  trend_fit  <- lm(trend_comp[valid_t] ~ t_idx[valid_t])
  trend_next <- as.numeric(predict(trend_fit,
                                   newdata = data.frame(`t_idx[valid_t]` = n + 1,
                                                        check.names = FALSE)))

  # Re-extract the model using proper variable name
  trend_df   <- data.frame(x = t_idx[valid_t], y = trend_comp[valid_t])
  trend_fit2 <- lm(y ~ x, data = trend_df)
  trend_next <- as.numeric(predict(trend_fit2, newdata = data.frame(x = n + 1)))

  # Seasonal component for April (month 4)
  end_mo    <- end(ts_obj)[2]
  next_month <- if (end_mo == 12) 1L else end_mo + 1L
  freq      <- frequency(ts_obj)
  # seasonal repeats each year; take the value for the target month
  seas_next <- seasonal_comp[next_month]  # seasonal is periodic length n

  next_fcst <- trend_next + seas_next

  list(actual = actual, fitted = fitted_vals, next_fcst = next_fcst,
       method_label = "Additive Decomposition")
}

# ---------------------------------------------------------------------------
# 9. Multiplicative Decomposition
#    In-sample fitted = trend * seasonal (irregular dropped).
# ---------------------------------------------------------------------------
method_multiplicative_decomp <- function(ts_obj) {
  library(forecast)
  decomp <- decompose(ts_obj, type = "multiplicative")

  trend_comp    <- as.numeric(decomp$trend)
  seasonal_comp <- as.numeric(decomp$seasonal)
  fitted_vals   <- trend_comp * seasonal_comp
  actual        <- as.numeric(ts_obj)
  n             <- length(actual)

  # Linear trend extrapolation
  t_idx      <- 1:n
  valid_t    <- !is.na(trend_comp)
  trend_df   <- data.frame(x = t_idx[valid_t], y = trend_comp[valid_t])
  trend_fit  <- lm(y ~ x, data = trend_df)
  trend_next <- as.numeric(predict(trend_fit, newdata = data.frame(x = n + 1)))

  # Seasonal factor for next period
  end_mo     <- end(ts_obj)[2]
  next_month <- if (end_mo == 12) 1L else end_mo + 1L
  seas_next  <- seasonal_comp[next_month]

  next_fcst  <- trend_next * seas_next

  list(actual = actual, fitted = fitted_vals, next_fcst = next_fcst,
       method_label = "Multiplicative Decomposition")
}

# ---------------------------------------------------------------------------
# 10. Regression with Trend and Seasonal Dummy Variables
#     OLS: y ~ t + M2 + M3 + ... + M12  (January = reference month)
# ---------------------------------------------------------------------------
method_regression_seasonal <- function(ts_obj) {
  n      <- length(ts_obj)
  actual <- as.numeric(ts_obj)
  t_idx  <- 1:n
  month_idx <- as.integer(cycle(ts_obj))

  # Build seasonal dummies (M2 ... M12; January is reference)
  dummies <- as.data.frame(
    model.matrix(~ factor(month_idx))[, -1]
  )
  colnames(dummies) <- paste0("M", 2:12)

  df     <- data.frame(y = actual, t = t_idx, dummies)
  fit    <- lm(y ~ ., data = df)
  fitted_vals <- as.numeric(fitted(fit))

  # Forecast for next period (April 2026: t=172, M4=1, all others=0)
  end_mo     <- end(ts_obj)[2]
  next_month <- if (end_mo == 12) 1L else end_mo + 1L
  nd         <- as.data.frame(matrix(0, nrow = 1, ncol = ncol(dummies),
                                     dimnames = list(NULL, colnames(dummies))))
  nd$t <- n + 1
  if (next_month >= 2) nd[[paste0("M", next_month)]] <- 1

  next_fcst <- as.numeric(predict(fit, newdata = nd))

  list(actual = actual, fitted = fitted_vals, next_fcst = next_fcst,
       fit_obj = fit,
       method_label = "Regression (Trend + Seasonal Dummies)")
}
