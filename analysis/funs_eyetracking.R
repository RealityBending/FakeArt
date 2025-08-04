
# Interpolate -------------------------------------------------------------



# Data must have variables x (pixels from left), y (pixels from top), t (timestamp in seconds)
interpolate_xy <- function(data, debug=FALSE) {
  # Interpolated interval (resampled to 100 Hz)
  t_new <- seq(min(data$t), max(data$t), by = 0.01)

  # Linear interpolationt
  x_new <- approx(data$t, data$x, xout = t_new, rule = 2, ties = "ordered")$y
  y_new <- approx(data$t, data$y, xout = t_new, rule = 2, ties = "ordered")$y

  # Smooth (Exponential Moving Average - EMA)
  # x_new <- stats::filter(x_new, 0.2, method = "recursive")
  # y_new <- stats::filter(y_new, 0.2, method = "recursive")
  # Moving average (window = 3)
  x_new <- zoo::rollmean(x_new, 3, fill = "extend")
  y_new <- zoo::rollmean(y_new, 3, fill = "extend")

  out <- data.frame(t = t_new, x = x_new, y = y_new)

  # Debug plot
  if(debug) {
    ggplot(data, aes(x = t, y = x)) +
      geom_line(color = "red") +
      geom_line(data = out, aes(x = t, y = x), color = "darkred") +
      geom_line(data = data, aes(x = t, y = y), color = "green") +
      geom_line(data = out, aes(x = t, y = y), color = "darkgreen")
  }

  # Compute velocity
  distances <- sqrt(diff(out$x)^2 + diff(out$y)^2)
  out$velocity <- c(NA, distances / diff(out$t))

  # Sanitize
  out$velocity <- pmin(out$velocity, 10000)

  out
}


# Detect Fixations --------------------------------------------------------

# - I-VT - Velocity-Threshold Identification
# - I-DT - Dispersion-Threshold Identification

detect_fixations_idt <- function(t, x, y, dispersion_threshold = 100, min_duration = 0.1) {
  n <- length(t)
  if (n < 2) return(rep("Saccade", n))  # not enough data

  # Estimate sampling interval
  dt <- median(diff(t), na.rm = TRUE)
  # Minimum number of samples for a fixation
  min_samples <- ceiling(min_duration / dt)

  labels <- rep(NA_character_, n)
  start_idx <- 1
  fixation_id <- 1

  while (start_idx + min_samples - 1 <= n) {
    end_idx <- start_idx + min_samples - 1
    x_win <- x[start_idx:end_idx]
    y_win <- y[start_idx:end_idx]

    dispersion <- (max(x_win, na.rm = TRUE) - min(x_win, na.rm = TRUE)) +
      (max(y_win, na.rm = TRUE) - min(y_win, na.rm = TRUE))

    if (dispersion <= dispersion_threshold) {
      # Expand window while dispersion remains low
      while (end_idx < n) {
        end_idx <- end_idx + 1
        x_win <- x[start_idx:end_idx]
        y_win <- y[start_idx:end_idx]
        dispersion <- (max(x_win, na.rm = TRUE) - min(x_win, na.rm = TRUE)) +
          (max(y_win, na.rm = TRUE) - min(y_win, na.rm = TRUE))
        if (dispersion > dispersion_threshold) {
          end_idx <- end_idx - 1
          break
        }
      }

      labels[start_idx:end_idx] <- paste0("Fixation_", fixation_id)
      fixation_id <- fixation_id + 1
      start_idx <- end_idx + 1
    } else {
      labels[start_idx] <- "Saccade"
      start_idx <- start_idx + 1
    }
  }

  # Fill remaining unlabeled samples as saccades
  unlabeled <- which(is.na(labels))
  labels[unlabeled] <- "Saccade"

  labels
}



# Features ----------------------------------------------------------------


get_spatial_entropy <- function(x, y,
                                stim_left, stim_right,
                                stim_top, stim_bottom,
                                n_grid = 10) {
  # If all inputs are NA or too short
  if (length(x) < 2 || all(is.na(x)) || all(is.na(y))) return(NA_real_)

  # Define grid edges
  x_breaks <- seq(stim_left, stim_right, length.out = n_grid + 1)
  y_breaks <- seq(stim_top, stim_bottom, length.out = n_grid + 1)

  # Bin fixations
  x_bin <- cut(x, breaks = x_breaks, labels = FALSE, include.lowest = TRUE)
  y_bin <- cut(y, breaks = y_breaks, labels = FALSE, include.lowest = TRUE)

  # Remove NAs from binned fixations (outside bounds)
  valid <- !(is.na(x_bin) | is.na(y_bin))
  if (sum(valid) < 2) return(NA_real_)  # Not enough valid data to compute entropy

  # Create cell IDs
  cell_ids <- paste(x_bin[valid], y_bin[valid], sep = "-")
  counts <- table(cell_ids)

  # If all in same cell, entropy is 0
  if (length(counts) == 1) return(0)

  # Compute normalized Shannon entropy
  # This gives a normalized entropy between 0 and 1, where:
  # 0 = all fixations in one cell (focused/narrow)
  # 1 = uniform distribution across the grid (exploratory/wide)
  entropy::entropy(counts, unit = "log2") / log2(n_grid^2)
}

get_mean_jump <- function(x, y) {
  mean(sqrt(diff(x)^2 + diff(y)^2), na.rm = TRUE)
}

get_angular_variability <- function(x, y) {
  dx <- diff(x)
  dy <- diff(y)
  angles <- atan2(dy, dx)
  mean(abs(diff(angles)), na.rm = TRUE)
}
