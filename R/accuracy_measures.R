# =============================================================================
# accuracy_measures.R
# Computes the required forecast accuracy and monitoring measures.
# =============================================================================

#' Compute accuracy metrics from actual and fitted vectors.
#'
#' @param actual  Numeric vector of actual observations.
#' @param fitted  Numeric vector of in-sample fitted values (same length as actual).
#' @return Named numeric vector: Bias, MAD, MSE, MAPE, RSFE, Tracking_Signal.
compute_accuracy <- function(actual, fitted) {
  e    <- actual - fitted              # forecast errors
  n    <- length(e)

  bias <- mean(e)                      # Mean Error (Bias)
  mad  <- mean(abs(e))                 # Mean Absolute Deviation
  mse  <- mean(e^2)                    # Mean Squared Error
  mape <- mean(abs(e / actual)) * 100  # Mean Absolute Percent Error (%)
  rsfe <- sum(e)                       # Running Sum of Forecast Errors (final value)

  ts   <- if (mad > 0) rsfe / mad else NA_real_  # Tracking Signal

  c(Bias = round(bias, 4),
    MAD  = round(mad,  4),
    MSE  = round(mse,  4),
    MAPE = round(mape, 4),
    RSFE = round(rsfe, 4),
    Tracking_Signal = round(ts, 4))
}

#' Build the full comparison table for all candidate methods.
#'
#' @param results_list  Named list where each element contains $actual, $fitted, $next_fcst.
#' @return data.frame with one row per method and columns for each accuracy measure
#'         plus the next-period forecast.
build_comparison_table <- function(results_list) {
  rows <- lapply(names(results_list), function(method_name) {
    res <- results_list[[method_name]]

    # Remove NA pairs before computing (some methods lose obs at boundaries)
    valid  <- !is.na(res$actual) & !is.na(res$fitted)
    actual <- res$actual[valid]
    fitted <- res$fitted[valid]

    if (length(actual) < 2) {
      return(data.frame(
        Method          = method_name,
        Bias            = NA, MAD = NA, MSE = NA, MAPE = NA,
        RSFE            = NA, Tracking_Signal = NA,
        Next_Period_Fcst= round(res$next_fcst, 2),
        stringsAsFactors = FALSE
      ))
    }

    acc <- compute_accuracy(actual, fitted)
    data.frame(
      Method           = method_name,
      Bias             = acc["Bias"],
      MAD              = acc["MAD"],
      MSE              = acc["MSE"],
      MAPE             = acc["MAPE"],
      RSFE             = acc["RSFE"],
      Tracking_Signal  = acc["Tracking_Signal"],
      Next_Period_Fcst = round(res$next_fcst, 2),
      stringsAsFactors = FALSE,
      row.names        = NULL
    )
  })

  do.call(rbind, rows)
}
