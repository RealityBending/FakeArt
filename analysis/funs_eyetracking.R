# Interpolate -------------------------------------------------------------

# Data must have variables x (pixels from left), y (pixels from top), t (timestamp in seconds)
# screenwidth is used for normalization of velocity
interpolate_xy <- function(data, screenwidth, debug = FALSE) {
  # Interpolated interval (resampled to 100 Hz)
  t_new <- seq(min(data$t), max(data$t), by = 0.01)

  # Linear interpolation
  x_new <- approx(data$t, data$x, xout = t_new, rule = 2, ties = "ordered")$y
  y_new <- approx(data$t, data$y, xout = t_new, rule = 2, ties = "ordered")$y

  # Smooth (Exponential Moving Average - EMA)
  # x_new <- stats::filter(x_new, 0.2, method = "recursive")
  # y_new <- stats::filter(y_new, 0.2, method = "recursive")
  # Moving median (window = 11 to span ~3 frames of 30Hz raw data)
  x_new <- zoo::rollmedian(x_new, k = 11, fill = "extend")
  y_new <- zoo::rollmedian(y_new, k = 11, fill = "extend")

  out <- data.frame(t = t_new, x = x_new, y = y_new)

  # Debug plot
  if (debug) {
    p <- ggplot(data, aes(x = t, y = x)) +
      geom_line(color = "red") +
      geom_line(data = out, aes(x = t, y = x), color = "darkred") +
      geom_line(data = data, aes(x = t, y = y), color = "green") +
      geom_line(data = out, aes(x = t, y = y), color = "darkgreen")
    return(p)
  }

  # Compute velocity (based on normalized coordinates)

  xZ <- out$x / screenwidth
  yZ <- out$y / screenwidth
  distances <- sqrt(diff(xZ)^2 + diff(yZ)^2)
  out$velocity <- c(NA, distances / diff(out$t))

  # Sanitize
  # out$velocity <- pmin(out$velocity, 1000)

  out
}


# Detect Fixations --------------------------------------------------------

# - I-VT - Velocity-Threshold Identification
# - I-DT - Dispersion-Threshold Identification

