# Presentation helpers shared by 3_models.qmd and 4_memory.qmd.
# server/estimates.R turns fits into numbers (on the cluster); this turns those
# numbers into output. Not in server/ because `./hpc push` mirrors server/*.R.

# Read models/estimates/<name>.rds (written by `./hpc extract`, fetched with
# `./hpc pull 'estimates/*.rds'`).
read_estimates <- function(names) {
  lapply(setNames(nm = names), function(o) {
    f <- file.path("models", "estimates", paste0(o, ".rds"))
    if (!file.exists(f)) {
      stop(f, " is missing. Run `./hpc extract ", o, "` in analysis/server, ",
           "then `./hpc pull 'estimates/*.rds'`.", call. = FALSE)
    }
    readRDS(f)
  })
}

# Which fit and extraction each set of estimates came from.
provenance_table <- function(estimates) {
  knitr::kable(
    data.frame(
      Model = names(estimates),
      Fit = vapply(estimates, function(e) if (is.null(e$fit_file)) NA_character_ else e$fit_file, ""),
      Draws = vapply(estimates, function(e) e$ndraws, numeric(1)),
      Max_Rhat = vapply(estimates, function(e) e$diag$Max_Rhat, numeric(1)),
      Extracted = vapply(estimates, function(e) format(e$created, "%Y-%m-%d %H:%M"), ""),
      row.names = NULL
    ),
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
