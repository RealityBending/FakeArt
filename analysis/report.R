# Presentation helpers shared by 3_models.qmd, 4_memory.qmd and
# 5_realitydeterminants.qmd.
# server/estimates.R turns fits into numbers (on the cluster); this turns those
# numbers into output. Not in server/ because `./hpc push` mirrors server/*.R.

# Read models/<dir>/<name>.rds, written on the cluster by `./hpc extract`
# (dir = "estimates") or `./hpc individual` (dir = "individual").
read_estimates <- function(names, dir = "estimates") {
  job <- if (dir == "estimates") "extract" else dir
  lapply(setNames(nm = names), function(o) {
    f <- file.path("models", dir, paste0(o, ".rds"))
    if (!file.exists(f)) {
      stop(f, " is missing. Run `./hpc ", job, " ", o, "` in analysis/server, ",
           "then `./hpc pull '", dir, "/*.rds'`.", call. = FALSE)
    }
    readRDS(f)
  })
}

# Which fit and extraction each set of estimates came from.
provenance_table <- function(estimates) {
  knitr::kable(
    Filter(\(x) !all(is.na(x)), data.frame(
      Model = names(estimates),
      Fit = vapply(estimates, function(e) if (is.null(e$fit_file)) NA_character_ else e$fit_file, ""),
      Draws = vapply(estimates, function(e) e$ndraws, numeric(1)),
      Max_Rhat = vapply(estimates, function(e) e$diag$Max_Rhat %||% NA_real_, numeric(1)),
      Extracted = vapply(estimates, function(e) format(e$created, "%Y-%m-%d %H:%M"), ""),
      row.names = NULL
    )),
    caption = "Provenance of the estimates read by this report.", format = "pipe"
  )
}

make_asis <- function(...) knitr::asis_output(paste(unlist(list(...)), collapse = "\n"))

# A coloured gt table plus the same table as folded Markdown (for text readers
# of the .html.md twin). `cols` selects and orders the columns; an "Effect"
# column, if present, is colour-coded.
make_tables <- function(df, cols, title) {
  tbl <- as.data.frame(df)[cols]
  g <- gt::gt(tbl, groupname_col = if ("Contrast" %in% cols) "Contrast" else NULL) |>
    gt::tab_header(title = title) |>
    gt::opt_stylize(style = 2, color = "gray") |>
    gt::tab_options(table.font.size = gt::px(13), heading.align = "left")
  if ("Effect" %in% cols) {
    g <- g |>
      gt::tab_style(style = gt::cell_fill(color = "#E8F5E9"), locations = gt::cells_body(rows = Effect == "Positive")) |>
      gt::tab_style(style = gt::cell_fill(color = "#FFEBEE"), locations = gt::cells_body(rows = Effect == "Negative")) |>
      gt::tab_style(style = gt::cell_text(color = "#9E9E9E"), locations = gt::cells_body(rows = Effect == "n.s."))
  }
  make_asis(as.character(knitr::knit_print(g)), "", make_markdown(tbl, title), "")
}

# The folded Markdown table on its own.
make_markdown <- function(tbl, title) {
  paste(
    c(
      sprintf('::: {.callout-note collapse="true" title="%s (Markdown table, for text readers)"}', title),
      "",
      knitr::kable(as.data.frame(tbl), format = "pipe", row.names = FALSE),
      "",
      ":::"
    ),
    collapse = "\n"
  )
}


# CHOCO figures ---------------------------------------------------------------
# `data` (the trial file, for the observed histogram) and `palette` (colours per
# Condition) default to the calling notebook's `dftask` and `cols`.