# @param dispersion_threshold Maximum dispersion for a fixation
# screenwidth is used for normalization of velocity
detect_fixations_idt <- function(
  t, x, y, screenwidth,
  dispersion_threshold = 0.1,
  min_duration = 0.1
) {
  n <- length(t)
  if (n < 2) {
    return(rep("Saccade", n))
  } # not enough data

  # Estimate sampling interval
  dt <- median(diff(t), na.rm = TRUE)
  # Minimum number of samples for a fixation
  min_samples <- ceiling(min_duration / dt)

  # Normalize coordinates by screen width
  x <- x / unique(screenwidth)
  y <- y / unique(screenwidth)

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

get_spatial_entropy <- function(
  x, y,
  stim_left, stim_right, stim_top, stim_bottom,
  n_grid = 4
) {
  if (length(x) < 2 || all(is.na(x)) || all(is.na(y))) {
    return(NA)
  }

  x_breaks <- seq(stim_left, stim_right, length.out = n_grid + 1)
  y_breaks <- seq(stim_top, stim_bottom, length.out = n_grid + 1)

  x_bin <- cut(x, breaks = x_breaks, labels = FALSE, include.lowest = TRUE)
  y_bin <- cut(y, breaks = y_breaks, labels = FALSE, include.lowest = TRUE)

  valid <- !(is.na(x_bin) | is.na(y_bin))
  n_valid <- sum(valid)
  if (n_valid < 2) {
    return(NA)
  }

  cell_ids <- paste(x_bin[valid], y_bin[valid], sep = "-")
  counts <- table(cell_ids)

  if (length(counts) == 1) {
    return(0)
  }

  # Maximum achievable entropy is bounded by both the number of fixations
  # (can't spread n points across more than n cells) and the grid size.
  # Normalising by log2(n_grid^2) when n < n_grid^2 artificially deflates
  # the score for data-sparse trials, making them look "focused" by artefact.
  max_cells <- min(n_valid, n_grid^2L)
  max_entropy <- log2(max_cells) # = 0 only if max_cells == 1, guarded above

  entropy::entropy(counts, unit = "log2") / max_entropy
}

get_mean_jump <- function(x, y, screenwidth) {
  mean(sqrt(diff(x / screenwidth)^2 + diff(y / screenwidth)^2), na.rm = TRUE)
}

get_angular_variability <- function(x, y, screenwidth) {
  dx <- diff(x / screenwidth)
  dy <- diff(y / screenwidth)
  angles <- atan2(dy, dx)
  angle_diffs <- diff(angles)
  angle_diffs <- (angle_diffs + pi) %% (2 * pi) - pi # wrap to [-π, π]
  mean(abs(angle_diffs), na.rm = TRUE)
}


# Convex Hull Area
# Calculates the area of the smallest polygon that encloses all fixations.
# Returns area as a proportion of total screen area.
get_convex_hull_area <- function(x, y, screenwidth, screenheight) {
  # Remove NAs
  valid <- complete.cases(x, y)
  x <- x[valid]
  y <- y[valid]

  # Need at least 3 distinct points to form a polygon
  if (length(unique(x)) < 3 || length(unique(y)) < 3) {
    return(NA)
  }

  # Find indices of the convex hull vertices
  hpts <- chull(x, y)
  hpts <- c(hpts, hpts[1]) # Close the polygon

  # Calculate area using the Shoelace formula
  hull_x <- x[hpts]
  hull_y <- y[hpts]
  area_px <- 0.5 * abs(sum(hull_x[-length(hull_x)] * hull_y[-1] -
    hull_x[-1] * hull_y[-length(hull_y)]))

  # Normalize by screen size
  screen_area <- unique(screenwidth) * unique(screenheight)

  return(area_px / screen_area)
}


# Bivariate Contour Ellipse Area (BCEA)
# Calculates the area of an ellipse encompassing a given proportion (p)
# of the fixations, accounting for spatial spread and correlation.
# Standard p values are 0.68 (1 SD) or 0.95 (2 SD).
get_bcea <- function(x, y, screenwidth, screenheight, p = 0.68) {
  valid <- complete.cases(x, y)
  x <- x[valid]
  y <- y[valid]

  if (length(x) < 3) {
    return(NA)
  }

  # Chi-square value for the given probability (2 degrees of freedom for x,y)
  chisq_val <- qchisq(p, df = 2)

  # Standard deviations and Pearson correlation
  sd_x <- sd(x)
  sd_y <- sd(y)
  r <- cor(x, y)

  # Handle edge cases where correlation is perfectly 1 or -1 (straight line)
  if (is.na(r) || abs(r) >= 1) {
    return(0)
  }

  # BCEA Formula: pi * chisq * sd_x * sd_y * sqrt(1 - r^2)
  area_px <- pi * chisq_val * sd_x * sd_y * sqrt(1 - r^2)

  # Normalize by screen size
  screen_area <- unique(screenwidth) * unique(screenheight)

  return(area_px / screen_area)
}


# Spatial clustering: Gini of 2D KDE
# Compute a 2D kernel density estimate over the stimulus area, then measure
# how unequally density is distributed across cells using the Gini coefficient.
#
# Gini = 0: perfectly uniform density (gaze spread evenly across image)
# Gini → 1: all density in one cell (single unbroken fixation)
# Intermediate high values (0.6–0.8): a few tight clusters, clear structure
#
# Unlike peak/mean ratio, Gini is not sensitive to the absolute scale
# of the density surface, so it is comparable across trials and participants.

get_kde_gini <- function(x, y, stim_left, stim_right, stim_top, stim_bottom,
                         n_grid = 40) {
  within <- !is.na(x) & !is.na(y) &
    x >= stim_left & x <= stim_right &
    y >= stim_top & y <= stim_bottom
  x <- x[within]
  y <- y[within]
  if (length(x) < 10) {
    return(NA)
  }

  kde <- MASS::kde2d(
    x, y,
    n = n_grid,
    lims = c(stim_left, stim_right, stim_top, stim_bottom)
  )

  z <- sort(as.vector(kde$z)) # ascending sort required for Lorenz curve
  n <- length(z)

  # Standard Gini via Lorenz curve area
  2 * sum(seq_len(n) * z) / (n * sum(z)) - (n + 1) / n
}


# emporal clustering: velocity bimodality coefficient
# Clear fixation/saccade alternation produces a bimodal velocity distribution:
# a low-velocity mode (dwell) and a high-velocity mode (transit).
# Uniform or random gaze produces a unimodal, roughly exponential distribution.
#
# The Sarle bimodality coefficient BC = (skew² + 1) / (excess_kurt + correction)
# Reference threshold: BC > 0.555 (= 5/9, value for a uniform distribution)
# suggests bimodality. A normal distribution scores ~0.33.
#
# This is entirely in the time domain — no spatial parameters involved.

get_velocity_bimodality <- function(vel) {
  vel <- vel[!is.na(vel) & is.finite(vel) & vel > 0]
  n <- length(vel)
  if (n < 10) {
    return(NA)
  }

  s <- sd(vel)
  if (s == 0) {
    return(NA)
  }

  z <- (vel - mean(vel)) / s
  skew <- mean(z^3)
  kurt <- mean(z^4) - 3 # excess kurtosis

  # Finite-sample correction on kurtosis (DeCarlo 1997)
  kurt_c <- kurt + 3 * (n - 1)^2 / ((n - 2) * (n - 3))

  (skew^2 + 1) / kurt_c
}



# Precision profile
# Continuous analogue of "dispersion threshold," without any detection or
# expansion logic. Computes the I-DT dispersion statistic in a small fixed
# rolling window across the whole trial and summarizes the resulting
# distribution. The minimum is "the tightest gaze got at its best moment,"
# which is a candidate explanation for effects that only show up at very
# low dispersion thresholds (i.e. only the most precise instants matter,
# regardless of how long they last).
#
# window: number of samples in the rolling window (15 ~= 150ms at 100Hz,
# matched to the low end of the min_duration range already explored).
get_dispersion_profile <- function(x, y, screenwidth, window = 15) {
  n <- length(x)
  if (n < window) {
    return(c(
      Precision_Min = NA_real_, Precision_P10 = NA_real_,
      Precision_Median = NA_real_, Precision_IQR = NA_real_
    ))
  }

  xz <- x / screenwidth
  yz <- y / screenwidth

  disp <- zoo::rollapply(
    seq_len(n),
    width = window,
    align = "center",
    fill = NA,
    FUN = function(idx) {
      (max(xz[idx], na.rm = TRUE) - min(xz[idx], na.rm = TRUE)) +
        (max(yz[idx], na.rm = TRUE) - min(yz[idx], na.rm = TRUE))
    }
  )

  c(
    Precision_Min    = suppressWarnings(min(disp, na.rm = TRUE)),
    Precision_P10    = unname(quantile(disp, 0.10, na.rm = TRUE)),
    Precision_Median = median(disp, na.rm = TRUE),
    Precision_IQR    = IQR(disp, na.rm = TRUE)
  )
}


# Run-length structure
# Continuous analogue of "min_duration," without enforcing any minimum.
# Segments the trial into slow/fast episodes using the fixed velocity
# threshold already used for RawGaze_LowVelProp, then describes the
# episode structure itself (frequency, typical length, regularity) rather
# than collapsing it into a single proportion.
#
# vel_thresh should match LOW_VEL_THRESH used elsewhere in the pipeline.
get_runlength_stats <- function(velocity, t, vel_thresh = 0.05) {
  ok <- !is.na(velocity) & is.finite(velocity)
  velocity <- velocity[ok]
  t <- t[ok]
  n <- length(velocity)

  empty <- c(
    Runs_N = NA_real_, Runs_PerSecond = NA_real_,
    Runs_DurationMean = NA_real_, Runs_DurationMedian = NA_real_,
    Runs_DurationMax = NA_real_, Runs_DurationCV = NA_real_
  )
  if (n < 5) {
    return(empty)
  }

  slow <- velocity < vel_thresh
  r <- rle(slow)
  run_durations <- r$lengths[r$values] / 100 # 100Hz -> seconds
  total_time <- max(t) - min(t)

  if (length(run_durations) == 0 || total_time <= 0) {
    return(empty)
  }

  c(
    Runs_N              = length(run_durations),
    Runs_PerSecond      = length(run_durations) / total_time,
    Runs_DurationMean   = mean(run_durations),
    Runs_DurationMedian = median(run_durations),
    Runs_DurationMax    = max(run_durations),
    Runs_DurationCV     = sd(run_durations) / mean(run_durations)
  )
}


# Precision x persistence coupling
# A single continuous stand-in for the dispersion x min_duration interaction
# the grid search is implicitly fitting one cell at a time. For each slow
# episode (same segmentation as get_runlength_stats), computes its own
# local dispersion and its duration, then correlates the two across
# episodes within a trial.
#
#   Positive coupling -> gaze sprawls the longer it lingers (loose, drifting dwell)
#   Negative coupling -> gaze tightens the longer it lingers (settling in)
#   ~0                 -> precision and persistence are independent for this trial
get_precision_persistence_coupling <- function(x, y, t, velocity, screenwidth,
                                               vel_thresh = 0.05) {
  ok <- !is.na(velocity) & is.finite(velocity) & !is.na(x) & !is.na(y)
  x <- x[ok]
  y <- y[ok]
  t <- t[ok]
  velocity <- velocity[ok]
  if (length(velocity) < 10) {
    return(NA_real_)
  }

  slow <- velocity < vel_thresh
  r <- rle(slow)
  ends <- cumsum(r$lengths)
  starts <- ends - r$lengths + 1
  keep <- which(r$values)
  if (length(keep) < 5) {
    return(NA_real_)
  }

  disp <- rep(NA_real_, length(keep))
  dur <- rep(NA_real_, length(keep))
  for (i in seq_along(keep)) {
    idx <- starts[keep[i]]:ends[keep[i]]
    if (length(idx) < 2) next
    xz <- x[idx] / screenwidth
    yz <- y[idx] / screenwidth
    disp[i] <- (max(xz) - min(xz)) + (max(yz) - min(yz))
    dur[i] <- t[max(idx)] - t[min(idx)]
  }

  ok2 <- !is.na(disp) & !is.na(dur)
  if (sum(ok2) < 5) {
    return(NA_real_)
  }
  suppressWarnings(cor(disp[ok2], dur[ok2], method = "spearman"))
}


# Spread restricted to dwell periods
# Reuses your existing get_bcea() but applied only to samples below the
# velocity threshold, i.e. spatial spread of where gaze pauses, as opposed
# to where it travels in transit. Comparing this to a BCEA/convex-hull
# computed on ALL raw points (just call get_bcea(dfeye$x, dfeye$y, ...)
# directly, no new function needed) tells you how much of the total
# roaming happens during pauses vs. during saccadic transit -- a
# parameter-free analogue of "high dispersion threshold lets sprawling
# dwells count as fixations."
get_slow_spread <- function(x, y, velocity, screenwidth, screenheight,
                            vel_thresh = 0.05, p = 0.68) {
  slow <- velocity < vel_thresh & !is.na(velocity) & !is.na(x) & !is.na(y)
  if (sum(slow) < 3) {
    return(NA_real_)
  }
  get_bcea(x[slow], y[slow], screenwidth, screenheight, p = p)
}