# CHOCO density per condition from the marginal parameters (est$marginal).
# `adjust` scales the curve to match the histogram.
get_marginal_densities <- function(dat_par, adjust = 2) {
  dat_dens <- data.frame()
  dat_annot <- data.frame()
  for (row in 1:nrow(dat_par)) {
    x <- seq(0, 1, length.out = 201)
    y <- cogmod::dcogmod_choco(
      x = x, p = dat_par$Mu[row], confleft = dat_par$Confleft[row], confright = dat_par$Confright[row],
      precleft = dat_par$Precleft[row], precright = dat_par$Precright[row],
      pmid = dat_par$Pmid[row], pex = dat_par$Pex[row], bex = dat_par$Bex[row]
    )
    y <- y * adjust
    dat_dens <- rbind(dat_dens, data.frame(Condition = dat_par$Condition[row], x = x, y = y))

    # Modes of each half, sized by the probability of that half
    dat_annot <- rbind(dat_annot, data.frame(
      Condition = dat_par$Condition[row],
      right_y = max(y[x > 0.5]), left_y = max(y[x < 0.5]),
      right_x = 0.5 + x[which.max(y[x > 0.5])], left_x = x[which.max(y[x < 0.5])],
      right_size = dat_par$Mu[row], left_size = 1 - dat_par$Mu[row]
    ))
  }

  offset <- 1 - (rev(as.numeric(dat_par$Condition)) / 3)
  max_y <- max(dat_dens$y)
  dat_par$Mean_y <- 1.2 * max_y - offset * (1.2 * max_y - max_y)

  list(par=dat_par, dens=dat_dens, annot=dat_annot)
}

# The same per emotion quadrant (est$marginal_emo)
get_marginal_densities_emo <- function(dat_par, adjust = 2, emotion_levels = levels(dftask$Emotion)) {
  out <- list(par = data.frame(), dens = data.frame(), annot = data.frame())
  for (emo in unique(dat_par$Emotion)) {
    dat <- get_marginal_densities(dat_par[dat_par$Emotion == emo, ], adjust = adjust)
    dat[["dens"]]$Emotion <- emo
    dat[["annot"]]$Emotion <- emo
    for (el in c("par", "dens", "annot")) out[[el]] <- rbind(out[[el]], dat[[el]])
  }
  lv <- rev(emotion_levels)
  out$dens$Emotion <- forcats::fct_relevel(out$dens$Emotion, lv)
  out$annot$Emotion <- forcats::fct_relevel(out$annot$Emotion, lv)
  out
}

get_choco_plot <- function(dat, title = "Beauty", observed = title, xlabs = c("0% - Ugly", "100% - Beautiful"),
                           facet = NULL, data = dftask, palette = cols, ...) {
  dat_obs <- data
  dat_obs$obs <- dat_obs[[observed]]
  dat_obs <- dat_obs[!is.na(dat_obs$obs), ]

  p <- dat$dens |>
    ggplot(aes(x = x, y = y)) +
    geom_histogram(data = dat_obs, aes(x = obs, y = after_stat(density)), alpha = 0.1, bins = 47) +
    geom_segment(data = dat$annot, aes(
      x = right_x, xend = right_x,
      y = 0, yend = right_y, color = Condition
    ), linewidth = 0.5, linetype = "dashed") +
    geom_segment(data = dat$annot, aes(
      x = left_x, xend = left_x,
      y = 0, yend = left_y, color = Condition
    ), linewidth = 0.5, linetype = "dashed") +
    geom_point(data = dat$annot, aes(x = right_x, y = 0, color = Condition, size = right_size * 6)) +
    geom_point(data = dat$annot, aes(x = left_x, y = 0, color = Condition, size = left_size * 6)) +
    geom_pointrange(data = dat$par, aes(x = Mean, y = Mean_y, xmin = Mean_low, xmax = Mean_high, color = Condition), linewidth = 0.5) +
    geom_line(aes(color = Condition), linewidth = 1.3) +
    labs(y = "Likelihood of Response", title = title) +
    scale_size_identity() +
    scale_color_manual(values = palette) +
    scale_x_continuous(breaks = c(0, 0.25, 0.5, 0.75, 1),
                       labels = c(xlabs[1], "25%", "50%",  "75%", xlabs[2])) +
    theme_minimal() +
    theme(axis.text.y = element_blank(),
          axis.title.x = element_blank(),
          axis.title.y = element_blank(),
          plot.title = element_text(face = "bold"))

  if(!is.null(facet)) p <- p + facet_wrap(facet, ...)
  p
}
