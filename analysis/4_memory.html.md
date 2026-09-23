---
title: "FakeArt - Memory Results"
editor: source
editor_options: 
  chunk_output_type: console
format:
  html:
    code-fold: true
    self-contained: false
    toc: true
    keep-md: true
---

<!-- Estimates are computed on the cluster (`./hpc extract`, see server/estimates.R) and read from models/estimates/. -->

## Data Preparation


::: {.cell}

```{.r .cell-code  code-fold="false"}
library(tidyverse)
library(easystats)
library(patchwork)

df <- read.csv("../data/data_memory_task.csv") |>
  mutate(Condition = fct_relevel(Condition, "Human Original", "Human Forgery", "AI-Generated", "New Items"),
         AnswerCondition = fct_relevel(AnswerCondition, "Human Original", "Human Forgery", "AI-Generated", "Not recognized"),
         AnswerBelief = fct_relevel(AnswerBelief, "Human Original", "Human Forgery", "AI Original", "AI Copy", "Not recognized"),
         Belief = fct_relevel(Belief, "Human Original", "Human Forgery", "AI Original", "AI Copy", "None"))

dfsub <- read.csv("../data/data_participants.csv") |> 
  filter(Participant %in% df$Participant)

cols <- c(
  # Condition
  "Human Original" = "#F51D56",
  "Human Forgery" = "#F5A41D",
  "AI-Generated" = "#1D9AF5",
  "AI Original" = "#1D9AF5",
  "AI Copy" = "#4CAF50",
  "Not recognized" = "#607D8B",
  # Style
  "Abstract and Avant-garde" = "#E41A1C", 
  "Classical" = "#377EB8", 
  "Impressionist and Expressionist" = "#4DAF4A",
  "Romantic and Realism" = "#FF7F00"
)

source("server/estimates.R") # memory_info
source("report.R")           # make_asis(), make_tables(), make_markdown(), read_estimates()

estimates <- read_estimates(names(memory_info))
provenance_table(estimates)
```

::: {.cell-output-display}


Table: Provenance of the estimates read by this report.

|Model                 |Fit                       | Draws| Max_Rhat|Extracted        |
|:---------------------|:-------------------------|-----:|--------:|:----------------|
|MemoryCondition       |MemoryCondition.rds       |  4000|    1.131|2026-09-22 20:32 |
|MemoryBelief          |MemoryBelief.rds          |  4000|    1.043|2026-09-22 20:33 |
|MemoryConditionBelief |MemoryConditionBelief.rds |  4000|    1.031|2026-09-23 15:50 |


:::
:::


## How to read this report

Three Bayesian categorical mixed models of what participants remembered in the
follow-up session (220 participants × 96 items = 21,120 rows: 48 seen in Phase 1,
48 new).

| model | outcome | predictor | levels of the predictor |
| --- | --- | --- | --- |
| **Memory of Condition** | `AnswerCondition`: which label the participant recalls being shown | `Condition`: the label actually shown in Phase 1 | Human Original, Human Forgery, AI-Generated, **New Items** (never seen) |
| **Memory of Beliefs** | `AnswerBelief`: what the participant recalls believing the artwork was | `Belief`: what they actually reported believing in Phase 2 | Human Original, Human Forgery, AI Original, AI Copy, None |
| **Memory of the Condition by Belief** | `AnswerCondition` | `Condition` **+** `Belief` (additive; old items with a recorded belief only, 10,416 rows) | Belief: Human Original, Human Forgery, AI Original, AI Copy |

All outcomes include **Not recognized** (item judged "new"): correct for
`New Items`, forgetting for the seen levels. The third model asks whether the
recalled label is reconstructed from one's own Phase-2 belief: its `Belief`
means and contrasts are averaged over the label actually shown (computed over
the observed trials, see `memory_observed()` in `server/estimates.R`), so a
`Belief` effect is the effect of the belief with the label held constant.

Each section: figure of the probability of each answer per level, convergence,
marginal means, contrasts (coloured tables of interest + the complete set), and
an auto-generated summary. Every table has a folded Markdown twin; the Summary
section writes `data/results_memory_contrasts.csv` and
`data/results_memory_means.csv`.

Estimates are probabilities and contrasts (`Level1 - Level2`) differences of
probabilities, reported in percentage points as posterior medians with 95% CI
and probability of direction (`pd`). "Credible" = CI excludes 0 (no
multiplicity correction).

## Delay


::: {.cell}

```{.r .cell-code}
dfsub |> 
  ggplot(aes(x=Delay)) +
  geom_histogram(bins=30) +
  theme_minimal()
```

::: {.cell-output-display}
![](4_memory_files/figure-html/unnamed-chunk-2-1.png){width=672}
:::
:::


The mean and median days between the two experiments were 46.95 and 47.00, respectively.

## Memory of Condition

### Main Model


::: {.cell}

```{.r .cell-code}
# Dodging order of the answers in the figures
make_group <- function(resp, covariate = NULL) {
  group <- case_when(  
    resp == "Not recognized" ~ 0,
    resp == "Human Original" ~ 1,
    resp == "AI-Generated" ~ 2,
    resp == "AI Original" ~ 2,
    resp == "Human Forgery" ~ 3,
    resp == "AI Copy" ~ 4,
    .default = NA)
  
  if(!is.null(covariate)) {
    covariate <- insight::format_value(normalize(covariate), style_positive="plus")
    group <- paste0(group, covariate)
  }
  group
}

dat_cond1 <- estimates$MemoryCondition$means |>
  mutate(group = make_group(Response))

p_cond1 <- dat_cond1 |> 
  ggplot(aes(x=Condition,  y = Median, color = Response)) +
  geom_line(aes(group=group), position = position_dodge(width=0.1), linewidth = 1,
            show.legend = FALSE) +
  geom_pointrange(aes(group=group, ymin = CI_low, ymax = CI_high), position = position_dodge(width=0.1),
                  key_glyph = "point") +
  scale_y_continuous(label = scales::percent, limits = c(0,1), expand = c(0, 0)) +
  scale_color_manual(values = cols) +
  guides(color = guide_legend(override.aes = list(size = 3))) +
  labs(y="Proportion of answers", color = "Answer", x =  "Experimental Condition",
       title = "Memory of the Experimental Condition") +
  theme_minimal() 
p_cond1
```

::: {.cell-output-display}
![](4_memory_files/figure-html/unnamed-chunk-3-1.png){width=672}
:::
:::



::: {.cell}

```{.r .cell-code}
make_contrasts <- function(c, answer=NULL, condition=NULL, title="Marginal Contrasts") {

  if(!is.null(answer)) {
    c <- filter(c, str_detect(Response1, answer) & str_detect(Response2, answer))
  }
  if(!is.null(condition)) {
    c <- filter(c, str_detect(Level1, condition) & str_detect(Level2, condition))
  }

  # Collapse a constant Response/Level pair into one Category column
  if(length(unique(c$Response1)) == 1 & all(c$Response1 == c$Response2)) {
    c <- cbind(data.frame("Category" = c$Response1[1]), c)
    c$Response1 <- NULL
    c$Response2 <- NULL
  }
  if(length(unique(c$Level1)) == 1 & all(c$Level1 == c$Level2)) {
    c <- cbind(data.frame("Category" = c$Level1[1]), c)
    c$Level1 <- NULL
    c$Level2 <- NULL
  }

  c <- arrange(c, desc(abs(Median)))
  t <- format_table(c, zap_small = TRUE)

  t$effectsize <- as.numeric(c$Median)
  t$sig <- as.numeric(c$pd)

  g <- gt::gt(t) |>
    gt::data_color(columns = "effectsize", target_columns = "Median", method = "numeric",
palette = c("red", "red", "white", "green", "green"), domain = c(-0.7, 0.7)) |>
    gt::data_color(columns = "sig", target_columns = "pd", fn = \(x) {
      ifelse(x > 0.99, "#FFC107", ifelse(x > 0.97, "#FFEB3B", ifelse(x > 0.95, "#FFF59D", "white")))
    }) |>
    gt::cols_hide(c("effectsize", "sig")) |>
    gt::tab_header(title = title)

  # Markdown twin: colour coding replaced by an Effect column
  md <- t[setdiff(names(t), c("effectsize", "sig"))]
  md$Effect <- ifelse(sign(c$CI_low) != sign(c$CI_high), "n.s.",
                      ifelse(c$Median < 0, "Negative", "Positive"))
  make_asis(as.character(knitr::knit_print(g)), "", make_markdown(md, title), "")
}

# Convergence, marginal means and the complete contrast set
make_memory_tables <- function(est) {
  means_fmt <- as.data.frame(est$means)[c(est$by, "Response", "Median", "CI_low", "CI_high")]
  num <- vapply(means_fmt, is.numeric, logical(1))
  means_fmt[num] <- lapply(means_fmt[num], insight::format_value, zap_small = TRUE)

  all_con <- as.data.frame(est$contrasts)
  all_con$Effect <- ifelse(sign(all_con$CI_low) != sign(all_con$CI_high), "n.s.",
                           ifelse(all_con$Median < 0, "Negative", "Positive"))
  all_fmt <- all_con[c("Level1", "Response1", "Level2", "Response2", "Median", "CI_low", "CI_high", "pd", "Effect")]
  n <- vapply(all_fmt, is.numeric, logical(1))
  all_fmt[n] <- lapply(all_fmt[n], insight::format_value, zap_small = TRUE)

  make_asis(
    make_tables(est$diag,
                c("Model", "Family", "N_obs", "N_participants", "Chains", "Draws",
                  "Max_Rhat", "Min_ESS_ratio", "Divergent_pct", "Criterion"),
                sprintf("%s: convergence", est$label)),
    make_tables(means_fmt, names(means_fmt),
                sprintf("%s: probability of each answer per %s (marginal means)", est$label, est$by)),
    # Markdown only (120-300 rows)
    make_markdown(all_fmt, sprintf("%s: all %d contrasts", est$label, nrow(all_fmt)))
  )
}

# Generated summary of the credible same-answer contrasts
make_memory_summary <- function(est) {
  d <- as.data.frame(est$contrasts)
  d <- d[d$Response1 == d$Response2, ]
  d$Credible <- sign(d$CI_low) == sign(d$CI_high)
  pp <- function(x) insight::format_value(100 * x)
  out <- c(sprintf(
    "**%s.** Each row of the model is the probability of one answer. The differences below are between %s levels *within* the same answer, in percentage points, as posterior medians with 95%% CI; `pd` is the probability of direction. An effect is called credible when the CI excludes 0. Contrasts *across* answers are in the full table above.",
    est$label, est$by), "")
  for (r in unique(d$Response1)) {
    dr <- d[d$Response1 == r, ]
    cred <- dr[dr$Credible, ]
    if (nrow(cred) == 0) {
      out <- c(out, sprintf("- **%s**: no credible difference between any pair of %s levels.", r, est$by))
      next
    }
    cred <- cred[order(-abs(cred$Median)), ]
    out <- c(out, sprintf("- **%s**: %s.%s", r,
      paste(sprintf("%s - %s %s pp [%s, %s]", cred$Level1, cred$Level2,
                    pp(cred$Median), pp(cred$CI_low), pp(cred$CI_high)), collapse = "; "),
      if (nrow(cred) < nrow(dr)) sprintf(" The other %d pair(s) are not credible.", nrow(dr) - nrow(cred)) else ""))
  }
  make_asis("", '::: {.callout-tip title="Summary of credible effects (generated from the tables above)"}',
            "", out, "", ":::", "")
}
```
:::



::: {.cell}

```{.r .cell-code}
make_memory_tables(estimates$MemoryCondition)
```

::: {.cell-output-display}

```{=html}
<div id="chsiuddwnz" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#chsiuddwnz table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#chsiuddwnz thead, #chsiuddwnz tbody, #chsiuddwnz tfoot, #chsiuddwnz tr, #chsiuddwnz td, #chsiuddwnz th {
  border-style: none;
}

#chsiuddwnz p {
  margin: 0;
  padding: 0;
}

#chsiuddwnz .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 13px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 3px;
  border-top-color: #D5D5D5;
  border-right-style: solid;
  border-right-width: 3px;
  border-right-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 3px;
  border-bottom-color: #D5D5D5;
  border-left-style: solid;
  border-left-width: 3px;
  border-left-color: #D5D5D5;
}

#chsiuddwnz .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}

#chsiuddwnz .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#chsiuddwnz .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#chsiuddwnz .gt_heading {
  background-color: #FFFFFF;
  text-align: left;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#chsiuddwnz .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#chsiuddwnz .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#chsiuddwnz .gt_col_heading {
  color: #FFFFFF;
  background-color: #000000;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#chsiuddwnz .gt_column_spanner_outer {
  color: #FFFFFF;
  background-color: #000000;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#chsiuddwnz .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#chsiuddwnz .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#chsiuddwnz .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#chsiuddwnz .gt_spanner_row {
  border-bottom-style: hidden;
}

#chsiuddwnz .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}

#chsiuddwnz .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  vertical-align: middle;
}

#chsiuddwnz .gt_from_md > :first-child {
  margin-top: 0;
}

#chsiuddwnz .gt_from_md > :last-child {
  margin-bottom: 0;
}

#chsiuddwnz .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D5D5D5;
  border-left-style: solid;
  border-left-width: 1px;
  border-left-color: #D5D5D5;
  border-right-style: solid;
  border-right-width: 1px;
  border-right-color: #D5D5D5;
  vertical-align: middle;
  overflow-x: hidden;
}

#chsiuddwnz .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #5F5F5F;
  padding-left: 5px;
  padding-right: 5px;
}

#chsiuddwnz .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}

#chsiuddwnz .gt_row_group_first td {
  border-top-width: 2px;
}

#chsiuddwnz .gt_row_group_first th {
  border-top-width: 2px;
}

#chsiuddwnz .gt_summary_row {
  color: #333333;
  background-color: #D5D5D5;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#chsiuddwnz .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D5D5D5;
}

#chsiuddwnz .gt_first_summary_row.thick {
  border-top-width: 2px;
}

#chsiuddwnz .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#chsiuddwnz .gt_grand_summary_row {
  color: #FFFFFF;
  background-color: #929292;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#chsiuddwnz .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D5D5D5;
}

#chsiuddwnz .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D5D5D5;
}

#chsiuddwnz .gt_striped {
  background-color: #F4F4F4;
}

#chsiuddwnz .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#chsiuddwnz .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#chsiuddwnz .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#chsiuddwnz .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#chsiuddwnz .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#chsiuddwnz .gt_left {
  text-align: left;
}

#chsiuddwnz .gt_center {
  text-align: center;
}

#chsiuddwnz .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#chsiuddwnz .gt_font_normal {
  font-weight: normal;
}

#chsiuddwnz .gt_font_bold {
  font-weight: bold;
}

#chsiuddwnz .gt_font_italic {
  font-style: italic;
}

#chsiuddwnz .gt_super {
  font-size: 65%;
}

#chsiuddwnz .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}

#chsiuddwnz .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}

#chsiuddwnz .gt_indent_1 {
  text-indent: 5px;
}

#chsiuddwnz .gt_indent_2 {
  text-indent: 10px;
}

#chsiuddwnz .gt_indent_3 {
  text-indent: 15px;
}

#chsiuddwnz .gt_indent_4 {
  text-indent: 20px;
}

#chsiuddwnz .gt_indent_5 {
  text-indent: 25px;
}

#chsiuddwnz .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}

#chsiuddwnz div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>
<table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false">
  <thead>
    <tr class="gt_heading">
      <td colspan="10" class="gt_heading gt_title gt_font_normal gt_bottom_border" style>Memory of the Experimental Condition: convergence</td>
    </tr>
    
    <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Model">Model</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Family">Family</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="N_obs">N_obs</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="N_participants">N_participants</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Chains">Chains</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Draws">Draws</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Max_Rhat">Max_Rhat</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Min_ESS_ratio">Min_ESS_ratio</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Divergent_pct">Divergent_pct</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Criterion">Criterion</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr><td headers="Model" class="gt_row gt_left">MemoryCondition</td>
<td headers="Family" class="gt_row gt_left">Categorical</td>
<td headers="N_obs" class="gt_row gt_right">21120</td>
<td headers="N_participants" class="gt_row gt_right">220</td>
<td headers="Chains" class="gt_row gt_right">8</td>
<td headers="Draws" class="gt_row gt_right">4000</td>
<td headers="Max_Rhat" class="gt_row gt_right">1.131</td>
<td headers="Min_ESS_ratio" class="gt_row gt_right">0.011</td>
<td headers="Divergent_pct" class="gt_row gt_right">1.45</td>
<td headers="Criterion" class="gt_row gt_left">loo</td></tr>
  </tbody>
  
</table>
</div>
```


::: {.callout-note collapse="true" title="Memory of the Experimental Condition: convergence (Markdown table, for text readers)"}

|Model           |Family      | N_obs| N_participants| Chains| Draws| Max_Rhat| Min_ESS_ratio| Divergent_pct|Criterion |
|:---------------|:-----------|-----:|--------------:|------:|-----:|--------:|-------------:|-------------:|:---------|
|MemoryCondition |Categorical | 21120|            220|      8|  4000|    1.131|         0.011|          1.45|loo       |

:::

```{=html}
<div id="xsjowecglr" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#xsjowecglr table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#xsjowecglr thead, #xsjowecglr tbody, #xsjowecglr tfoot, #xsjowecglr tr, #xsjowecglr td, #xsjowecglr th {
  border-style: none;
}

#xsjowecglr p {
  margin: 0;
  padding: 0;
}

#xsjowecglr .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 13px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 3px;
  border-top-color: #D5D5D5;
  border-right-style: solid;
  border-right-width: 3px;
  border-right-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 3px;
  border-bottom-color: #D5D5D5;
  border-left-style: solid;
  border-left-width: 3px;
  border-left-color: #D5D5D5;
}

#xsjowecglr .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}

#xsjowecglr .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#xsjowecglr .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#xsjowecglr .gt_heading {
  background-color: #FFFFFF;
  text-align: left;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#xsjowecglr .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#xsjowecglr .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#xsjowecglr .gt_col_heading {
  color: #FFFFFF;
  background-color: #000000;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#xsjowecglr .gt_column_spanner_outer {
  color: #FFFFFF;
  background-color: #000000;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#xsjowecglr .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#xsjowecglr .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#xsjowecglr .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#xsjowecglr .gt_spanner_row {
  border-bottom-style: hidden;
}

#xsjowecglr .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}

#xsjowecglr .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  vertical-align: middle;
}

#xsjowecglr .gt_from_md > :first-child {
  margin-top: 0;
}

#xsjowecglr .gt_from_md > :last-child {
  margin-bottom: 0;
}

#xsjowecglr .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D5D5D5;
  border-left-style: solid;
  border-left-width: 1px;
  border-left-color: #D5D5D5;
  border-right-style: solid;
  border-right-width: 1px;
  border-right-color: #D5D5D5;
  vertical-align: middle;
  overflow-x: hidden;
}

#xsjowecglr .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #5F5F5F;
  padding-left: 5px;
  padding-right: 5px;
}

#xsjowecglr .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}

#xsjowecglr .gt_row_group_first td {
  border-top-width: 2px;
}

#xsjowecglr .gt_row_group_first th {
  border-top-width: 2px;
}

#xsjowecglr .gt_summary_row {
  color: #333333;
  background-color: #D5D5D5;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#xsjowecglr .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D5D5D5;
}

#xsjowecglr .gt_first_summary_row.thick {
  border-top-width: 2px;
}

#xsjowecglr .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#xsjowecglr .gt_grand_summary_row {
  color: #FFFFFF;
  background-color: #929292;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#xsjowecglr .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D5D5D5;
}

#xsjowecglr .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D5D5D5;
}

#xsjowecglr .gt_striped {
  background-color: #F4F4F4;
}

#xsjowecglr .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#xsjowecglr .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#xsjowecglr .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#xsjowecglr .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#xsjowecglr .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#xsjowecglr .gt_left {
  text-align: left;
}

#xsjowecglr .gt_center {
  text-align: center;
}

#xsjowecglr .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#xsjowecglr .gt_font_normal {
  font-weight: normal;
}

#xsjowecglr .gt_font_bold {
  font-weight: bold;
}

#xsjowecglr .gt_font_italic {
  font-style: italic;
}

#xsjowecglr .gt_super {
  font-size: 65%;
}

#xsjowecglr .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}

#xsjowecglr .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}

#xsjowecglr .gt_indent_1 {
  text-indent: 5px;
}

#xsjowecglr .gt_indent_2 {
  text-indent: 10px;
}

#xsjowecglr .gt_indent_3 {
  text-indent: 15px;
}

#xsjowecglr .gt_indent_4 {
  text-indent: 20px;
}

#xsjowecglr .gt_indent_5 {
  text-indent: 25px;
}

#xsjowecglr .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}

#xsjowecglr div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>
<table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false">
  <thead>
    <tr class="gt_heading">
      <td colspan="5" class="gt_heading gt_title gt_font_normal gt_bottom_border" style>Memory of the Experimental Condition: probability of each answer per Condition (marginal means)</td>
    </tr>
    
    <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="1" colspan="1" scope="col" id="Condition">Condition</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="1" colspan="1" scope="col" id="Response">Response</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Median">Median</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="CI_low">CI_low</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="CI_high">CI_high</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr><td headers="Condition" class="gt_row gt_center">Human Original</td>
<td headers="Response" class="gt_row gt_center">Human Original</td>
<td headers="Median" class="gt_row gt_right">0.23</td>
<td headers="CI_low" class="gt_row gt_right">0.21</td>
<td headers="CI_high" class="gt_row gt_right">0.25</td></tr>
    <tr><td headers="Condition" class="gt_row gt_center gt_striped">Human Forgery</td>
<td headers="Response" class="gt_row gt_center gt_striped">Human Original</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.22</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.20</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.24</td></tr>
    <tr><td headers="Condition" class="gt_row gt_center">AI-Generated</td>
<td headers="Response" class="gt_row gt_center">Human Original</td>
<td headers="Median" class="gt_row gt_right">0.21</td>
<td headers="CI_low" class="gt_row gt_right">0.19</td>
<td headers="CI_high" class="gt_row gt_right">0.24</td></tr>
    <tr><td headers="Condition" class="gt_row gt_center gt_striped">New Items</td>
<td headers="Response" class="gt_row gt_center gt_striped">Human Original</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.06</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.05</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.07</td></tr>
    <tr><td headers="Condition" class="gt_row gt_center">Human Original</td>
<td headers="Response" class="gt_row gt_center">Human Forgery</td>
<td headers="Median" class="gt_row gt_right">0.06</td>
<td headers="CI_low" class="gt_row gt_right">0.06</td>
<td headers="CI_high" class="gt_row gt_right">0.07</td></tr>
    <tr><td headers="Condition" class="gt_row gt_center gt_striped">Human Forgery</td>
<td headers="Response" class="gt_row gt_center gt_striped">Human Forgery</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.07</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.06</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.08</td></tr>
    <tr><td headers="Condition" class="gt_row gt_center">AI-Generated</td>
<td headers="Response" class="gt_row gt_center">Human Forgery</td>
<td headers="Median" class="gt_row gt_right">0.07</td>
<td headers="CI_low" class="gt_row gt_right">0.06</td>
<td headers="CI_high" class="gt_row gt_right">0.07</td></tr>
    <tr><td headers="Condition" class="gt_row gt_center gt_striped">New Items</td>
<td headers="Response" class="gt_row gt_center gt_striped">Human Forgery</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.02</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.01</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.02</td></tr>
    <tr><td headers="Condition" class="gt_row gt_center">Human Original</td>
<td headers="Response" class="gt_row gt_center">AI-Generated</td>
<td headers="Median" class="gt_row gt_right">0.15</td>
<td headers="CI_low" class="gt_row gt_right">0.13</td>
<td headers="CI_high" class="gt_row gt_right">0.17</td></tr>
    <tr><td headers="Condition" class="gt_row gt_center gt_striped">Human Forgery</td>
<td headers="Response" class="gt_row gt_center gt_striped">AI-Generated</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.14</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.12</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.16</td></tr>
    <tr><td headers="Condition" class="gt_row gt_center">AI-Generated</td>
<td headers="Response" class="gt_row gt_center">AI-Generated</td>
<td headers="Median" class="gt_row gt_right">0.15</td>
<td headers="CI_low" class="gt_row gt_right">0.13</td>
<td headers="CI_high" class="gt_row gt_right">0.17</td></tr>
    <tr><td headers="Condition" class="gt_row gt_center gt_striped">New Items</td>
<td headers="Response" class="gt_row gt_center gt_striped">AI-Generated</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.04</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.03</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.04</td></tr>
    <tr><td headers="Condition" class="gt_row gt_center">Human Original</td>
<td headers="Response" class="gt_row gt_center">Not recognized</td>
<td headers="Median" class="gt_row gt_right">0.56</td>
<td headers="CI_low" class="gt_row gt_right">0.53</td>
<td headers="CI_high" class="gt_row gt_right">0.59</td></tr>
    <tr><td headers="Condition" class="gt_row gt_center gt_striped">Human Forgery</td>
<td headers="Response" class="gt_row gt_center gt_striped">Not recognized</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.57</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.54</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.61</td></tr>
    <tr><td headers="Condition" class="gt_row gt_center">AI-Generated</td>
<td headers="Response" class="gt_row gt_center">Not recognized</td>
<td headers="Median" class="gt_row gt_right">0.57</td>
<td headers="CI_low" class="gt_row gt_right">0.54</td>
<td headers="CI_high" class="gt_row gt_right">0.61</td></tr>
    <tr><td headers="Condition" class="gt_row gt_center gt_striped">New Items</td>
<td headers="Response" class="gt_row gt_center gt_striped">Not recognized</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.89</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.87</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.90</td></tr>
  </tbody>
  
</table>
</div>
```


::: {.callout-note collapse="true" title="Memory of the Experimental Condition: probability of each answer per Condition (marginal means) (Markdown table, for text readers)"}

|Condition      |Response       |Median |CI_low |CI_high |
|:--------------|:--------------|:------|:------|:-------|
|Human Original |Human Original |0.23   |0.21   |0.25    |
|Human Forgery  |Human Original |0.22   |0.20   |0.24    |
|AI-Generated   |Human Original |0.21   |0.19   |0.24    |
|New Items      |Human Original |0.06   |0.05   |0.07    |
|Human Original |Human Forgery  |0.06   |0.06   |0.07    |
|Human Forgery  |Human Forgery  |0.07   |0.06   |0.08    |
|AI-Generated   |Human Forgery  |0.07   |0.06   |0.07    |
|New Items      |Human Forgery  |0.02   |0.01   |0.02    |
|Human Original |AI-Generated   |0.15   |0.13   |0.17    |
|Human Forgery  |AI-Generated   |0.14   |0.12   |0.16    |
|AI-Generated   |AI-Generated   |0.15   |0.13   |0.17    |
|New Items      |AI-Generated   |0.04   |0.03   |0.04    |
|Human Original |Not recognized |0.56   |0.53   |0.59    |
|Human Forgery  |Not recognized |0.57   |0.54   |0.61    |
|AI-Generated   |Not recognized |0.57   |0.54   |0.61    |
|New Items      |Not recognized |0.89   |0.87   |0.90    |

:::

::: {.callout-note collapse="true" title="Memory of the Experimental Condition: all 120 contrasts (Markdown table, for text readers)"}

|Level1         |Response1      |Level2         |Response2      |Median |CI_low |CI_high |pd   |Effect   |
|:--------------|:--------------|:--------------|:--------------|:------|:------|:-------|:----|:--------|
|Human Forgery  |Human Original |Human Original |Human Original |-0.01  |-0.03  |0.01    |0.82 |n.s.     |
|AI-Generated   |Human Original |Human Original |Human Original |-0.01  |-0.03  |0.01    |0.91 |n.s.     |
|New Items      |Human Original |Human Original |Human Original |-0.17  |-0.19  |-0.14   |1.00 |Negative |
|Human Original |Human Forgery  |Human Original |Human Original |-0.16  |-0.19  |-0.14   |1.00 |Negative |
|Human Forgery  |Human Forgery  |Human Original |Human Original |-0.16  |-0.18  |-0.14   |1.00 |Negative |
|AI-Generated   |Human Forgery  |Human Original |Human Original |-0.16  |-0.18  |-0.14   |1.00 |Negative |
|New Items      |Human Forgery  |Human Original |Human Original |-0.21  |-0.23  |-0.19   |1.00 |Negative |
|Human Original |AI-Generated   |Human Original |Human Original |-0.08  |-0.10  |-0.05   |1.00 |Negative |
|Human Forgery  |AI-Generated   |Human Original |Human Original |-0.09  |-0.11  |-0.06   |1.00 |Negative |
|AI-Generated   |AI-Generated   |Human Original |Human Original |-0.08  |-0.11  |-0.06   |1.00 |Negative |
|New Items      |AI-Generated   |Human Original |Human Original |-0.19  |-0.21  |-0.17   |1.00 |Negative |
|Human Original |Not recognized |Human Original |Human Original |0.33   |0.28   |0.39    |1.00 |Positive |
|Human Forgery  |Not recognized |Human Original |Human Original |0.35   |0.30   |0.40    |1.00 |Positive |
|AI-Generated   |Not recognized |Human Original |Human Original |0.35   |0.30   |0.40    |1.00 |Positive |
|New Items      |Not recognized |Human Original |Human Original |0.66   |0.64   |0.68    |1.00 |Positive |
|AI-Generated   |Human Original |Human Forgery  |Human Original |0.00   |-0.02  |0.01    |0.69 |n.s.     |
|New Items      |Human Original |Human Forgery  |Human Original |-0.16  |-0.18  |-0.13   |1.00 |Negative |
|Human Original |Human Forgery  |Human Forgery  |Human Original |-0.16  |-0.18  |-0.14   |1.00 |Negative |
|Human Forgery  |Human Forgery  |Human Forgery  |Human Original |-0.15  |-0.17  |-0.13   |1.00 |Negative |
|AI-Generated   |Human Forgery  |Human Forgery  |Human Original |-0.15  |-0.17  |-0.13   |1.00 |Negative |
|New Items      |Human Forgery  |Human Forgery  |Human Original |-0.20  |-0.22  |-0.18   |1.00 |Negative |
|Human Original |AI-Generated   |Human Forgery  |Human Original |-0.07  |-0.09  |-0.05   |1.00 |Negative |
|Human Forgery  |AI-Generated   |Human Forgery  |Human Original |-0.08  |-0.10  |-0.05   |1.00 |Negative |
|AI-Generated   |AI-Generated   |Human Forgery  |Human Original |-0.07  |-0.10  |-0.05   |1.00 |Negative |
|New Items      |AI-Generated   |Human Forgery  |Human Original |-0.18  |-0.21  |-0.16   |1.00 |Negative |
|Human Original |Not recognized |Human Forgery  |Human Original |0.34   |0.29   |0.39    |1.00 |Positive |
|Human Forgery  |Not recognized |Human Forgery  |Human Original |0.36   |0.30   |0.41    |1.00 |Positive |
|AI-Generated   |Not recognized |Human Forgery  |Human Original |0.36   |0.31   |0.40    |1.00 |Positive |
|New Items      |Not recognized |Human Forgery  |Human Original |0.67   |0.65   |0.68    |1.00 |Positive |
|New Items      |Human Original |AI-Generated   |Human Original |-0.15  |-0.18  |-0.13   |1.00 |Negative |
|Human Original |Human Forgery  |AI-Generated   |Human Original |-0.15  |-0.17  |-0.13   |1.00 |Negative |
|Human Forgery  |Human Forgery  |AI-Generated   |Human Original |-0.15  |-0.17  |-0.13   |1.00 |Negative |
|AI-Generated   |Human Forgery  |AI-Generated   |Human Original |-0.15  |-0.17  |-0.13   |1.00 |Negative |
|New Items      |Human Forgery  |AI-Generated   |Human Original |-0.20  |-0.22  |-0.18   |1.00 |Negative |
|Human Original |AI-Generated   |AI-Generated   |Human Original |-0.07  |-0.09  |-0.04   |1.00 |Negative |
|Human Forgery  |AI-Generated   |AI-Generated   |Human Original |-0.07  |-0.10  |-0.05   |1.00 |Negative |
|AI-Generated   |AI-Generated   |AI-Generated   |Human Original |-0.07  |-0.09  |-0.04   |1.00 |Negative |
|New Items      |AI-Generated   |AI-Generated   |Human Original |-0.18  |-0.20  |-0.15   |1.00 |Negative |
|Human Original |Not recognized |AI-Generated   |Human Original |0.35   |0.30   |0.39    |1.00 |Positive |
|Human Forgery  |Not recognized |AI-Generated   |Human Original |0.36   |0.31   |0.41    |1.00 |Positive |
|AI-Generated   |Not recognized |AI-Generated   |Human Original |0.36   |0.31   |0.41    |1.00 |Positive |
|New Items      |Not recognized |AI-Generated   |Human Original |0.67   |0.65   |0.69    |1.00 |Positive |
|Human Original |Human Forgery  |New Items      |Human Original |0.00   |-0.01  |0.02    |0.67 |n.s.     |
|Human Forgery  |Human Forgery  |New Items      |Human Original |0.01   |-0.01  |0.02    |0.82 |n.s.     |
|AI-Generated   |Human Forgery  |New Items      |Human Original |0.00   |-0.01  |0.02    |0.75 |n.s.     |
|New Items      |Human Forgery  |New Items      |Human Original |-0.04  |-0.05  |-0.04   |1.00 |Negative |
|Human Original |AI-Generated   |New Items      |Human Original |0.09   |0.06   |0.11    |1.00 |Positive |
|Human Forgery  |AI-Generated   |New Items      |Human Original |0.08   |0.06   |0.10    |1.00 |Positive |
|AI-Generated   |AI-Generated   |New Items      |Human Original |0.09   |0.06   |0.11    |1.00 |Positive |
|New Items      |AI-Generated   |New Items      |Human Original |-0.02  |-0.03  |-0.02   |1.00 |Negative |
|Human Original |Not recognized |New Items      |Human Original |0.50   |0.47   |0.53    |1.00 |Positive |
|Human Forgery  |Not recognized |New Items      |Human Original |0.51   |0.48   |0.54    |1.00 |Positive |
|AI-Generated   |Not recognized |New Items      |Human Original |0.51   |0.48   |0.54    |1.00 |Positive |
|New Items      |Not recognized |New Items      |Human Original |0.83   |0.80   |0.85    |1.00 |Positive |
|Human Forgery  |Human Forgery  |Human Original |Human Forgery  |0.00   |-0.01  |0.02    |0.73 |n.s.     |
|AI-Generated   |Human Forgery  |Human Original |Human Forgery  |0.00   |-0.01  |0.01    |0.63 |n.s.     |
|New Items      |Human Forgery  |Human Original |Human Forgery  |-0.05  |-0.06  |-0.04   |1.00 |Negative |
|Human Original |AI-Generated   |Human Original |Human Forgery  |0.08   |0.07   |0.11    |1.00 |Positive |
|Human Forgery  |AI-Generated   |Human Original |Human Forgery  |0.08   |0.06   |0.10    |1.00 |Positive |
|AI-Generated   |AI-Generated   |Human Original |Human Forgery  |0.08   |0.06   |0.10    |1.00 |Positive |
|New Items      |AI-Generated   |Human Original |Human Forgery  |-0.03  |-0.04  |-0.01   |1.00 |Negative |
|Human Original |Not recognized |Human Original |Human Forgery  |0.50   |0.46   |0.54    |1.00 |Positive |
|Human Forgery  |Not recognized |Human Original |Human Forgery  |0.51   |0.47   |0.55    |1.00 |Positive |
|AI-Generated   |Not recognized |Human Original |Human Forgery  |0.51   |0.47   |0.55    |1.00 |Positive |
|New Items      |Not recognized |Human Original |Human Forgery  |0.82   |0.81   |0.84    |1.00 |Positive |
|AI-Generated   |Human Forgery  |Human Forgery  |Human Forgery  |0.00   |-0.01  |0.01    |0.61 |n.s.     |
|New Items      |Human Forgery  |Human Forgery  |Human Forgery  |-0.05  |-0.06  |-0.04   |1.00 |Negative |
|Human Original |AI-Generated   |Human Forgery  |Human Forgery  |0.08   |0.06   |0.10    |1.00 |Positive |
|Human Forgery  |AI-Generated   |Human Forgery  |Human Forgery  |0.07   |0.05   |0.09    |1.00 |Positive |
|AI-Generated   |AI-Generated   |Human Forgery  |Human Forgery  |0.08   |0.06   |0.10    |1.00 |Positive |
|New Items      |AI-Generated   |Human Forgery  |Human Forgery  |-0.03  |-0.04  |-0.02   |1.00 |Negative |
|Human Original |Not recognized |Human Forgery  |Human Forgery  |0.49   |0.46   |0.53    |1.00 |Positive |
|Human Forgery  |Not recognized |Human Forgery  |Human Forgery  |0.51   |0.47   |0.55    |1.00 |Positive |
|AI-Generated   |Not recognized |Human Forgery  |Human Forgery  |0.51   |0.47   |0.55    |1.00 |Positive |
|New Items      |Not recognized |Human Forgery  |Human Forgery  |0.82   |0.80   |0.83    |1.00 |Positive |
|New Items      |Human Forgery  |AI-Generated   |Human Forgery  |-0.05  |-0.06  |-0.04   |1.00 |Negative |
|Human Original |AI-Generated   |AI-Generated   |Human Forgery  |0.08   |0.06   |0.10    |1.00 |Positive |
|Human Forgery  |AI-Generated   |AI-Generated   |Human Forgery  |0.07   |0.06   |0.09    |1.00 |Positive |
|AI-Generated   |AI-Generated   |AI-Generated   |Human Forgery  |0.08   |0.06   |0.10    |1.00 |Positive |
|New Items      |AI-Generated   |AI-Generated   |Human Forgery  |-0.03  |-0.04  |-0.02   |1.00 |Negative |
|Human Original |Not recognized |AI-Generated   |Human Forgery  |0.50   |0.46   |0.53    |1.00 |Positive |
|Human Forgery  |Not recognized |AI-Generated   |Human Forgery  |0.51   |0.47   |0.55    |1.00 |Positive |
|AI-Generated   |Not recognized |AI-Generated   |Human Forgery  |0.51   |0.47   |0.55    |1.00 |Positive |
|New Items      |Not recognized |AI-Generated   |Human Forgery  |0.82   |0.81   |0.83    |1.00 |Positive |
|Human Original |AI-Generated   |New Items      |Human Forgery  |0.13   |0.11   |0.15    |1.00 |Positive |
|Human Forgery  |AI-Generated   |New Items      |Human Forgery  |0.12   |0.10   |0.14    |1.00 |Positive |
|AI-Generated   |AI-Generated   |New Items      |Human Forgery  |0.13   |0.11   |0.15    |1.00 |Positive |
|New Items      |AI-Generated   |New Items      |Human Forgery  |0.02   |0.01   |0.03    |1.00 |Positive |
|Human Original |Not recognized |New Items      |Human Forgery  |0.54   |0.51   |0.58    |1.00 |Positive |
|Human Forgery  |Not recognized |New Items      |Human Forgery  |0.56   |0.53   |0.59    |1.00 |Positive |
|AI-Generated   |Not recognized |New Items      |Human Forgery  |0.56   |0.52   |0.59    |1.00 |Positive |
|New Items      |Not recognized |New Items      |Human Forgery  |0.87   |0.85   |0.88    |1.00 |Positive |
|Human Forgery  |AI-Generated   |Human Original |AI-Generated   |-0.01  |-0.02  |0.01    |0.85 |n.s.     |
|AI-Generated   |AI-Generated   |Human Original |AI-Generated   |0.00   |-0.02  |0.01    |0.62 |n.s.     |
|New Items      |AI-Generated   |Human Original |AI-Generated   |-0.11  |-0.13  |-0.09   |1.00 |Negative |
|Human Original |Not recognized |Human Original |AI-Generated   |0.41   |0.36   |0.46    |1.00 |Positive |
|Human Forgery  |Not recognized |Human Original |AI-Generated   |0.43   |0.38   |0.47    |1.00 |Positive |
|AI-Generated   |Not recognized |Human Original |AI-Generated   |0.43   |0.38   |0.47    |1.00 |Positive |
|New Items      |Not recognized |Human Original |AI-Generated   |0.74   |0.72   |0.75    |1.00 |Positive |
|AI-Generated   |AI-Generated   |Human Forgery  |AI-Generated   |0.01   |-0.01  |0.02    |0.76 |n.s.     |
|New Items      |AI-Generated   |Human Forgery  |AI-Generated   |-0.10  |-0.13  |-0.08   |1.00 |Negative |
|Human Original |Not recognized |Human Forgery  |AI-Generated   |0.42   |0.37   |0.47    |1.00 |Positive |
|Human Forgery  |Not recognized |Human Forgery  |AI-Generated   |0.43   |0.39   |0.48    |1.00 |Positive |
|AI-Generated   |Not recognized |Human Forgery  |AI-Generated   |0.43   |0.39   |0.48    |1.00 |Positive |
|New Items      |Not recognized |Human Forgery  |AI-Generated   |0.75   |0.73   |0.76    |1.00 |Positive |
|New Items      |AI-Generated   |AI-Generated   |AI-Generated   |-0.11  |-0.13  |-0.09   |1.00 |Negative |
|Human Original |Not recognized |AI-Generated   |AI-Generated   |0.42   |0.37   |0.46    |1.00 |Positive |
|Human Forgery  |Not recognized |AI-Generated   |AI-Generated   |0.43   |0.38   |0.47    |1.00 |Positive |
|AI-Generated   |Not recognized |AI-Generated   |AI-Generated   |0.43   |0.38   |0.48    |1.00 |Positive |
|New Items      |Not recognized |AI-Generated   |AI-Generated   |0.74   |0.72   |0.76    |1.00 |Positive |
|Human Original |Not recognized |New Items      |AI-Generated   |0.52   |0.49   |0.55    |1.00 |Positive |
|Human Forgery  |Not recognized |New Items      |AI-Generated   |0.54   |0.51   |0.57    |1.00 |Positive |
|AI-Generated   |Not recognized |New Items      |AI-Generated   |0.54   |0.51   |0.57    |1.00 |Positive |
|New Items      |Not recognized |New Items      |AI-Generated   |0.85   |0.83   |0.87    |1.00 |Positive |
|Human Forgery  |Not recognized |Human Original |Not recognized |0.01   |-0.01  |0.03    |0.90 |n.s.     |
|AI-Generated   |Not recognized |Human Original |Not recognized |0.01   |-0.01  |0.03    |0.90 |n.s.     |
|New Items      |Not recognized |Human Original |Not recognized |0.32   |0.28   |0.37    |1.00 |Positive |
|AI-Generated   |Not recognized |Human Forgery  |Not recognized |0.00   |-0.02  |0.02    |0.51 |n.s.     |
|New Items      |Not recognized |Human Forgery  |Not recognized |0.31   |0.27   |0.36    |1.00 |Positive |
|New Items      |Not recognized |AI-Generated   |Not recognized |0.31   |0.27   |0.36    |1.00 |Positive |

:::
:::
:::



::: {.cell}

```{.r .cell-code}
c <- estimates$MemoryCondition$contrasts
make_contrasts(c, answer="Not recognized",
               title="Memory of Condition: forgetting ('Not recognized') by condition")
```

::: {.cell-output-display}

```{=html}
<div id="pgtbhbsswm" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#pgtbhbsswm table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#pgtbhbsswm thead, #pgtbhbsswm tbody, #pgtbhbsswm tfoot, #pgtbhbsswm tr, #pgtbhbsswm td, #pgtbhbsswm th {
  border-style: none;
}

#pgtbhbsswm p {
  margin: 0;
  padding: 0;
}

#pgtbhbsswm .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 16px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #A8A8A8;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #A8A8A8;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
}

#pgtbhbsswm .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}

#pgtbhbsswm .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#pgtbhbsswm .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#pgtbhbsswm .gt_heading {
  background-color: #FFFFFF;
  text-align: center;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#pgtbhbsswm .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#pgtbhbsswm .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#pgtbhbsswm .gt_col_heading {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#pgtbhbsswm .gt_column_spanner_outer {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#pgtbhbsswm .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#pgtbhbsswm .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#pgtbhbsswm .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#pgtbhbsswm .gt_spanner_row {
  border-bottom-style: hidden;
}

#pgtbhbsswm .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}

#pgtbhbsswm .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: middle;
}

#pgtbhbsswm .gt_from_md > :first-child {
  margin-top: 0;
}

#pgtbhbsswm .gt_from_md > :last-child {
  margin-bottom: 0;
}

#pgtbhbsswm .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  overflow-x: hidden;
}

#pgtbhbsswm .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
}

#pgtbhbsswm .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}

#pgtbhbsswm .gt_row_group_first td {
  border-top-width: 2px;
}

#pgtbhbsswm .gt_row_group_first th {
  border-top-width: 2px;
}

#pgtbhbsswm .gt_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#pgtbhbsswm .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D3D3D3;
}

#pgtbhbsswm .gt_first_summary_row.thick {
  border-top-width: 2px;
}

#pgtbhbsswm .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#pgtbhbsswm .gt_grand_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#pgtbhbsswm .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D3D3D3;
}

#pgtbhbsswm .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D3D3D3;
}

#pgtbhbsswm .gt_striped {
  background-color: rgba(128, 128, 128, 0.05);
}

#pgtbhbsswm .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#pgtbhbsswm .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#pgtbhbsswm .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#pgtbhbsswm .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#pgtbhbsswm .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#pgtbhbsswm .gt_left {
  text-align: left;
}

#pgtbhbsswm .gt_center {
  text-align: center;
}

#pgtbhbsswm .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#pgtbhbsswm .gt_font_normal {
  font-weight: normal;
}

#pgtbhbsswm .gt_font_bold {
  font-weight: bold;
}

#pgtbhbsswm .gt_font_italic {
  font-style: italic;
}

#pgtbhbsswm .gt_super {
  font-size: 65%;
}

#pgtbhbsswm .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}

#pgtbhbsswm .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}

#pgtbhbsswm .gt_indent_1 {
  text-indent: 5px;
}

#pgtbhbsswm .gt_indent_2 {
  text-indent: 10px;
}

#pgtbhbsswm .gt_indent_3 {
  text-indent: 15px;
}

#pgtbhbsswm .gt_indent_4 {
  text-indent: 20px;
}

#pgtbhbsswm .gt_indent_5 {
  text-indent: 25px;
}

#pgtbhbsswm .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}

#pgtbhbsswm div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>
<table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false">
  <thead>
    <tr class="gt_heading">
      <td colspan="6" class="gt_heading gt_title gt_font_normal gt_bottom_border" style>Memory of Condition: forgetting ('Not recognized') by condition</td>
    </tr>
    
    <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Category">Category</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Level1">Level1</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Level2">Level2</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Median">Median</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="CI">CI</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="pd">pd</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr><td headers="Category" class="gt_row gt_left">Not recognized</td>
<td headers="Level1" class="gt_row gt_left">New Items</td>
<td headers="Level2" class="gt_row gt_left">Human Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #42FF30; color: #000000;">0.32</td>
<td headers="CI" class="gt_row gt_left">[ 0.28, 0.37]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Not recognized</td>
<td headers="Level1" class="gt_row gt_left">New Items</td>
<td headers="Level2" class="gt_row gt_left">Human Forgery</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #52FF3D; color: #000000;">0.31</td>
<td headers="CI" class="gt_row gt_left">[ 0.27, 0.36]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Not recognized</td>
<td headers="Level1" class="gt_row gt_left">New Items</td>
<td headers="Level2" class="gt_row gt_left">AI-Generated</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #52FF3D; color: #000000;">0.31</td>
<td headers="CI" class="gt_row gt_left">[ 0.27, 0.36]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Not recognized</td>
<td headers="Level1" class="gt_row gt_left">AI-Generated</td>
<td headers="Level2" class="gt_row gt_left">Human Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FAFFF7; color: #000000;">0.01</td>
<td headers="CI" class="gt_row gt_left">[-0.01, 0.03]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFFFFF; color: #000000;">90.10%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Not recognized</td>
<td headers="Level1" class="gt_row gt_left">Human Forgery</td>
<td headers="Level2" class="gt_row gt_left">Human Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FAFFF7; color: #000000;">0.01</td>
<td headers="CI" class="gt_row gt_left">[-0.01, 0.03]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFFFFF; color: #000000;">89.98%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Not recognized</td>
<td headers="Level1" class="gt_row gt_left">AI-Generated</td>
<td headers="Level2" class="gt_row gt_left">Human Forgery</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FFFFFF; color: #000000;">0.00</td>
<td headers="CI" class="gt_row gt_left">[-0.02, 0.02]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFFFFF; color: #000000;">50.55%</td></tr>
  </tbody>
  
</table>
</div>
```


::: {.callout-note collapse="true" title="Memory of Condition: forgetting ('Not recognized') by condition (Markdown table, for text readers)"}

|Category       |Level1        |Level2         |Median |CI            |pd     |Effect   |
|:--------------|:-------------|:--------------|:------|:-------------|:------|:--------|
|Not recognized |New Items     |Human Original |0.32   |[ 0.28, 0.37] |100%   |Positive |
|Not recognized |New Items     |Human Forgery  |0.31   |[ 0.27, 0.36] |100%   |Positive |
|Not recognized |New Items     |AI-Generated   |0.31   |[ 0.27, 0.36] |100%   |Positive |
|Not recognized |AI-Generated  |Human Original |0.01   |[-0.01, 0.03] |90.10% |n.s.     |
|Not recognized |Human Forgery |Human Original |0.01   |[-0.01, 0.03] |89.98% |n.s.     |
|Not recognized |AI-Generated  |Human Forgery  |0.00   |[-0.02, 0.02] |50.55% |n.s.     |

:::

:::

```{.r .cell-code}
make_contrasts(c, condition="Human Original",
               title="Memory of Condition: which answer, within the Human Original condition")
```

::: {.cell-output-display}

```{=html}
<div id="wjdoqgipsn" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#wjdoqgipsn table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#wjdoqgipsn thead, #wjdoqgipsn tbody, #wjdoqgipsn tfoot, #wjdoqgipsn tr, #wjdoqgipsn td, #wjdoqgipsn th {
  border-style: none;
}

#wjdoqgipsn p {
  margin: 0;
  padding: 0;
}

#wjdoqgipsn .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 16px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #A8A8A8;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #A8A8A8;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
}

#wjdoqgipsn .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}

#wjdoqgipsn .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#wjdoqgipsn .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#wjdoqgipsn .gt_heading {
  background-color: #FFFFFF;
  text-align: center;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#wjdoqgipsn .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#wjdoqgipsn .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#wjdoqgipsn .gt_col_heading {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#wjdoqgipsn .gt_column_spanner_outer {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#wjdoqgipsn .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#wjdoqgipsn .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#wjdoqgipsn .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#wjdoqgipsn .gt_spanner_row {
  border-bottom-style: hidden;
}

#wjdoqgipsn .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}

#wjdoqgipsn .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: middle;
}

#wjdoqgipsn .gt_from_md > :first-child {
  margin-top: 0;
}

#wjdoqgipsn .gt_from_md > :last-child {
  margin-bottom: 0;
}

#wjdoqgipsn .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  overflow-x: hidden;
}

#wjdoqgipsn .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
}

#wjdoqgipsn .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}

#wjdoqgipsn .gt_row_group_first td {
  border-top-width: 2px;
}

#wjdoqgipsn .gt_row_group_first th {
  border-top-width: 2px;
}

#wjdoqgipsn .gt_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#wjdoqgipsn .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D3D3D3;
}

#wjdoqgipsn .gt_first_summary_row.thick {
  border-top-width: 2px;
}

#wjdoqgipsn .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#wjdoqgipsn .gt_grand_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#wjdoqgipsn .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D3D3D3;
}

#wjdoqgipsn .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D3D3D3;
}

#wjdoqgipsn .gt_striped {
  background-color: rgba(128, 128, 128, 0.05);
}

#wjdoqgipsn .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#wjdoqgipsn .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#wjdoqgipsn .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#wjdoqgipsn .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#wjdoqgipsn .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#wjdoqgipsn .gt_left {
  text-align: left;
}

#wjdoqgipsn .gt_center {
  text-align: center;
}

#wjdoqgipsn .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#wjdoqgipsn .gt_font_normal {
  font-weight: normal;
}

#wjdoqgipsn .gt_font_bold {
  font-weight: bold;
}

#wjdoqgipsn .gt_font_italic {
  font-style: italic;
}

#wjdoqgipsn .gt_super {
  font-size: 65%;
}

#wjdoqgipsn .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}

#wjdoqgipsn .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}

#wjdoqgipsn .gt_indent_1 {
  text-indent: 5px;
}

#wjdoqgipsn .gt_indent_2 {
  text-indent: 10px;
}

#wjdoqgipsn .gt_indent_3 {
  text-indent: 15px;
}

#wjdoqgipsn .gt_indent_4 {
  text-indent: 20px;
}

#wjdoqgipsn .gt_indent_5 {
  text-indent: 25px;
}

#wjdoqgipsn .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}

#wjdoqgipsn div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>
<table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false">
  <thead>
    <tr class="gt_heading">
      <td colspan="6" class="gt_heading gt_title gt_font_normal gt_bottom_border" style>Memory of Condition: which answer, within the Human Original condition</td>
    </tr>
    
    <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Category">Category</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Response1">Response1</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Response2">Response2</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Median">Median</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="CI">CI</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="pd">pd</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Response1" class="gt_row gt_left">Not recognized</td>
<td headers="Response2" class="gt_row gt_left">Human Forgery</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #00FF00; color: #000000;">0.50</td>
<td headers="CI" class="gt_row gt_left">[ 0.46,  0.54]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Response1" class="gt_row gt_left">Not recognized</td>
<td headers="Response2" class="gt_row gt_left">AI-Generated</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #00FF00; color: #000000;">0.41</td>
<td headers="CI" class="gt_row gt_left">[ 0.36,  0.46]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Response1" class="gt_row gt_left">Not recognized</td>
<td headers="Response2" class="gt_row gt_left">Human Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #34FF24; color: #000000;">0.33</td>
<td headers="CI" class="gt_row gt_left">[ 0.28,  0.39]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Response1" class="gt_row gt_left">Human Forgery</td>
<td headers="Response2" class="gt_row gt_left">Human Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FFA489; color: #000000;">-0.16</td>
<td headers="CI" class="gt_row gt_left">[-0.19, -0.14]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Response1" class="gt_row gt_left">AI-Generated</td>
<td headers="Response2" class="gt_row gt_left">Human Forgery</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #DCFFCF; color: #000000;">0.08</td>
<td headers="CI" class="gt_row gt_left">[ 0.07,  0.11]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Response1" class="gt_row gt_left">AI-Generated</td>
<td headers="Response2" class="gt_row gt_left">Human Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FFD4C5; color: #000000;">-0.08</td>
<td headers="CI" class="gt_row gt_left">[-0.10, -0.05]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
  </tbody>
  
</table>
</div>
```


::: {.callout-note collapse="true" title="Memory of Condition: which answer, within the Human Original condition (Markdown table, for text readers)"}

|Category       |Response1      |Response2      |Median |CI             |pd   |Effect   |
|:--------------|:--------------|:--------------|:------|:--------------|:----|:--------|
|Human Original |Not recognized |Human Forgery  |0.50   |[ 0.46,  0.54] |100% |Positive |
|Human Original |Not recognized |AI-Generated   |0.41   |[ 0.36,  0.46] |100% |Positive |
|Human Original |Not recognized |Human Original |0.33   |[ 0.28,  0.39] |100% |Positive |
|Human Original |Human Forgery  |Human Original |-0.16  |[-0.19, -0.14] |100% |Negative |
|Human Original |AI-Generated   |Human Forgery  |0.08   |[ 0.07,  0.11] |100% |Positive |
|Human Original |AI-Generated   |Human Original |-0.08  |[-0.10, -0.05] |100% |Negative |

:::

:::

```{.r .cell-code}
make_contrasts(c, condition="New Items",
               title="Memory of Condition: which answer, within the New Items condition")
```

::: {.cell-output .cell-output-stderr}

```
Warning: Some values were outside the color scale and will be treated as NA
```


:::

::: {.cell-output-display}

```{=html}
<div id="bsyijeddrc" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#bsyijeddrc table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#bsyijeddrc thead, #bsyijeddrc tbody, #bsyijeddrc tfoot, #bsyijeddrc tr, #bsyijeddrc td, #bsyijeddrc th {
  border-style: none;
}

#bsyijeddrc p {
  margin: 0;
  padding: 0;
}

#bsyijeddrc .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 16px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #A8A8A8;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #A8A8A8;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
}

#bsyijeddrc .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}

#bsyijeddrc .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#bsyijeddrc .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#bsyijeddrc .gt_heading {
  background-color: #FFFFFF;
  text-align: center;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#bsyijeddrc .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#bsyijeddrc .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#bsyijeddrc .gt_col_heading {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#bsyijeddrc .gt_column_spanner_outer {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#bsyijeddrc .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#bsyijeddrc .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#bsyijeddrc .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#bsyijeddrc .gt_spanner_row {
  border-bottom-style: hidden;
}

#bsyijeddrc .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}

#bsyijeddrc .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: middle;
}

#bsyijeddrc .gt_from_md > :first-child {
  margin-top: 0;
}

#bsyijeddrc .gt_from_md > :last-child {
  margin-bottom: 0;
}

#bsyijeddrc .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  overflow-x: hidden;
}

#bsyijeddrc .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
}

#bsyijeddrc .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}

#bsyijeddrc .gt_row_group_first td {
  border-top-width: 2px;
}

#bsyijeddrc .gt_row_group_first th {
  border-top-width: 2px;
}

#bsyijeddrc .gt_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#bsyijeddrc .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D3D3D3;
}

#bsyijeddrc .gt_first_summary_row.thick {
  border-top-width: 2px;
}

#bsyijeddrc .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#bsyijeddrc .gt_grand_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#bsyijeddrc .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D3D3D3;
}

#bsyijeddrc .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D3D3D3;
}

#bsyijeddrc .gt_striped {
  background-color: rgba(128, 128, 128, 0.05);
}

#bsyijeddrc .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#bsyijeddrc .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#bsyijeddrc .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#bsyijeddrc .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#bsyijeddrc .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#bsyijeddrc .gt_left {
  text-align: left;
}

#bsyijeddrc .gt_center {
  text-align: center;
}

#bsyijeddrc .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#bsyijeddrc .gt_font_normal {
  font-weight: normal;
}

#bsyijeddrc .gt_font_bold {
  font-weight: bold;
}

#bsyijeddrc .gt_font_italic {
  font-style: italic;
}

#bsyijeddrc .gt_super {
  font-size: 65%;
}

#bsyijeddrc .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}

#bsyijeddrc .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}

#bsyijeddrc .gt_indent_1 {
  text-indent: 5px;
}

#bsyijeddrc .gt_indent_2 {
  text-indent: 10px;
}

#bsyijeddrc .gt_indent_3 {
  text-indent: 15px;
}

#bsyijeddrc .gt_indent_4 {
  text-indent: 20px;
}

#bsyijeddrc .gt_indent_5 {
  text-indent: 25px;
}

#bsyijeddrc .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}

#bsyijeddrc div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>
<table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false">
  <thead>
    <tr class="gt_heading">
      <td colspan="6" class="gt_heading gt_title gt_font_normal gt_bottom_border" style>Memory of Condition: which answer, within the New Items condition</td>
    </tr>
    
    <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Category">Category</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Response1">Response1</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Response2">Response2</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Median">Median</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="CI">CI</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="pd">pd</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr><td headers="Category" class="gt_row gt_left">New Items</td>
<td headers="Response1" class="gt_row gt_left">Not recognized</td>
<td headers="Response2" class="gt_row gt_left">Human Forgery</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #808080; color: #FFFFFF;">0.87</td>
<td headers="CI" class="gt_row gt_left">[ 0.85,  0.88]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">New Items</td>
<td headers="Response1" class="gt_row gt_left">Not recognized</td>
<td headers="Response2" class="gt_row gt_left">AI-Generated</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #808080; color: #FFFFFF;">0.85</td>
<td headers="CI" class="gt_row gt_left">[ 0.83,  0.87]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">New Items</td>
<td headers="Response1" class="gt_row gt_left">Not recognized</td>
<td headers="Response2" class="gt_row gt_left">Human Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #808080; color: #FFFFFF;">0.83</td>
<td headers="CI" class="gt_row gt_left">[ 0.80,  0.85]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">New Items</td>
<td headers="Response1" class="gt_row gt_left">Human Forgery</td>
<td headers="Response2" class="gt_row gt_left">Human Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FFE7DF; color: #000000;">-0.04</td>
<td headers="CI" class="gt_row gt_left">[-0.05, -0.04]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">New Items</td>
<td headers="Response1" class="gt_row gt_left">AI-Generated</td>
<td headers="Response2" class="gt_row gt_left">Human Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FFF2ED; color: #000000;">-0.02</td>
<td headers="CI" class="gt_row gt_left">[-0.03, -0.02]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">New Items</td>
<td headers="Response1" class="gt_row gt_left">AI-Generated</td>
<td headers="Response2" class="gt_row gt_left">Human Forgery</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #F7FFF4; color: #000000;">0.02</td>
<td headers="CI" class="gt_row gt_left">[ 0.01,  0.03]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
  </tbody>
  
</table>
</div>
```


::: {.callout-note collapse="true" title="Memory of Condition: which answer, within the New Items condition (Markdown table, for text readers)"}

|Category  |Response1      |Response2      |Median |CI             |pd   |Effect   |
|:---------|:--------------|:--------------|:------|:--------------|:----|:--------|
|New Items |Not recognized |Human Forgery  |0.87   |[ 0.85,  0.88] |100% |Positive |
|New Items |Not recognized |AI-Generated   |0.85   |[ 0.83,  0.87] |100% |Positive |
|New Items |Not recognized |Human Original |0.83   |[ 0.80,  0.85] |100% |Positive |
|New Items |Human Forgery  |Human Original |-0.04  |[-0.05, -0.04] |100% |Negative |
|New Items |AI-Generated   |Human Original |-0.02  |[-0.03, -0.02] |100% |Negative |
|New Items |AI-Generated   |Human Forgery  |0.02   |[ 0.01,  0.03] |100% |Positive |

:::

:::
:::



::: {.cell}

```{.r .cell-code}
make_memory_summary(estimates$MemoryCondition)
```

::: {.cell-output-display}

::: {.callout-tip title="Summary of credible effects (generated from the tables above)"}

**Memory of the Experimental Condition.** Each row of the model is the probability of one answer. The differences below are between Condition levels *within* the same answer, in percentage points, as posterior medians with 95% CI; `pd` is the probability of direction. An effect is called credible when the CI excludes 0. Contrasts *across* answers are in the full table above.

- **Human Original**: New Items - Human Original -16.66 pp [-19.31, -14.11]; New Items - Human Forgery -15.85 pp [-18.46, -13.29]; New Items - AI-Generated -15.38 pp [-18.06, -12.84]. The other 3 pair(s) are not credible.
- **Human Forgery**: New Items - Human Forgery -5.02 pp [-6.12, -3.98]; New Items - AI-Generated -4.84 pp [-5.94, -3.83]; New Items - Human Original -4.65 pp [-5.70, -3.68]. The other 3 pair(s) are not credible.
- **AI-Generated**: New Items - Human Original -11.15 pp [-13.44, -8.84]; New Items - AI-Generated -10.92 pp [-13.25, -8.70]; New Items - Human Forgery -10.30 pp [-12.51, -8.11]. The other 3 pair(s) are not credible.
- **Not recognized**: New Items - Human Original 32.50 pp [28.02, 36.86]; New Items - Human Forgery 31.22 pp [26.71, 35.51]; New Items - AI-Generated 31.22 pp [26.65, 35.59]. The other 3 pair(s) are not credible.

:::

:::
:::



## Memory of Beliefs

### Main Model


::: {.cell}

```{.r .cell-code}
dat_belief1a <- estimates$MemoryBelief$means |>
  mutate(group = make_group(Response))

p_belief1a <- dat_belief1a |> 
  ggplot(aes(x=Belief,  y = Median, color = Response)) +
  geom_line(aes(group=group), position = position_dodge(width=0.1), linewidth = 1, 
            show.legend = FALSE) +
  geom_pointrange(aes(group=group, ymin = CI_low, ymax = CI_high), position = position_dodge(width=0.1),
                  key_glyph = "point") +
  scale_y_continuous(label = scales::percent, limits = c(0,1), expand = c(0, 0)) +
  scale_color_manual(values = cols) +
  guides(color = guide_legend(override.aes = list(size = 3))) +
  labs(y="Proportion of answers", color = "Answer", x =  "Original Belief",
       title = "Memory of Beliefs") +
  theme_minimal()
p_belief1a
```

::: {.cell-output-display}
![](4_memory_files/figure-html/unnamed-chunk-8-1.png){width=672}
:::
:::



::: {.cell}

```{.r .cell-code}
make_memory_tables(estimates$MemoryBelief)
```

::: {.cell-output-display}

```{=html}
<div id="uowdnvkubv" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#uowdnvkubv table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#uowdnvkubv thead, #uowdnvkubv tbody, #uowdnvkubv tfoot, #uowdnvkubv tr, #uowdnvkubv td, #uowdnvkubv th {
  border-style: none;
}

#uowdnvkubv p {
  margin: 0;
  padding: 0;
}

#uowdnvkubv .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 13px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 3px;
  border-top-color: #D5D5D5;
  border-right-style: solid;
  border-right-width: 3px;
  border-right-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 3px;
  border-bottom-color: #D5D5D5;
  border-left-style: solid;
  border-left-width: 3px;
  border-left-color: #D5D5D5;
}

#uowdnvkubv .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}

#uowdnvkubv .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#uowdnvkubv .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#uowdnvkubv .gt_heading {
  background-color: #FFFFFF;
  text-align: left;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#uowdnvkubv .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#uowdnvkubv .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#uowdnvkubv .gt_col_heading {
  color: #FFFFFF;
  background-color: #000000;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#uowdnvkubv .gt_column_spanner_outer {
  color: #FFFFFF;
  background-color: #000000;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#uowdnvkubv .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#uowdnvkubv .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#uowdnvkubv .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#uowdnvkubv .gt_spanner_row {
  border-bottom-style: hidden;
}

#uowdnvkubv .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}

#uowdnvkubv .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  vertical-align: middle;
}

#uowdnvkubv .gt_from_md > :first-child {
  margin-top: 0;
}

#uowdnvkubv .gt_from_md > :last-child {
  margin-bottom: 0;
}

#uowdnvkubv .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D5D5D5;
  border-left-style: solid;
  border-left-width: 1px;
  border-left-color: #D5D5D5;
  border-right-style: solid;
  border-right-width: 1px;
  border-right-color: #D5D5D5;
  vertical-align: middle;
  overflow-x: hidden;
}

#uowdnvkubv .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #5F5F5F;
  padding-left: 5px;
  padding-right: 5px;
}

#uowdnvkubv .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}

#uowdnvkubv .gt_row_group_first td {
  border-top-width: 2px;
}

#uowdnvkubv .gt_row_group_first th {
  border-top-width: 2px;
}

#uowdnvkubv .gt_summary_row {
  color: #333333;
  background-color: #D5D5D5;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#uowdnvkubv .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D5D5D5;
}

#uowdnvkubv .gt_first_summary_row.thick {
  border-top-width: 2px;
}

#uowdnvkubv .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#uowdnvkubv .gt_grand_summary_row {
  color: #FFFFFF;
  background-color: #929292;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#uowdnvkubv .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D5D5D5;
}

#uowdnvkubv .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D5D5D5;
}

#uowdnvkubv .gt_striped {
  background-color: #F4F4F4;
}

#uowdnvkubv .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#uowdnvkubv .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#uowdnvkubv .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#uowdnvkubv .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#uowdnvkubv .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#uowdnvkubv .gt_left {
  text-align: left;
}

#uowdnvkubv .gt_center {
  text-align: center;
}

#uowdnvkubv .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#uowdnvkubv .gt_font_normal {
  font-weight: normal;
}

#uowdnvkubv .gt_font_bold {
  font-weight: bold;
}

#uowdnvkubv .gt_font_italic {
  font-style: italic;
}

#uowdnvkubv .gt_super {
  font-size: 65%;
}

#uowdnvkubv .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}

#uowdnvkubv .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}

#uowdnvkubv .gt_indent_1 {
  text-indent: 5px;
}

#uowdnvkubv .gt_indent_2 {
  text-indent: 10px;
}

#uowdnvkubv .gt_indent_3 {
  text-indent: 15px;
}

#uowdnvkubv .gt_indent_4 {
  text-indent: 20px;
}

#uowdnvkubv .gt_indent_5 {
  text-indent: 25px;
}

#uowdnvkubv .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}

#uowdnvkubv div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>
<table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false">
  <thead>
    <tr class="gt_heading">
      <td colspan="10" class="gt_heading gt_title gt_font_normal gt_bottom_border" style>Memory of Beliefs: convergence</td>
    </tr>
    
    <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Model">Model</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Family">Family</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="N_obs">N_obs</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="N_participants">N_participants</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Chains">Chains</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Draws">Draws</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Max_Rhat">Max_Rhat</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Min_ESS_ratio">Min_ESS_ratio</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Divergent_pct">Divergent_pct</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Criterion">Criterion</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr><td headers="Model" class="gt_row gt_left">MemoryBelief</td>
<td headers="Family" class="gt_row gt_left">Categorical</td>
<td headers="N_obs" class="gt_row gt_right">21120</td>
<td headers="N_participants" class="gt_row gt_right">220</td>
<td headers="Chains" class="gt_row gt_right">8</td>
<td headers="Draws" class="gt_row gt_right">4000</td>
<td headers="Max_Rhat" class="gt_row gt_right">1.043</td>
<td headers="Min_ESS_ratio" class="gt_row gt_right">0.035</td>
<td headers="Divergent_pct" class="gt_row gt_right">0</td>
<td headers="Criterion" class="gt_row gt_left">loo</td></tr>
  </tbody>
  
</table>
</div>
```


::: {.callout-note collapse="true" title="Memory of Beliefs: convergence (Markdown table, for text readers)"}

|Model        |Family      | N_obs| N_participants| Chains| Draws| Max_Rhat| Min_ESS_ratio| Divergent_pct|Criterion |
|:------------|:-----------|-----:|--------------:|------:|-----:|--------:|-------------:|-------------:|:---------|
|MemoryBelief |Categorical | 21120|            220|      8|  4000|    1.043|         0.035|             0|loo       |

:::

```{=html}
<div id="ddbfcxvmwc" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#ddbfcxvmwc table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#ddbfcxvmwc thead, #ddbfcxvmwc tbody, #ddbfcxvmwc tfoot, #ddbfcxvmwc tr, #ddbfcxvmwc td, #ddbfcxvmwc th {
  border-style: none;
}

#ddbfcxvmwc p {
  margin: 0;
  padding: 0;
}

#ddbfcxvmwc .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 13px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 3px;
  border-top-color: #D5D5D5;
  border-right-style: solid;
  border-right-width: 3px;
  border-right-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 3px;
  border-bottom-color: #D5D5D5;
  border-left-style: solid;
  border-left-width: 3px;
  border-left-color: #D5D5D5;
}

#ddbfcxvmwc .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}

#ddbfcxvmwc .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#ddbfcxvmwc .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#ddbfcxvmwc .gt_heading {
  background-color: #FFFFFF;
  text-align: left;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#ddbfcxvmwc .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#ddbfcxvmwc .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#ddbfcxvmwc .gt_col_heading {
  color: #FFFFFF;
  background-color: #000000;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#ddbfcxvmwc .gt_column_spanner_outer {
  color: #FFFFFF;
  background-color: #000000;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#ddbfcxvmwc .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#ddbfcxvmwc .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#ddbfcxvmwc .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#ddbfcxvmwc .gt_spanner_row {
  border-bottom-style: hidden;
}

#ddbfcxvmwc .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}

#ddbfcxvmwc .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  vertical-align: middle;
}

#ddbfcxvmwc .gt_from_md > :first-child {
  margin-top: 0;
}

#ddbfcxvmwc .gt_from_md > :last-child {
  margin-bottom: 0;
}

#ddbfcxvmwc .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D5D5D5;
  border-left-style: solid;
  border-left-width: 1px;
  border-left-color: #D5D5D5;
  border-right-style: solid;
  border-right-width: 1px;
  border-right-color: #D5D5D5;
  vertical-align: middle;
  overflow-x: hidden;
}

#ddbfcxvmwc .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #5F5F5F;
  padding-left: 5px;
  padding-right: 5px;
}

#ddbfcxvmwc .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}

#ddbfcxvmwc .gt_row_group_first td {
  border-top-width: 2px;
}

#ddbfcxvmwc .gt_row_group_first th {
  border-top-width: 2px;
}

#ddbfcxvmwc .gt_summary_row {
  color: #333333;
  background-color: #D5D5D5;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#ddbfcxvmwc .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D5D5D5;
}

#ddbfcxvmwc .gt_first_summary_row.thick {
  border-top-width: 2px;
}

#ddbfcxvmwc .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#ddbfcxvmwc .gt_grand_summary_row {
  color: #FFFFFF;
  background-color: #929292;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#ddbfcxvmwc .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D5D5D5;
}

#ddbfcxvmwc .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D5D5D5;
}

#ddbfcxvmwc .gt_striped {
  background-color: #F4F4F4;
}

#ddbfcxvmwc .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#ddbfcxvmwc .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#ddbfcxvmwc .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#ddbfcxvmwc .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#ddbfcxvmwc .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#ddbfcxvmwc .gt_left {
  text-align: left;
}

#ddbfcxvmwc .gt_center {
  text-align: center;
}

#ddbfcxvmwc .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#ddbfcxvmwc .gt_font_normal {
  font-weight: normal;
}

#ddbfcxvmwc .gt_font_bold {
  font-weight: bold;
}

#ddbfcxvmwc .gt_font_italic {
  font-style: italic;
}

#ddbfcxvmwc .gt_super {
  font-size: 65%;
}

#ddbfcxvmwc .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}

#ddbfcxvmwc .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}

#ddbfcxvmwc .gt_indent_1 {
  text-indent: 5px;
}

#ddbfcxvmwc .gt_indent_2 {
  text-indent: 10px;
}

#ddbfcxvmwc .gt_indent_3 {
  text-indent: 15px;
}

#ddbfcxvmwc .gt_indent_4 {
  text-indent: 20px;
}

#ddbfcxvmwc .gt_indent_5 {
  text-indent: 25px;
}

#ddbfcxvmwc .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}

#ddbfcxvmwc div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>
<table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false">
  <thead>
    <tr class="gt_heading">
      <td colspan="5" class="gt_heading gt_title gt_font_normal gt_bottom_border" style>Memory of Beliefs: probability of each answer per Belief (marginal means)</td>
    </tr>
    
    <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="1" colspan="1" scope="col" id="Belief">Belief</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="1" colspan="1" scope="col" id="Response">Response</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Median">Median</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="CI_low">CI_low</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="CI_high">CI_high</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr><td headers="Belief" class="gt_row gt_center">Human Original</td>
<td headers="Response" class="gt_row gt_center">Human Original</td>
<td headers="Median" class="gt_row gt_right">0.21</td>
<td headers="CI_low" class="gt_row gt_right">0.19</td>
<td headers="CI_high" class="gt_row gt_right">0.23</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">Human Forgery</td>
<td headers="Response" class="gt_row gt_center gt_striped">Human Original</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.17</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.15</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.20</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">AI Original</td>
<td headers="Response" class="gt_row gt_center">Human Original</td>
<td headers="Median" class="gt_row gt_right">0.13</td>
<td headers="CI_low" class="gt_row gt_right">0.11</td>
<td headers="CI_high" class="gt_row gt_right">0.14</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">AI Copy</td>
<td headers="Response" class="gt_row gt_center gt_striped">Human Original</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.14</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.12</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.16</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">None</td>
<td headers="Response" class="gt_row gt_center">Human Original</td>
<td headers="Median" class="gt_row gt_right">0.06</td>
<td headers="CI_low" class="gt_row gt_right">0.06</td>
<td headers="CI_high" class="gt_row gt_right">0.08</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">Human Original</td>
<td headers="Response" class="gt_row gt_center gt_striped">Human Forgery</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.07</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.06</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.08</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">Human Forgery</td>
<td headers="Response" class="gt_row gt_center">Human Forgery</td>
<td headers="Median" class="gt_row gt_right">0.09</td>
<td headers="CI_low" class="gt_row gt_right">0.07</td>
<td headers="CI_high" class="gt_row gt_right">0.10</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">AI Original</td>
<td headers="Response" class="gt_row gt_center gt_striped">Human Forgery</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.06</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.05</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.07</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">AI Copy</td>
<td headers="Response" class="gt_row gt_center">Human Forgery</td>
<td headers="Median" class="gt_row gt_right">0.07</td>
<td headers="CI_low" class="gt_row gt_right">0.06</td>
<td headers="CI_high" class="gt_row gt_right">0.09</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">None</td>
<td headers="Response" class="gt_row gt_center gt_striped">Human Forgery</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.03</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.02</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.03</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">Human Original</td>
<td headers="Response" class="gt_row gt_center">AI Original</td>
<td headers="Median" class="gt_row gt_right">0.09</td>
<td headers="CI_low" class="gt_row gt_right">0.08</td>
<td headers="CI_high" class="gt_row gt_right">0.11</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">Human Forgery</td>
<td headers="Response" class="gt_row gt_center gt_striped">AI Original</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.10</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.08</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.12</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">AI Original</td>
<td headers="Response" class="gt_row gt_center">AI Original</td>
<td headers="Median" class="gt_row gt_right">0.16</td>
<td headers="CI_low" class="gt_row gt_right">0.13</td>
<td headers="CI_high" class="gt_row gt_right">0.18</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">AI Copy</td>
<td headers="Response" class="gt_row gt_center gt_striped">AI Original</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.13</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.11</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.15</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">None</td>
<td headers="Response" class="gt_row gt_center">AI Original</td>
<td headers="Median" class="gt_row gt_right">0.04</td>
<td headers="CI_low" class="gt_row gt_right">0.03</td>
<td headers="CI_high" class="gt_row gt_right">0.05</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">Human Original</td>
<td headers="Response" class="gt_row gt_center gt_striped">AI Copy</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.03</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.02</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.04</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">Human Forgery</td>
<td headers="Response" class="gt_row gt_center">AI Copy</td>
<td headers="Median" class="gt_row gt_right">0.04</td>
<td headers="CI_low" class="gt_row gt_right">0.03</td>
<td headers="CI_high" class="gt_row gt_right">0.05</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">AI Original</td>
<td headers="Response" class="gt_row gt_center gt_striped">AI Copy</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.05</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.04</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.06</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">AI Copy</td>
<td headers="Response" class="gt_row gt_center">AI Copy</td>
<td headers="Median" class="gt_row gt_right">0.05</td>
<td headers="CI_low" class="gt_row gt_right">0.04</td>
<td headers="CI_high" class="gt_row gt_right">0.06</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">None</td>
<td headers="Response" class="gt_row gt_center gt_striped">AI Copy</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.01</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.01</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.01</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">Human Original</td>
<td headers="Response" class="gt_row gt_center">Not recognized</td>
<td headers="Median" class="gt_row gt_right">0.60</td>
<td headers="CI_low" class="gt_row gt_right">0.56</td>
<td headers="CI_high" class="gt_row gt_right">0.64</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">Human Forgery</td>
<td headers="Response" class="gt_row gt_center gt_striped">Not recognized</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.60</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.56</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.64</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">AI Original</td>
<td headers="Response" class="gt_row gt_center">Not recognized</td>
<td headers="Median" class="gt_row gt_right">0.61</td>
<td headers="CI_low" class="gt_row gt_right">0.57</td>
<td headers="CI_high" class="gt_row gt_right">0.65</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">AI Copy</td>
<td headers="Response" class="gt_row gt_center gt_striped">Not recognized</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.62</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.58</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.65</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">None</td>
<td headers="Response" class="gt_row gt_center">Not recognized</td>
<td headers="Median" class="gt_row gt_right">0.86</td>
<td headers="CI_low" class="gt_row gt_right">0.84</td>
<td headers="CI_high" class="gt_row gt_right">0.88</td></tr>
  </tbody>
  
</table>
</div>
```


::: {.callout-note collapse="true" title="Memory of Beliefs: probability of each answer per Belief (marginal means) (Markdown table, for text readers)"}

|Belief         |Response       |Median |CI_low |CI_high |
|:--------------|:--------------|:------|:------|:-------|
|Human Original |Human Original |0.21   |0.19   |0.23    |
|Human Forgery  |Human Original |0.17   |0.15   |0.20    |
|AI Original    |Human Original |0.13   |0.11   |0.14    |
|AI Copy        |Human Original |0.14   |0.12   |0.16    |
|None           |Human Original |0.06   |0.06   |0.08    |
|Human Original |Human Forgery  |0.07   |0.06   |0.08    |
|Human Forgery  |Human Forgery  |0.09   |0.07   |0.10    |
|AI Original    |Human Forgery  |0.06   |0.05   |0.07    |
|AI Copy        |Human Forgery  |0.07   |0.06   |0.09    |
|None           |Human Forgery  |0.03   |0.02   |0.03    |
|Human Original |AI Original    |0.09   |0.08   |0.11    |
|Human Forgery  |AI Original    |0.10   |0.08   |0.12    |
|AI Original    |AI Original    |0.16   |0.13   |0.18    |
|AI Copy        |AI Original    |0.13   |0.11   |0.15    |
|None           |AI Original    |0.04   |0.03   |0.05    |
|Human Original |AI Copy        |0.03   |0.02   |0.04    |
|Human Forgery  |AI Copy        |0.04   |0.03   |0.05    |
|AI Original    |AI Copy        |0.05   |0.04   |0.06    |
|AI Copy        |AI Copy        |0.05   |0.04   |0.06    |
|None           |AI Copy        |0.01   |0.01   |0.01    |
|Human Original |Not recognized |0.60   |0.56   |0.64    |
|Human Forgery  |Not recognized |0.60   |0.56   |0.64    |
|AI Original    |Not recognized |0.61   |0.57   |0.65    |
|AI Copy        |Not recognized |0.62   |0.58   |0.65    |
|None           |Not recognized |0.86   |0.84   |0.88    |

:::

::: {.callout-note collapse="true" title="Memory of Beliefs: all 300 contrasts (Markdown table, for text readers)"}

|Level1         |Response1      |Level2         |Response2      |Median |CI_low |CI_high |pd   |Effect   |
|:--------------|:--------------|:--------------|:--------------|:------|:------|:-------|:----|:--------|
|Human Forgery  |Human Original |Human Original |Human Original |-0.03  |-0.05  |-0.01   |1.00 |Negative |
|AI Original    |Human Original |Human Original |Human Original |-0.08  |-0.10  |-0.06   |1.00 |Negative |
|AI Copy        |Human Original |Human Original |Human Original |-0.07  |-0.09  |-0.05   |1.00 |Negative |
|None           |Human Original |Human Original |Human Original |-0.14  |-0.17  |-0.11   |1.00 |Negative |
|Human Original |Human Forgery  |Human Original |Human Original |-0.13  |-0.15  |-0.11   |1.00 |Negative |
|Human Forgery  |Human Forgery  |Human Original |Human Original |-0.12  |-0.14  |-0.10   |1.00 |Negative |
|AI Original    |Human Forgery  |Human Original |Human Original |-0.15  |-0.17  |-0.13   |1.00 |Negative |
|AI Copy        |Human Forgery  |Human Original |Human Original |-0.13  |-0.15  |-0.11   |1.00 |Negative |
|None           |Human Forgery  |Human Original |Human Original |-0.18  |-0.20  |-0.16   |1.00 |Negative |
|Human Original |AI Original    |Human Original |Human Original |-0.11  |-0.14  |-0.09   |1.00 |Negative |
|Human Forgery  |AI Original    |Human Original |Human Original |-0.10  |-0.13  |-0.08   |1.00 |Negative |
|AI Original    |AI Original    |Human Original |Human Original |-0.05  |-0.07  |-0.02   |1.00 |Negative |
|AI Copy        |AI Original    |Human Original |Human Original |-0.08  |-0.10  |-0.06   |1.00 |Negative |
|None           |AI Original    |Human Original |Human Original |-0.17  |-0.19  |-0.15   |1.00 |Negative |
|Human Original |AI Copy        |Human Original |Human Original |-0.18  |-0.20  |-0.16   |1.00 |Negative |
|Human Forgery  |AI Copy        |Human Original |Human Original |-0.17  |-0.19  |-0.14   |1.00 |Negative |
|AI Original    |AI Copy        |Human Original |Human Original |-0.16  |-0.18  |-0.14   |1.00 |Negative |
|AI Copy        |AI Copy        |Human Original |Human Original |-0.16  |-0.18  |-0.14   |1.00 |Negative |
|None           |AI Copy        |Human Original |Human Original |-0.19  |-0.22  |-0.17   |1.00 |Negative |
|Human Original |Not recognized |Human Original |Human Original |0.40   |0.34   |0.45    |1.00 |Positive |
|Human Forgery  |Not recognized |Human Original |Human Original |0.39   |0.33   |0.45    |1.00 |Positive |
|AI Original    |Not recognized |Human Original |Human Original |0.40   |0.34   |0.46    |1.00 |Positive |
|AI Copy        |Not recognized |Human Original |Human Original |0.41   |0.35   |0.46    |1.00 |Positive |
|None           |Not recognized |Human Original |Human Original |0.66   |0.63   |0.67    |1.00 |Positive |
|AI Original    |Human Original |Human Forgery  |Human Original |-0.05  |-0.07  |-0.03   |1.00 |Negative |
|AI Copy        |Human Original |Human Forgery  |Human Original |-0.04  |-0.06  |-0.01   |1.00 |Negative |
|None           |Human Original |Human Forgery  |Human Original |-0.11  |-0.14  |-0.08   |1.00 |Negative |
|Human Original |Human Forgery  |Human Forgery  |Human Original |-0.10  |-0.12  |-0.08   |1.00 |Negative |
|Human Forgery  |Human Forgery  |Human Forgery  |Human Original |-0.09  |-0.11  |-0.06   |1.00 |Negative |
|AI Original    |Human Forgery  |Human Forgery  |Human Original |-0.11  |-0.14  |-0.09   |1.00 |Negative |
|AI Copy        |Human Forgery  |Human Forgery  |Human Original |-0.10  |-0.12  |-0.08   |1.00 |Negative |
|None           |Human Forgery  |Human Forgery  |Human Original |-0.15  |-0.17  |-0.12   |1.00 |Negative |
|Human Original |AI Original    |Human Forgery  |Human Original |-0.08  |-0.11  |-0.06   |1.00 |Negative |
|Human Forgery  |AI Original    |Human Forgery  |Human Original |-0.07  |-0.10  |-0.04   |1.00 |Negative |
|AI Original    |AI Original    |Human Forgery  |Human Original |-0.02  |-0.05  |0.01    |0.89 |n.s.     |
|AI Copy        |AI Original    |Human Forgery  |Human Original |-0.05  |-0.07  |-0.02   |1.00 |Negative |
|None           |AI Original    |Human Forgery  |Human Original |-0.14  |-0.16  |-0.11   |1.00 |Negative |
|Human Original |AI Copy        |Human Forgery  |Human Original |-0.14  |-0.17  |-0.12   |1.00 |Negative |
|Human Forgery  |AI Copy        |Human Forgery  |Human Original |-0.13  |-0.16  |-0.11   |1.00 |Negative |
|AI Original    |AI Copy        |Human Forgery  |Human Original |-0.12  |-0.15  |-0.10   |1.00 |Negative |
|AI Copy        |AI Copy        |Human Forgery  |Human Original |-0.13  |-0.15  |-0.11   |1.00 |Negative |
|None           |AI Copy        |Human Forgery  |Human Original |-0.16  |-0.19  |-0.14   |1.00 |Negative |
|Human Original |Not recognized |Human Forgery  |Human Original |0.43   |0.37   |0.48    |1.00 |Positive |
|Human Forgery  |Not recognized |Human Forgery  |Human Original |0.43   |0.36   |0.48    |1.00 |Positive |
|AI Original    |Not recognized |Human Forgery  |Human Original |0.44   |0.38   |0.49    |1.00 |Positive |
|AI Copy        |Not recognized |Human Forgery  |Human Original |0.44   |0.39   |0.49    |1.00 |Positive |
|None           |Not recognized |Human Forgery  |Human Original |0.69   |0.66   |0.71    |1.00 |Positive |
|AI Copy        |Human Original |AI Original    |Human Original |0.01   |-0.01  |0.03    |0.86 |n.s.     |
|None           |Human Original |AI Original    |Human Original |-0.06  |-0.08  |-0.04   |1.00 |Negative |
|Human Original |Human Forgery  |AI Original    |Human Original |-0.05  |-0.07  |-0.04   |1.00 |Negative |
|Human Forgery  |Human Forgery  |AI Original    |Human Original |-0.04  |-0.06  |-0.02   |1.00 |Negative |
|AI Original    |Human Forgery  |AI Original    |Human Original |-0.07  |-0.09  |-0.05   |1.00 |Negative |
|AI Copy        |Human Forgery  |AI Original    |Human Original |-0.05  |-0.07  |-0.03   |1.00 |Negative |
|None           |Human Forgery  |AI Original    |Human Original |-0.10  |-0.12  |-0.08   |1.00 |Negative |
|Human Original |AI Original    |AI Original    |Human Original |-0.03  |-0.05  |-0.01   |1.00 |Negative |
|Human Forgery  |AI Original    |AI Original    |Human Original |-0.02  |-0.05  |0.00    |0.97 |n.s.     |
|AI Original    |AI Original    |AI Original    |Human Original |0.03   |0.00   |0.06    |0.99 |Positive |
|AI Copy        |AI Original    |AI Original    |Human Original |0.00   |-0.02  |0.03    |0.52 |n.s.     |
|None           |AI Original    |AI Original    |Human Original |-0.09  |-0.11  |-0.07   |1.00 |Negative |
|Human Original |AI Copy        |AI Original    |Human Original |-0.10  |-0.11  |-0.08   |1.00 |Negative |
|Human Forgery  |AI Copy        |AI Original    |Human Original |-0.09  |-0.11  |-0.07   |1.00 |Negative |
|AI Original    |AI Copy        |AI Original    |Human Original |-0.08  |-0.10  |-0.06   |1.00 |Negative |
|AI Copy        |AI Copy        |AI Original    |Human Original |-0.08  |-0.10  |-0.06   |1.00 |Negative |
|None           |AI Copy        |AI Original    |Human Original |-0.11  |-0.13  |-0.10   |1.00 |Negative |
|Human Original |Not recognized |AI Original    |Human Original |0.48   |0.43   |0.52    |1.00 |Positive |
|Human Forgery  |Not recognized |AI Original    |Human Original |0.47   |0.42   |0.52    |1.00 |Positive |
|AI Original    |Not recognized |AI Original    |Human Original |0.48   |0.43   |0.54    |1.00 |Positive |
|AI Copy        |Not recognized |AI Original    |Human Original |0.49   |0.44   |0.54    |1.00 |Positive |
|None           |Not recognized |AI Original    |Human Original |0.74   |0.71   |0.75    |1.00 |Positive |
|None           |Human Original |AI Copy        |Human Original |-0.07  |-0.10  |-0.05   |1.00 |Negative |
|Human Original |Human Forgery  |AI Copy        |Human Original |-0.06  |-0.08  |-0.05   |1.00 |Negative |
|Human Forgery  |Human Forgery  |AI Copy        |Human Original |-0.05  |-0.07  |-0.03   |1.00 |Negative |
|AI Original    |Human Forgery  |AI Copy        |Human Original |-0.08  |-0.10  |-0.06   |1.00 |Negative |
|AI Copy        |Human Forgery  |AI Copy        |Human Original |-0.06  |-0.08  |-0.04   |1.00 |Negative |
|None           |Human Forgery  |AI Copy        |Human Original |-0.11  |-0.13  |-0.09   |1.00 |Negative |
|Human Original |AI Original    |AI Copy        |Human Original |-0.05  |-0.07  |-0.02   |1.00 |Negative |
|Human Forgery  |AI Original    |AI Copy        |Human Original |-0.04  |-0.06  |-0.01   |0.99 |Negative |
|AI Original    |AI Original    |AI Copy        |Human Original |0.02   |-0.01  |0.05    |0.94 |n.s.     |
|AI Copy        |AI Original    |AI Copy        |Human Original |-0.01  |-0.03  |0.02    |0.79 |n.s.     |
|None           |AI Original    |AI Copy        |Human Original |-0.10  |-0.12  |-0.08   |1.00 |Negative |
|Human Original |AI Copy        |AI Copy        |Human Original |-0.11  |-0.13  |-0.09   |1.00 |Negative |
|Human Forgery  |AI Copy        |AI Copy        |Human Original |-0.10  |-0.12  |-0.08   |1.00 |Negative |
|AI Original    |AI Copy        |AI Copy        |Human Original |-0.09  |-0.11  |-0.07   |1.00 |Negative |
|AI Copy        |AI Copy        |AI Copy        |Human Original |-0.09  |-0.11  |-0.07   |1.00 |Negative |
|None           |AI Copy        |AI Copy        |Human Original |-0.12  |-0.15  |-0.11   |1.00 |Negative |
|Human Original |Not recognized |AI Copy        |Human Original |0.46   |0.41   |0.51    |1.00 |Positive |
|Human Forgery  |Not recognized |AI Copy        |Human Original |0.46   |0.41   |0.51    |1.00 |Positive |
|AI Original    |Not recognized |AI Copy        |Human Original |0.47   |0.42   |0.52    |1.00 |Positive |
|AI Copy        |Not recognized |AI Copy        |Human Original |0.48   |0.42   |0.53    |1.00 |Positive |
|None           |Not recognized |AI Copy        |Human Original |0.72   |0.70   |0.74    |1.00 |Positive |
|Human Original |Human Forgery  |None           |Human Original |0.01   |-0.01  |0.02    |0.83 |n.s.     |
|Human Forgery  |Human Forgery  |None           |Human Original |0.02   |0.00   |0.04    |0.97 |n.s.     |
|AI Original    |Human Forgery  |None           |Human Original |-0.01  |-0.02  |0.01    |0.74 |n.s.     |
|AI Copy        |Human Forgery  |None           |Human Original |0.01   |-0.01  |0.03    |0.82 |n.s.     |
|None           |Human Forgery  |None           |Human Original |-0.04  |-0.05  |-0.03   |1.00 |Negative |
|Human Original |AI Original    |None           |Human Original |0.03   |0.01   |0.05    |1.00 |Positive |
|Human Forgery  |AI Original    |None           |Human Original |0.04   |0.01   |0.06    |1.00 |Positive |
|AI Original    |AI Original    |None           |Human Original |0.09   |0.06   |0.12    |1.00 |Positive |
|AI Copy        |AI Original    |None           |Human Original |0.06   |0.04   |0.09    |1.00 |Positive |
|None           |AI Original    |None           |Human Original |-0.03  |-0.04  |-0.02   |1.00 |Negative |
|Human Original |AI Copy        |None           |Human Original |-0.04  |-0.05  |-0.02   |1.00 |Negative |
|Human Forgery  |AI Copy        |None           |Human Original |-0.03  |-0.04  |-0.01   |1.00 |Negative |
|AI Original    |AI Copy        |None           |Human Original |-0.01  |-0.03  |0.00    |0.97 |n.s.     |
|AI Copy        |AI Copy        |None           |Human Original |-0.02  |-0.04  |0.00    |1.00 |Negative |
|None           |AI Copy        |None           |Human Original |-0.05  |-0.06  |-0.05   |1.00 |Negative |
|Human Original |Not recognized |None           |Human Original |0.54   |0.50   |0.57    |1.00 |Positive |
|Human Forgery  |Not recognized |None           |Human Original |0.53   |0.49   |0.57    |1.00 |Positive |
|AI Original    |Not recognized |None           |Human Original |0.54   |0.50   |0.58    |1.00 |Positive |
|AI Copy        |Not recognized |None           |Human Original |0.55   |0.51   |0.59    |1.00 |Positive |
|None           |Not recognized |None           |Human Original |0.80   |0.76   |0.82    |1.00 |Positive |
|Human Forgery  |Human Forgery  |Human Original |Human Forgery  |0.01   |0.00   |0.03    |0.95 |n.s.     |
|AI Original    |Human Forgery  |Human Original |Human Forgery  |-0.01  |-0.03  |0.00    |0.98 |Negative |
|AI Copy        |Human Forgery  |Human Original |Human Forgery  |0.00   |-0.01  |0.01    |0.53 |n.s.     |
|None           |Human Forgery  |Human Original |Human Forgery  |-0.05  |-0.06  |-0.03   |1.00 |Negative |
|Human Original |AI Original    |Human Original |Human Forgery  |0.02   |0.00   |0.04    |0.99 |Positive |
|Human Forgery  |AI Original    |Human Original |Human Forgery  |0.03   |0.01   |0.05    |1.00 |Positive |
|AI Original    |AI Original    |Human Original |Human Forgery  |0.08   |0.06   |0.11    |1.00 |Positive |
|AI Copy        |AI Original    |Human Original |Human Forgery  |0.05   |0.03   |0.07    |1.00 |Positive |
|None           |AI Original    |Human Original |Human Forgery  |-0.04  |-0.05  |-0.02   |1.00 |Negative |
|Human Original |AI Copy        |Human Original |Human Forgery  |-0.04  |-0.05  |-0.03   |1.00 |Negative |
|Human Forgery  |AI Copy        |Human Original |Human Forgery  |-0.03  |-0.05  |-0.02   |1.00 |Negative |
|AI Original    |AI Copy        |Human Original |Human Forgery  |-0.02  |-0.03  |-0.01   |1.00 |Negative |
|AI Copy        |AI Copy        |Human Original |Human Forgery  |-0.03  |-0.04  |-0.02   |1.00 |Negative |
|None           |AI Copy        |Human Original |Human Forgery  |-0.06  |-0.07  |-0.05   |1.00 |Negative |
|Human Original |Not recognized |Human Original |Human Forgery  |0.53   |0.48   |0.57    |1.00 |Positive |
|Human Forgery  |Not recognized |Human Original |Human Forgery  |0.53   |0.48   |0.57    |1.00 |Positive |
|AI Original    |Not recognized |Human Original |Human Forgery  |0.54   |0.49   |0.58    |1.00 |Positive |
|AI Copy        |Not recognized |Human Original |Human Forgery  |0.55   |0.50   |0.59    |1.00 |Positive |
|None           |Not recognized |Human Original |Human Forgery  |0.79   |0.76   |0.80    |1.00 |Positive |
|AI Original    |Human Forgery  |Human Forgery  |Human Forgery  |-0.03  |-0.04  |-0.01   |1.00 |Negative |
|AI Copy        |Human Forgery  |Human Forgery  |Human Forgery  |-0.01  |-0.03  |0.01    |0.91 |n.s.     |
|None           |Human Forgery  |Human Forgery  |Human Forgery  |-0.06  |-0.08  |-0.04   |1.00 |Negative |
|Human Original |AI Original    |Human Forgery  |Human Forgery  |0.01   |-0.01  |0.03    |0.73 |n.s.     |
|Human Forgery  |AI Original    |Human Forgery  |Human Forgery  |0.02   |-0.01  |0.04    |0.89 |n.s.     |
|AI Original    |AI Original    |Human Forgery  |Human Forgery  |0.07   |0.05   |0.10    |1.00 |Positive |
|AI Copy        |AI Original    |Human Forgery  |Human Forgery  |0.04   |0.02   |0.07    |1.00 |Positive |
|None           |AI Original    |Human Forgery  |Human Forgery  |-0.05  |-0.07  |-0.03   |1.00 |Negative |
|Human Original |AI Copy        |Human Forgery  |Human Forgery  |-0.06  |-0.07  |-0.04   |1.00 |Negative |
|Human Forgery  |AI Copy        |Human Forgery  |Human Forgery  |-0.05  |-0.06  |-0.03   |1.00 |Negative |
|AI Original    |AI Copy        |Human Forgery  |Human Forgery  |-0.04  |-0.05  |-0.02   |1.00 |Negative |
|AI Copy        |AI Copy        |Human Forgery  |Human Forgery  |-0.04  |-0.06  |-0.02   |1.00 |Negative |
|None           |AI Copy        |Human Forgery  |Human Forgery  |-0.07  |-0.09  |-0.06   |1.00 |Negative |
|Human Original |Not recognized |Human Forgery  |Human Forgery  |0.52   |0.47   |0.56    |1.00 |Positive |
|Human Forgery  |Not recognized |Human Forgery  |Human Forgery  |0.51   |0.46   |0.56    |1.00 |Positive |
|AI Original    |Not recognized |Human Forgery  |Human Forgery  |0.52   |0.47   |0.57    |1.00 |Positive |
|AI Copy        |Not recognized |Human Forgery  |Human Forgery  |0.53   |0.48   |0.58    |1.00 |Positive |
|None           |Not recognized |Human Forgery  |Human Forgery  |0.77   |0.75   |0.79    |1.00 |Positive |
|AI Copy        |Human Forgery  |AI Original    |Human Forgery  |0.01   |0.00   |0.03    |0.96 |n.s.     |
|None           |Human Forgery  |AI Original    |Human Forgery  |-0.03  |-0.05  |-0.02   |1.00 |Negative |
|Human Original |AI Original    |AI Original    |Human Forgery  |0.03   |0.01   |0.05    |1.00 |Positive |
|Human Forgery  |AI Original    |AI Original    |Human Forgery  |0.04   |0.02   |0.07    |1.00 |Positive |
|AI Original    |AI Original    |AI Original    |Human Forgery  |0.10   |0.07   |0.12    |1.00 |Positive |
|AI Copy        |AI Original    |AI Original    |Human Forgery  |0.07   |0.05   |0.09    |1.00 |Positive |
|None           |AI Original    |AI Original    |Human Forgery  |-0.02  |-0.04  |-0.01   |1.00 |Negative |
|Human Original |AI Copy        |AI Original    |Human Forgery  |-0.03  |-0.04  |-0.02   |1.00 |Negative |
|Human Forgery  |AI Copy        |AI Original    |Human Forgery  |-0.02  |-0.04  |0.00    |0.99 |Negative |
|AI Original    |AI Copy        |AI Original    |Human Forgery  |-0.01  |-0.02  |0.01    |0.89 |n.s.     |
|AI Copy        |AI Copy        |AI Original    |Human Forgery  |-0.01  |-0.03  |0.00    |0.98 |Negative |
|None           |AI Copy        |AI Original    |Human Forgery  |-0.05  |-0.06  |-0.04   |1.00 |Negative |
|Human Original |Not recognized |AI Original    |Human Forgery  |0.54   |0.50   |0.58    |1.00 |Positive |
|Human Forgery  |Not recognized |AI Original    |Human Forgery  |0.54   |0.49   |0.58    |1.00 |Positive |
|AI Original    |Not recognized |AI Original    |Human Forgery  |0.55   |0.50   |0.59    |1.00 |Positive |
|AI Copy        |Not recognized |AI Original    |Human Forgery  |0.56   |0.51   |0.60    |1.00 |Positive |
|None           |Not recognized |AI Original    |Human Forgery  |0.80   |0.78   |0.82    |1.00 |Positive |
|None           |Human Forgery  |AI Copy        |Human Forgery  |-0.05  |-0.06  |-0.03   |1.00 |Negative |
|Human Original |AI Original    |AI Copy        |Human Forgery  |0.02   |0.00   |0.04    |0.98 |Positive |
|Human Forgery  |AI Original    |AI Copy        |Human Forgery  |0.03   |0.01   |0.05    |0.99 |Positive |
|AI Original    |AI Original    |AI Copy        |Human Forgery  |0.08   |0.06   |0.11    |1.00 |Positive |
|AI Copy        |AI Original    |AI Copy        |Human Forgery  |0.05   |0.03   |0.08    |1.00 |Positive |
|None           |AI Original    |AI Copy        |Human Forgery  |-0.04  |-0.05  |-0.02   |1.00 |Negative |
|Human Original |AI Copy        |AI Copy        |Human Forgery  |-0.04  |-0.06  |-0.03   |1.00 |Negative |
|Human Forgery  |AI Copy        |AI Copy        |Human Forgery  |-0.03  |-0.05  |-0.02   |1.00 |Negative |
|AI Original    |AI Copy        |AI Copy        |Human Forgery  |-0.02  |-0.04  |-0.01   |1.00 |Negative |
|AI Copy        |AI Copy        |AI Copy        |Human Forgery  |-0.03  |-0.04  |-0.01   |1.00 |Negative |
|None           |AI Copy        |AI Copy        |Human Forgery  |-0.06  |-0.08  |-0.05   |1.00 |Negative |
|Human Original |Not recognized |AI Copy        |Human Forgery  |0.53   |0.48   |0.57    |1.00 |Positive |
|Human Forgery  |Not recognized |AI Copy        |Human Forgery  |0.53   |0.48   |0.57    |1.00 |Positive |
|AI Original    |Not recognized |AI Copy        |Human Forgery  |0.54   |0.49   |0.58    |1.00 |Positive |
|AI Copy        |Not recognized |AI Copy        |Human Forgery  |0.54   |0.49   |0.59    |1.00 |Positive |
|None           |Not recognized |AI Copy        |Human Forgery  |0.79   |0.76   |0.81    |1.00 |Positive |
|Human Original |AI Original    |None           |Human Forgery  |0.06   |0.05   |0.08    |1.00 |Positive |
|Human Forgery  |AI Original    |None           |Human Forgery  |0.07   |0.05   |0.10    |1.00 |Positive |
|AI Original    |AI Original    |None           |Human Forgery  |0.13   |0.10   |0.16    |1.00 |Positive |
|AI Copy        |AI Original    |None           |Human Forgery  |0.10   |0.08   |0.12    |1.00 |Positive |
|None           |AI Original    |None           |Human Forgery  |0.01   |0.00   |0.02    |0.98 |Positive |
|Human Original |AI Copy        |None           |Human Forgery  |0.00   |-0.01  |0.01    |0.69 |n.s.     |
|Human Forgery  |AI Copy        |None           |Human Forgery  |0.01   |0.00   |0.03    |0.98 |Positive |
|AI Original    |AI Copy        |None           |Human Forgery  |0.02   |0.01   |0.04    |1.00 |Positive |
|AI Copy        |AI Copy        |None           |Human Forgery  |0.02   |0.01   |0.03    |1.00 |Positive |
|None           |AI Copy        |None           |Human Forgery  |-0.02  |-0.02  |-0.01   |1.00 |Negative |
|Human Original |Not recognized |None           |Human Forgery  |0.57   |0.54   |0.61    |1.00 |Positive |
|Human Forgery  |Not recognized |None           |Human Forgery  |0.57   |0.53   |0.61    |1.00 |Positive |
|AI Original    |Not recognized |None           |Human Forgery  |0.58   |0.54   |0.62    |1.00 |Positive |
|AI Copy        |Not recognized |None           |Human Forgery  |0.59   |0.55   |0.63    |1.00 |Positive |
|None           |Not recognized |None           |Human Forgery  |0.83   |0.81   |0.85    |1.00 |Positive |
|Human Forgery  |AI Original    |Human Original |AI Original    |0.01   |-0.01  |0.03    |0.86 |n.s.     |
|AI Original    |AI Original    |Human Original |AI Original    |0.06   |0.05   |0.09    |1.00 |Positive |
|AI Copy        |AI Original    |Human Original |AI Original    |0.03   |0.02   |0.05    |1.00 |Positive |
|None           |AI Original    |Human Original |AI Original    |-0.06  |-0.08  |-0.04   |1.00 |Negative |
|Human Original |AI Copy        |Human Original |AI Original    |-0.06  |-0.08  |-0.05   |1.00 |Negative |
|Human Forgery  |AI Copy        |Human Original |AI Original    |-0.05  |-0.07  |-0.03   |1.00 |Negative |
|AI Original    |AI Copy        |Human Original |AI Original    |-0.04  |-0.06  |-0.03   |1.00 |Negative |
|AI Copy        |AI Copy        |Human Original |AI Original    |-0.05  |-0.06  |-0.03   |1.00 |Negative |
|None           |AI Copy        |Human Original |AI Original    |-0.08  |-0.10  |-0.07   |1.00 |Negative |
|Human Original |Not recognized |Human Original |AI Original    |0.51   |0.46   |0.55    |1.00 |Positive |
|Human Forgery  |Not recognized |Human Original |AI Original    |0.51   |0.46   |0.56    |1.00 |Positive |
|AI Original    |Not recognized |Human Original |AI Original    |0.52   |0.47   |0.57    |1.00 |Positive |
|AI Copy        |Not recognized |Human Original |AI Original    |0.53   |0.47   |0.57    |1.00 |Positive |
|None           |Not recognized |Human Original |AI Original    |0.77   |0.74   |0.79    |1.00 |Positive |
|AI Original    |AI Original    |Human Forgery  |AI Original    |0.06   |0.03   |0.08    |1.00 |Positive |
|AI Copy        |AI Original    |Human Forgery  |AI Original    |0.03   |0.00   |0.05    |0.99 |Positive |
|None           |AI Original    |Human Forgery  |AI Original    |-0.06  |-0.09  |-0.04   |1.00 |Negative |
|Human Original |AI Copy        |Human Forgery  |AI Original    |-0.07  |-0.09  |-0.05   |1.00 |Negative |
|Human Forgery  |AI Copy        |Human Forgery  |AI Original    |-0.06  |-0.09  |-0.04   |1.00 |Negative |
|AI Original    |AI Copy        |Human Forgery  |AI Original    |-0.05  |-0.07  |-0.03   |1.00 |Negative |
|AI Copy        |AI Copy        |Human Forgery  |AI Original    |-0.05  |-0.08  |-0.03   |1.00 |Negative |
|None           |AI Copy        |Human Forgery  |AI Original    |-0.09  |-0.11  |-0.07   |1.00 |Negative |
|Human Original |Not recognized |Human Forgery  |AI Original    |0.50   |0.45   |0.55    |1.00 |Positive |
|Human Forgery  |Not recognized |Human Forgery  |AI Original    |0.50   |0.44   |0.55    |1.00 |Positive |
|AI Original    |Not recognized |Human Forgery  |AI Original    |0.51   |0.45   |0.56    |1.00 |Positive |
|AI Copy        |Not recognized |Human Forgery  |AI Original    |0.52   |0.46   |0.57    |1.00 |Positive |
|None           |Not recognized |Human Forgery  |AI Original    |0.76   |0.73   |0.78    |1.00 |Positive |
|AI Copy        |AI Original    |AI Original    |AI Original    |-0.03  |-0.05  |-0.01   |1.00 |Negative |
|None           |AI Original    |AI Original    |AI Original    |-0.12  |-0.15  |-0.09   |1.00 |Negative |
|Human Original |AI Copy        |AI Original    |AI Original    |-0.13  |-0.15  |-0.10   |1.00 |Negative |
|Human Forgery  |AI Copy        |AI Original    |AI Original    |-0.12  |-0.14  |-0.09   |1.00 |Negative |
|AI Original    |AI Copy        |AI Original    |AI Original    |-0.11  |-0.13  |-0.08   |1.00 |Negative |
|AI Copy        |AI Copy        |AI Original    |AI Original    |-0.11  |-0.14  |-0.09   |1.00 |Negative |
|None           |AI Copy        |AI Original    |AI Original    |-0.14  |-0.17  |-0.12   |1.00 |Negative |
|Human Original |Not recognized |AI Original    |AI Original    |0.45   |0.39   |0.50    |1.00 |Positive |
|Human Forgery  |Not recognized |AI Original    |AI Original    |0.44   |0.38   |0.50    |1.00 |Positive |
|AI Original    |Not recognized |AI Original    |AI Original    |0.45   |0.39   |0.51    |1.00 |Positive |
|AI Copy        |Not recognized |AI Original    |AI Original    |0.46   |0.40   |0.52    |1.00 |Positive |
|None           |Not recognized |AI Original    |AI Original    |0.70   |0.67   |0.73    |1.00 |Positive |
|None           |AI Original    |AI Copy        |AI Original    |-0.09  |-0.12  |-0.07   |1.00 |Negative |
|Human Original |AI Copy        |AI Copy        |AI Original    |-0.10  |-0.12  |-0.08   |1.00 |Negative |
|Human Forgery  |AI Copy        |AI Copy        |AI Original    |-0.09  |-0.11  |-0.06   |1.00 |Negative |
|AI Original    |AI Copy        |AI Copy        |AI Original    |-0.08  |-0.10  |-0.05   |1.00 |Negative |
|AI Copy        |AI Copy        |AI Copy        |AI Original    |-0.08  |-0.10  |-0.06   |1.00 |Negative |
|None           |AI Copy        |AI Copy        |AI Original    |-0.11  |-0.14  |-0.09   |1.00 |Negative |
|Human Original |Not recognized |AI Copy        |AI Original    |0.48   |0.42   |0.52    |1.00 |Positive |
|Human Forgery  |Not recognized |AI Copy        |AI Original    |0.47   |0.42   |0.53    |1.00 |Positive |
|AI Original    |Not recognized |AI Copy        |AI Original    |0.48   |0.43   |0.54    |1.00 |Positive |
|AI Copy        |Not recognized |AI Copy        |AI Original    |0.49   |0.43   |0.54    |1.00 |Positive |
|None           |Not recognized |AI Copy        |AI Original    |0.73   |0.71   |0.76    |1.00 |Positive |
|Human Original |AI Copy        |None           |AI Original    |-0.01  |-0.02  |0.00    |0.90 |n.s.     |
|Human Forgery  |AI Copy        |None           |AI Original    |0.00   |-0.01  |0.02    |0.70 |n.s.     |
|AI Original    |AI Copy        |None           |AI Original    |0.01   |0.00   |0.03    |0.97 |n.s.     |
|AI Copy        |AI Copy        |None           |AI Original    |0.01   |0.00   |0.02    |0.92 |n.s.     |
|None           |AI Copy        |None           |AI Original    |-0.02  |-0.03  |-0.02   |1.00 |Negative |
|Human Original |Not recognized |None           |AI Original    |0.56   |0.53   |0.60    |1.00 |Positive |
|Human Forgery  |Not recognized |None           |AI Original    |0.56   |0.52   |0.60    |1.00 |Positive |
|AI Original    |Not recognized |None           |AI Original    |0.57   |0.53   |0.61    |1.00 |Positive |
|AI Copy        |Not recognized |None           |AI Original    |0.58   |0.54   |0.62    |1.00 |Positive |
|None           |Not recognized |None           |AI Original    |0.82   |0.79   |0.85    |1.00 |Positive |
|Human Forgery  |AI Copy        |Human Original |AI Copy        |0.01   |0.00   |0.02    |0.96 |n.s.     |
|AI Original    |AI Copy        |Human Original |AI Copy        |0.02   |0.01   |0.03    |1.00 |Positive |
|AI Copy        |AI Copy        |Human Original |AI Copy        |0.02   |0.01   |0.03    |1.00 |Positive |
|None           |AI Copy        |Human Original |AI Copy        |-0.02  |-0.03  |-0.01   |1.00 |Negative |
|Human Original |Not recognized |Human Original |AI Copy        |0.57   |0.53   |0.61    |1.00 |Positive |
|Human Forgery  |Not recognized |Human Original |AI Copy        |0.57   |0.52   |0.61    |1.00 |Positive |
|AI Original    |Not recognized |Human Original |AI Copy        |0.58   |0.54   |0.62    |1.00 |Positive |
|AI Copy        |Not recognized |Human Original |AI Copy        |0.59   |0.54   |0.63    |1.00 |Positive |
|None           |Not recognized |Human Original |AI Copy        |0.83   |0.81   |0.85    |1.00 |Positive |
|AI Original    |AI Copy        |Human Forgery  |AI Copy        |0.01   |-0.01  |0.02    |0.91 |n.s.     |
|AI Copy        |AI Copy        |Human Forgery  |AI Copy        |0.01   |-0.01  |0.02    |0.79 |n.s.     |
|None           |AI Copy        |Human Forgery  |AI Copy        |-0.03  |-0.04  |-0.02   |1.00 |Negative |
|Human Original |Not recognized |Human Forgery  |AI Copy        |0.56   |0.52   |0.60    |1.00 |Positive |
|Human Forgery  |Not recognized |Human Forgery  |AI Copy        |0.56   |0.51   |0.60    |1.00 |Positive |
|AI Original    |Not recognized |Human Forgery  |AI Copy        |0.57   |0.52   |0.61    |1.00 |Positive |
|AI Copy        |Not recognized |Human Forgery  |AI Copy        |0.58   |0.53   |0.62    |1.00 |Positive |
|None           |Not recognized |Human Forgery  |AI Copy        |0.82   |0.80   |0.84    |1.00 |Positive |
|AI Copy        |AI Copy        |AI Original    |AI Copy        |0.00   |-0.02  |0.01    |0.75 |n.s.     |
|None           |AI Copy        |AI Original    |AI Copy        |-0.04  |-0.05  |-0.03   |1.00 |Negative |
|Human Original |Not recognized |AI Original    |AI Copy        |0.55   |0.51   |0.59    |1.00 |Positive |
|Human Forgery  |Not recognized |AI Original    |AI Copy        |0.55   |0.50   |0.59    |1.00 |Positive |
|AI Original    |Not recognized |AI Original    |AI Copy        |0.56   |0.51   |0.60    |1.00 |Positive |
|AI Copy        |Not recognized |AI Original    |AI Copy        |0.57   |0.52   |0.61    |1.00 |Positive |
|None           |Not recognized |AI Original    |AI Copy        |0.81   |0.79   |0.83    |1.00 |Positive |
|None           |AI Copy        |AI Copy        |AI Copy        |-0.03  |-0.05  |-0.02   |1.00 |Negative |
|Human Original |Not recognized |AI Copy        |AI Copy        |0.56   |0.51   |0.59    |1.00 |Positive |
|Human Forgery  |Not recognized |AI Copy        |AI Copy        |0.55   |0.51   |0.60    |1.00 |Positive |
|AI Original    |Not recognized |AI Copy        |AI Copy        |0.56   |0.52   |0.61    |1.00 |Positive |
|AI Copy        |Not recognized |AI Copy        |AI Copy        |0.57   |0.53   |0.61    |1.00 |Positive |
|None           |Not recognized |AI Copy        |AI Copy        |0.81   |0.79   |0.83    |1.00 |Positive |
|Human Original |Not recognized |None           |AI Copy        |0.59   |0.55   |0.62    |1.00 |Positive |
|Human Forgery  |Not recognized |None           |AI Copy        |0.59   |0.55   |0.63    |1.00 |Positive |
|AI Original    |Not recognized |None           |AI Copy        |0.60   |0.56   |0.64    |1.00 |Positive |
|AI Copy        |Not recognized |None           |AI Copy        |0.61   |0.57   |0.64    |1.00 |Positive |
|None           |Not recognized |None           |AI Copy        |0.85   |0.82   |0.87    |1.00 |Positive |
|Human Forgery  |Not recognized |Human Original |Not recognized |0.00   |-0.03  |0.03    |0.54 |n.s.     |
|AI Original    |Not recognized |Human Original |Not recognized |0.01   |-0.02  |0.03    |0.75 |n.s.     |
|AI Copy        |Not recognized |Human Original |Not recognized |0.02   |-0.01  |0.04    |0.93 |n.s.     |
|None           |Not recognized |Human Original |Not recognized |0.26   |0.21   |0.31    |1.00 |Positive |
|AI Original    |Not recognized |Human Forgery  |Not recognized |0.01   |-0.02  |0.04    |0.72 |n.s.     |
|AI Copy        |Not recognized |Human Forgery  |Not recognized |0.02   |-0.01  |0.05    |0.88 |n.s.     |
|None           |Not recognized |Human Forgery  |Not recognized |0.26   |0.21   |0.31    |1.00 |Positive |
|AI Copy        |Not recognized |AI Original    |Not recognized |0.01   |-0.02  |0.04    |0.74 |n.s.     |
|None           |Not recognized |AI Original    |Not recognized |0.25   |0.20   |0.30    |1.00 |Positive |
|None           |Not recognized |AI Copy        |Not recognized |0.24   |0.19   |0.29    |1.00 |Positive |

:::
:::
:::



::: {.cell}

```{.r .cell-code}
c <- estimates$MemoryBelief$contrasts
make_contrasts(c, answer="Not recognized",
               title="Memory of Beliefs: forgetting ('Not recognized') by original belief")
```

::: {.cell-output-display}

```{=html}
<div id="hjfdxcedkj" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#hjfdxcedkj table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#hjfdxcedkj thead, #hjfdxcedkj tbody, #hjfdxcedkj tfoot, #hjfdxcedkj tr, #hjfdxcedkj td, #hjfdxcedkj th {
  border-style: none;
}

#hjfdxcedkj p {
  margin: 0;
  padding: 0;
}

#hjfdxcedkj .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 16px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #A8A8A8;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #A8A8A8;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
}

#hjfdxcedkj .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}

#hjfdxcedkj .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#hjfdxcedkj .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#hjfdxcedkj .gt_heading {
  background-color: #FFFFFF;
  text-align: center;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#hjfdxcedkj .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#hjfdxcedkj .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#hjfdxcedkj .gt_col_heading {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#hjfdxcedkj .gt_column_spanner_outer {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#hjfdxcedkj .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#hjfdxcedkj .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#hjfdxcedkj .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#hjfdxcedkj .gt_spanner_row {
  border-bottom-style: hidden;
}

#hjfdxcedkj .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}

#hjfdxcedkj .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: middle;
}

#hjfdxcedkj .gt_from_md > :first-child {
  margin-top: 0;
}

#hjfdxcedkj .gt_from_md > :last-child {
  margin-bottom: 0;
}

#hjfdxcedkj .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  overflow-x: hidden;
}

#hjfdxcedkj .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
}

#hjfdxcedkj .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}

#hjfdxcedkj .gt_row_group_first td {
  border-top-width: 2px;
}

#hjfdxcedkj .gt_row_group_first th {
  border-top-width: 2px;
}

#hjfdxcedkj .gt_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#hjfdxcedkj .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D3D3D3;
}

#hjfdxcedkj .gt_first_summary_row.thick {
  border-top-width: 2px;
}

#hjfdxcedkj .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#hjfdxcedkj .gt_grand_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#hjfdxcedkj .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D3D3D3;
}

#hjfdxcedkj .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D3D3D3;
}

#hjfdxcedkj .gt_striped {
  background-color: rgba(128, 128, 128, 0.05);
}

#hjfdxcedkj .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#hjfdxcedkj .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#hjfdxcedkj .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#hjfdxcedkj .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#hjfdxcedkj .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#hjfdxcedkj .gt_left {
  text-align: left;
}

#hjfdxcedkj .gt_center {
  text-align: center;
}

#hjfdxcedkj .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#hjfdxcedkj .gt_font_normal {
  font-weight: normal;
}

#hjfdxcedkj .gt_font_bold {
  font-weight: bold;
}

#hjfdxcedkj .gt_font_italic {
  font-style: italic;
}

#hjfdxcedkj .gt_super {
  font-size: 65%;
}

#hjfdxcedkj .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}

#hjfdxcedkj .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}

#hjfdxcedkj .gt_indent_1 {
  text-indent: 5px;
}

#hjfdxcedkj .gt_indent_2 {
  text-indent: 10px;
}

#hjfdxcedkj .gt_indent_3 {
  text-indent: 15px;
}

#hjfdxcedkj .gt_indent_4 {
  text-indent: 20px;
}

#hjfdxcedkj .gt_indent_5 {
  text-indent: 25px;
}

#hjfdxcedkj .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}

#hjfdxcedkj div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>
<table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false">
  <thead>
    <tr class="gt_heading">
      <td colspan="6" class="gt_heading gt_title gt_font_normal gt_bottom_border" style>Memory of Beliefs: forgetting ('Not recognized') by original belief</td>
    </tr>
    
    <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Category">Category</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Level1">Level1</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Level2">Level2</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Median">Median</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="CI">CI</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="pd">pd</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr><td headers="Category" class="gt_row gt_left">Not recognized</td>
<td headers="Level1" class="gt_row gt_left">None</td>
<td headers="Level2" class="gt_row gt_left">Human Forgery</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #7EFF65; color: #000000;">0.26</td>
<td headers="CI" class="gt_row gt_left">[ 0.21, 0.31]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Not recognized</td>
<td headers="Level1" class="gt_row gt_left">None</td>
<td headers="Level2" class="gt_row gt_left">Human Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #7FFF66; color: #000000;">0.26</td>
<td headers="CI" class="gt_row gt_left">[ 0.21, 0.31]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Not recognized</td>
<td headers="Level1" class="gt_row gt_left">None</td>
<td headers="Level2" class="gt_row gt_left">AI Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #85FF6B; color: #000000;">0.25</td>
<td headers="CI" class="gt_row gt_left">[ 0.20, 0.30]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Not recognized</td>
<td headers="Level1" class="gt_row gt_left">None</td>
<td headers="Level2" class="gt_row gt_left">AI Copy</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #8BFF71; color: #000000;">0.24</td>
<td headers="CI" class="gt_row gt_left">[ 0.19, 0.29]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Not recognized</td>
<td headers="Level1" class="gt_row gt_left">AI Copy</td>
<td headers="Level2" class="gt_row gt_left">Human Forgery</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #F8FFF4; color: #000000;">0.02</td>
<td headers="CI" class="gt_row gt_left">[-0.01, 0.05]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFFFFF; color: #000000;">87.60%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Not recognized</td>
<td headers="Level1" class="gt_row gt_left">AI Copy</td>
<td headers="Level2" class="gt_row gt_left">Human Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #F8FFF5; color: #000000;">0.02</td>
<td headers="CI" class="gt_row gt_left">[-0.01, 0.04]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFFFFF; color: #000000;">92.58%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Not recognized</td>
<td headers="Level1" class="gt_row gt_left">AI Original</td>
<td headers="Level2" class="gt_row gt_left">Human Forgery</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FBFFF9; color: #000000;">0.01</td>
<td headers="CI" class="gt_row gt_left">[-0.02, 0.04]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFFFFF; color: #000000;">72.00%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Not recognized</td>
<td headers="Level1" class="gt_row gt_left">AI Copy</td>
<td headers="Level2" class="gt_row gt_left">AI Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FBFFFA; color: #000000;">0.01</td>
<td headers="CI" class="gt_row gt_left">[-0.02, 0.04]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFFFFF; color: #000000;">73.90%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Not recognized</td>
<td headers="Level1" class="gt_row gt_left">AI Original</td>
<td headers="Level2" class="gt_row gt_left">Human Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FCFFFA; color: #000000;">0.01</td>
<td headers="CI" class="gt_row gt_left">[-0.02, 0.03]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFFFFF; color: #000000;">74.52%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Not recognized</td>
<td headers="Level1" class="gt_row gt_left">Human Forgery</td>
<td headers="Level2" class="gt_row gt_left">Human Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FFFEFE; color: #000000;">0.00</td>
<td headers="CI" class="gt_row gt_left">[-0.03, 0.03]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFFFFF; color: #000000;">53.55%</td></tr>
  </tbody>
  
</table>
</div>
```


::: {.callout-note collapse="true" title="Memory of Beliefs: forgetting ('Not recognized') by original belief (Markdown table, for text readers)"}

|Category       |Level1        |Level2         |Median |CI            |pd     |Effect   |
|:--------------|:-------------|:--------------|:------|:-------------|:------|:--------|
|Not recognized |None          |Human Forgery  |0.26   |[ 0.21, 0.31] |100%   |Positive |
|Not recognized |None          |Human Original |0.26   |[ 0.21, 0.31] |100%   |Positive |
|Not recognized |None          |AI Original    |0.25   |[ 0.20, 0.30] |100%   |Positive |
|Not recognized |None          |AI Copy        |0.24   |[ 0.19, 0.29] |100%   |Positive |
|Not recognized |AI Copy       |Human Forgery  |0.02   |[-0.01, 0.05] |87.60% |n.s.     |
|Not recognized |AI Copy       |Human Original |0.02   |[-0.01, 0.04] |92.58% |n.s.     |
|Not recognized |AI Original   |Human Forgery  |0.01   |[-0.02, 0.04] |72.00% |n.s.     |
|Not recognized |AI Copy       |AI Original    |0.01   |[-0.02, 0.04] |73.90% |n.s.     |
|Not recognized |AI Original   |Human Original |0.01   |[-0.02, 0.03] |74.52% |n.s.     |
|Not recognized |Human Forgery |Human Original |0.00   |[-0.03, 0.03] |53.55% |n.s.     |

:::

:::

```{.r .cell-code}
make_contrasts(c, condition="Human Original",
               title="Memory of Beliefs: which answer, within the Human Original belief")
```

::: {.cell-output-display}

```{=html}
<div id="lleauuoiby" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#lleauuoiby table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#lleauuoiby thead, #lleauuoiby tbody, #lleauuoiby tfoot, #lleauuoiby tr, #lleauuoiby td, #lleauuoiby th {
  border-style: none;
}

#lleauuoiby p {
  margin: 0;
  padding: 0;
}

#lleauuoiby .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 16px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #A8A8A8;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #A8A8A8;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
}

#lleauuoiby .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}

#lleauuoiby .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#lleauuoiby .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#lleauuoiby .gt_heading {
  background-color: #FFFFFF;
  text-align: center;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#lleauuoiby .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#lleauuoiby .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#lleauuoiby .gt_col_heading {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#lleauuoiby .gt_column_spanner_outer {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#lleauuoiby .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#lleauuoiby .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#lleauuoiby .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#lleauuoiby .gt_spanner_row {
  border-bottom-style: hidden;
}

#lleauuoiby .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}

#lleauuoiby .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: middle;
}

#lleauuoiby .gt_from_md > :first-child {
  margin-top: 0;
}

#lleauuoiby .gt_from_md > :last-child {
  margin-bottom: 0;
}

#lleauuoiby .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  overflow-x: hidden;
}

#lleauuoiby .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
}

#lleauuoiby .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}

#lleauuoiby .gt_row_group_first td {
  border-top-width: 2px;
}

#lleauuoiby .gt_row_group_first th {
  border-top-width: 2px;
}

#lleauuoiby .gt_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#lleauuoiby .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D3D3D3;
}

#lleauuoiby .gt_first_summary_row.thick {
  border-top-width: 2px;
}

#lleauuoiby .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#lleauuoiby .gt_grand_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#lleauuoiby .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D3D3D3;
}

#lleauuoiby .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D3D3D3;
}

#lleauuoiby .gt_striped {
  background-color: rgba(128, 128, 128, 0.05);
}

#lleauuoiby .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#lleauuoiby .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#lleauuoiby .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#lleauuoiby .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#lleauuoiby .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#lleauuoiby .gt_left {
  text-align: left;
}

#lleauuoiby .gt_center {
  text-align: center;
}

#lleauuoiby .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#lleauuoiby .gt_font_normal {
  font-weight: normal;
}

#lleauuoiby .gt_font_bold {
  font-weight: bold;
}

#lleauuoiby .gt_font_italic {
  font-style: italic;
}

#lleauuoiby .gt_super {
  font-size: 65%;
}

#lleauuoiby .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}

#lleauuoiby .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}

#lleauuoiby .gt_indent_1 {
  text-indent: 5px;
}

#lleauuoiby .gt_indent_2 {
  text-indent: 10px;
}

#lleauuoiby .gt_indent_3 {
  text-indent: 15px;
}

#lleauuoiby .gt_indent_4 {
  text-indent: 20px;
}

#lleauuoiby .gt_indent_5 {
  text-indent: 25px;
}

#lleauuoiby .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}

#lleauuoiby div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>
<table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false">
  <thead>
    <tr class="gt_heading">
      <td colspan="6" class="gt_heading gt_title gt_font_normal gt_bottom_border" style>Memory of Beliefs: which answer, within the Human Original belief</td>
    </tr>
    
    <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Category">Category</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Response1">Response1</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Response2">Response2</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Median">Median</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="CI">CI</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="pd">pd</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Response1" class="gt_row gt_left">Not recognized</td>
<td headers="Response2" class="gt_row gt_left">AI Copy</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #00FF00; color: #000000;">0.57</td>
<td headers="CI" class="gt_row gt_left">[ 0.53,  0.61]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Response1" class="gt_row gt_left">Not recognized</td>
<td headers="Response2" class="gt_row gt_left">Human Forgery</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #00FF00; color: #000000;">0.53</td>
<td headers="CI" class="gt_row gt_left">[ 0.48,  0.57]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Response1" class="gt_row gt_left">Not recognized</td>
<td headers="Response2" class="gt_row gt_left">AI Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #00FF00; color: #000000;">0.51</td>
<td headers="CI" class="gt_row gt_left">[ 0.46,  0.55]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Response1" class="gt_row gt_left">Not recognized</td>
<td headers="Response2" class="gt_row gt_left">Human Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #00FF00; color: #000000;">0.40</td>
<td headers="CI" class="gt_row gt_left">[ 0.34,  0.45]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Response1" class="gt_row gt_left">AI Copy</td>
<td headers="Response2" class="gt_row gt_left">Human Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FF9D81; color: #000000;">-0.18</td>
<td headers="CI" class="gt_row gt_left">[-0.20, -0.16]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Response1" class="gt_row gt_left">Human Forgery</td>
<td headers="Response2" class="gt_row gt_left">Human Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FFB69F; color: #000000;">-0.13</td>
<td headers="CI" class="gt_row gt_left">[-0.15, -0.11]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Response1" class="gt_row gt_left">AI Original</td>
<td headers="Response2" class="gt_row gt_left">Human Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FFC0AC; color: #000000;">-0.11</td>
<td headers="CI" class="gt_row gt_left">[-0.14, -0.09]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Response1" class="gt_row gt_left">AI Copy</td>
<td headers="Response2" class="gt_row gt_left">AI Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FFDED2; color: #000000;">-0.06</td>
<td headers="CI" class="gt_row gt_left">[-0.08, -0.05]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Response1" class="gt_row gt_left">AI Copy</td>
<td headers="Response2" class="gt_row gt_left">Human Forgery</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FFE7DF; color: #000000;">-0.04</td>
<td headers="CI" class="gt_row gt_left">[-0.05, -0.03]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Response1" class="gt_row gt_left">AI Original</td>
<td headers="Response2" class="gt_row gt_left">Human Forgery</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #F8FFF5; color: #000000;">0.02</td>
<td headers="CI" class="gt_row gt_left">[ 0.00,  0.04]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">99.22%</td></tr>
  </tbody>
  
</table>
</div>
```


::: {.callout-note collapse="true" title="Memory of Beliefs: which answer, within the Human Original belief (Markdown table, for text readers)"}

|Category       |Response1      |Response2      |Median |CI             |pd     |Effect   |
|:--------------|:--------------|:--------------|:------|:--------------|:------|:--------|
|Human Original |Not recognized |AI Copy        |0.57   |[ 0.53,  0.61] |100%   |Positive |
|Human Original |Not recognized |Human Forgery  |0.53   |[ 0.48,  0.57] |100%   |Positive |
|Human Original |Not recognized |AI Original    |0.51   |[ 0.46,  0.55] |100%   |Positive |
|Human Original |Not recognized |Human Original |0.40   |[ 0.34,  0.45] |100%   |Positive |
|Human Original |AI Copy        |Human Original |-0.18  |[-0.20, -0.16] |100%   |Negative |
|Human Original |Human Forgery  |Human Original |-0.13  |[-0.15, -0.11] |100%   |Negative |
|Human Original |AI Original    |Human Original |-0.11  |[-0.14, -0.09] |100%   |Negative |
|Human Original |AI Copy        |AI Original    |-0.06  |[-0.08, -0.05] |100%   |Negative |
|Human Original |AI Copy        |Human Forgery  |-0.04  |[-0.05, -0.03] |100%   |Negative |
|Human Original |AI Original    |Human Forgery  |0.02   |[ 0.00,  0.04] |99.22% |Positive |

:::

:::
:::



::: {.cell}

```{.r .cell-code}
make_memory_summary(estimates$MemoryBelief)
```

::: {.cell-output-display}

::: {.callout-tip title="Summary of credible effects (generated from the tables above)"}

**Memory of Beliefs.** Each row of the model is the probability of one answer. The differences below are between Belief levels *within* the same answer, in percentage points, as posterior medians with 95% CI; `pd` is the probability of direction. An effect is called credible when the CI excludes 0. Contrasts *across* answers are in the full table above.

- **Human Original**: None - Human Original -14.08 pp [-16.68, -11.39]; None - Human Forgery -10.94 pp [-13.75, -8.15]; AI Original - Human Original -8.02 pp [-9.95, -6.15]; None - AI Copy -7.12 pp [-9.51, -4.80]; AI Copy - Human Original -6.90 pp [-8.79, -5.09]; None - AI Original -6.01 pp [-8.33, -3.77]; AI Original - Human Forgery -4.89 pp [-7.27, -2.61]; AI Copy - Human Forgery -3.77 pp [-6.17, -1.46]; Human Forgery - Human Original -3.16 pp [-5.27, -0.98]. The other 1 pair(s) are not credible.
- **Human Forgery**: None - Human Forgery -5.78 pp [-7.60, -4.08]; None - AI Copy -4.60 pp [-6.14, -3.14]; None - Human Original -4.55 pp [-5.78, -3.34]; None - AI Original -3.19 pp [-4.70, -1.85]; AI Original - Human Forgery -2.56 pp [-4.32, -0.89]; AI Original - Human Original -1.37 pp [-2.58, -0.05]. The other 4 pair(s) are not credible.
- **AI Original**: None - AI Original -11.99 pp [-15.04, -9.22]; None - AI Copy -8.99 pp [-11.64, -6.56]; AI Original - Human Original 6.47 pp [4.65, 8.52]; None - Human Forgery -6.44 pp [-9.10, -4.07]; AI Original - Human Forgery 5.54 pp [3.27, 7.87]; None - Human Original -5.52 pp [-7.56, -3.57]; AI Copy - Human Original 3.49 pp [1.87, 5.19]; AI Copy - AI Original -2.97 pp [-5.19, -0.88]; AI Copy - Human Forgery 2.54 pp [0.41, 4.63]. The other 1 pair(s) are not credible.
- **AI Copy**: None - AI Original -3.84 pp [-5.06, -2.75]; None - AI Copy -3.40 pp [-4.55, -2.41]; None - Human Forgery -2.80 pp [-4.21, -1.70]; AI Original - Human Original 2.05 pp [1.03, 3.16]; None - Human Original -1.79 pp [-2.51, -1.12]; AI Copy - Human Original 1.60 pp [0.68, 2.66]. The other 4 pair(s) are not credible.
- **Not recognized**: None - Human Forgery 26.05 pp [20.71, 31.17]; None - Human Original 25.98 pp [20.93, 30.73]; None - AI Original 25.14 pp [19.75, 30.08]; None - AI Copy 24.20 pp [19.18, 29.17]. The other 6 pair(s) are not credible.

:::

:::
:::


## Memory of the Condition by Belief

Does the recalled label follow what the participant came to believe about the
artwork (Phase 2), once the label actually shown is controlled for?


::: {.cell}

```{.r .cell-code}
dat_cb <- estimates$MemoryConditionBelief$means |>
  mutate(group = make_group(Response))

dat_cb |>
  ggplot(aes(x = Belief, y = Median, color = Response)) +
  geom_line(aes(group = group), position = position_dodge(width = 0.1), linewidth = 1,
            show.legend = FALSE) +
  geom_pointrange(aes(group = group, ymin = CI_low, ymax = CI_high), position = position_dodge(width = 0.1),
                  key_glyph = "point") +
  scale_y_continuous(label = scales::percent, limits = c(0, 1), expand = c(0, 0)) +
  scale_color_manual(values = cols) +
  guides(color = guide_legend(override.aes = list(size = 3))) +
  labs(y = "Proportion of answers (averaged over the label shown)", color = "Recalled label",
       x = "Own belief in Phase 2", title = "Memory of the Condition by Belief") +
  theme_minimal()
```

::: {.cell-output-display}
![](4_memory_files/figure-html/unnamed-chunk-12-1.png){width=672}
:::
:::



::: {.cell}

```{.r .cell-code}
make_memory_tables(estimates$MemoryConditionBelief)
```

::: {.cell-output-display}

```{=html}
<div id="zikubaddrh" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#zikubaddrh table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#zikubaddrh thead, #zikubaddrh tbody, #zikubaddrh tfoot, #zikubaddrh tr, #zikubaddrh td, #zikubaddrh th {
  border-style: none;
}

#zikubaddrh p {
  margin: 0;
  padding: 0;
}

#zikubaddrh .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 13px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 3px;
  border-top-color: #D5D5D5;
  border-right-style: solid;
  border-right-width: 3px;
  border-right-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 3px;
  border-bottom-color: #D5D5D5;
  border-left-style: solid;
  border-left-width: 3px;
  border-left-color: #D5D5D5;
}

#zikubaddrh .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}

#zikubaddrh .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#zikubaddrh .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#zikubaddrh .gt_heading {
  background-color: #FFFFFF;
  text-align: left;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#zikubaddrh .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#zikubaddrh .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#zikubaddrh .gt_col_heading {
  color: #FFFFFF;
  background-color: #000000;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#zikubaddrh .gt_column_spanner_outer {
  color: #FFFFFF;
  background-color: #000000;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#zikubaddrh .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#zikubaddrh .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#zikubaddrh .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#zikubaddrh .gt_spanner_row {
  border-bottom-style: hidden;
}

#zikubaddrh .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}

#zikubaddrh .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  vertical-align: middle;
}

#zikubaddrh .gt_from_md > :first-child {
  margin-top: 0;
}

#zikubaddrh .gt_from_md > :last-child {
  margin-bottom: 0;
}

#zikubaddrh .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D5D5D5;
  border-left-style: solid;
  border-left-width: 1px;
  border-left-color: #D5D5D5;
  border-right-style: solid;
  border-right-width: 1px;
  border-right-color: #D5D5D5;
  vertical-align: middle;
  overflow-x: hidden;
}

#zikubaddrh .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #5F5F5F;
  padding-left: 5px;
  padding-right: 5px;
}

#zikubaddrh .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}

#zikubaddrh .gt_row_group_first td {
  border-top-width: 2px;
}

#zikubaddrh .gt_row_group_first th {
  border-top-width: 2px;
}

#zikubaddrh .gt_summary_row {
  color: #333333;
  background-color: #D5D5D5;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#zikubaddrh .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D5D5D5;
}

#zikubaddrh .gt_first_summary_row.thick {
  border-top-width: 2px;
}

#zikubaddrh .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#zikubaddrh .gt_grand_summary_row {
  color: #FFFFFF;
  background-color: #929292;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#zikubaddrh .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D5D5D5;
}

#zikubaddrh .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D5D5D5;
}

#zikubaddrh .gt_striped {
  background-color: #F4F4F4;
}

#zikubaddrh .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#zikubaddrh .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#zikubaddrh .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#zikubaddrh .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#zikubaddrh .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#zikubaddrh .gt_left {
  text-align: left;
}

#zikubaddrh .gt_center {
  text-align: center;
}

#zikubaddrh .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#zikubaddrh .gt_font_normal {
  font-weight: normal;
}

#zikubaddrh .gt_font_bold {
  font-weight: bold;
}

#zikubaddrh .gt_font_italic {
  font-style: italic;
}

#zikubaddrh .gt_super {
  font-size: 65%;
}

#zikubaddrh .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}

#zikubaddrh .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}

#zikubaddrh .gt_indent_1 {
  text-indent: 5px;
}

#zikubaddrh .gt_indent_2 {
  text-indent: 10px;
}

#zikubaddrh .gt_indent_3 {
  text-indent: 15px;
}

#zikubaddrh .gt_indent_4 {
  text-indent: 20px;
}

#zikubaddrh .gt_indent_5 {
  text-indent: 25px;
}

#zikubaddrh .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}

#zikubaddrh div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>
<table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false">
  <thead>
    <tr class="gt_heading">
      <td colspan="10" class="gt_heading gt_title gt_font_normal gt_bottom_border" style>Memory of the Condition by Belief: convergence</td>
    </tr>
    
    <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Model">Model</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Family">Family</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="N_obs">N_obs</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="N_participants">N_participants</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Chains">Chains</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Draws">Draws</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Max_Rhat">Max_Rhat</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Min_ESS_ratio">Min_ESS_ratio</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Divergent_pct">Divergent_pct</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Criterion">Criterion</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr><td headers="Model" class="gt_row gt_left">MemoryConditionBelief</td>
<td headers="Family" class="gt_row gt_left">Categorical</td>
<td headers="N_obs" class="gt_row gt_right">10416</td>
<td headers="N_participants" class="gt_row gt_right">217</td>
<td headers="Chains" class="gt_row gt_right">8</td>
<td headers="Draws" class="gt_row gt_right">4000</td>
<td headers="Max_Rhat" class="gt_row gt_right">1.031</td>
<td headers="Min_ESS_ratio" class="gt_row gt_right">0.078</td>
<td headers="Divergent_pct" class="gt_row gt_right">0</td>
<td headers="Criterion" class="gt_row gt_left">loo</td></tr>
  </tbody>
  
</table>
</div>
```


::: {.callout-note collapse="true" title="Memory of the Condition by Belief: convergence (Markdown table, for text readers)"}

|Model                 |Family      | N_obs| N_participants| Chains| Draws| Max_Rhat| Min_ESS_ratio| Divergent_pct|Criterion |
|:---------------------|:-----------|-----:|--------------:|------:|-----:|--------:|-------------:|-------------:|:---------|
|MemoryConditionBelief |Categorical | 10416|            217|      8|  4000|    1.031|         0.078|             0|loo       |

:::

```{=html}
<div id="anurzbccuf" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#anurzbccuf table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#anurzbccuf thead, #anurzbccuf tbody, #anurzbccuf tfoot, #anurzbccuf tr, #anurzbccuf td, #anurzbccuf th {
  border-style: none;
}

#anurzbccuf p {
  margin: 0;
  padding: 0;
}

#anurzbccuf .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 13px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 3px;
  border-top-color: #D5D5D5;
  border-right-style: solid;
  border-right-width: 3px;
  border-right-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 3px;
  border-bottom-color: #D5D5D5;
  border-left-style: solid;
  border-left-width: 3px;
  border-left-color: #D5D5D5;
}

#anurzbccuf .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}

#anurzbccuf .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#anurzbccuf .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#anurzbccuf .gt_heading {
  background-color: #FFFFFF;
  text-align: left;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#anurzbccuf .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#anurzbccuf .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#anurzbccuf .gt_col_heading {
  color: #FFFFFF;
  background-color: #000000;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#anurzbccuf .gt_column_spanner_outer {
  color: #FFFFFF;
  background-color: #000000;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#anurzbccuf .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#anurzbccuf .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#anurzbccuf .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#anurzbccuf .gt_spanner_row {
  border-bottom-style: hidden;
}

#anurzbccuf .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}

#anurzbccuf .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  vertical-align: middle;
}

#anurzbccuf .gt_from_md > :first-child {
  margin-top: 0;
}

#anurzbccuf .gt_from_md > :last-child {
  margin-bottom: 0;
}

#anurzbccuf .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D5D5D5;
  border-left-style: solid;
  border-left-width: 1px;
  border-left-color: #D5D5D5;
  border-right-style: solid;
  border-right-width: 1px;
  border-right-color: #D5D5D5;
  vertical-align: middle;
  overflow-x: hidden;
}

#anurzbccuf .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #5F5F5F;
  padding-left: 5px;
  padding-right: 5px;
}

#anurzbccuf .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}

#anurzbccuf .gt_row_group_first td {
  border-top-width: 2px;
}

#anurzbccuf .gt_row_group_first th {
  border-top-width: 2px;
}

#anurzbccuf .gt_summary_row {
  color: #333333;
  background-color: #D5D5D5;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#anurzbccuf .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D5D5D5;
}

#anurzbccuf .gt_first_summary_row.thick {
  border-top-width: 2px;
}

#anurzbccuf .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#anurzbccuf .gt_grand_summary_row {
  color: #FFFFFF;
  background-color: #929292;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#anurzbccuf .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D5D5D5;
}

#anurzbccuf .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D5D5D5;
}

#anurzbccuf .gt_striped {
  background-color: #F4F4F4;
}

#anurzbccuf .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#anurzbccuf .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#anurzbccuf .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#anurzbccuf .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#anurzbccuf .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#anurzbccuf .gt_left {
  text-align: left;
}

#anurzbccuf .gt_center {
  text-align: center;
}

#anurzbccuf .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#anurzbccuf .gt_font_normal {
  font-weight: normal;
}

#anurzbccuf .gt_font_bold {
  font-weight: bold;
}

#anurzbccuf .gt_font_italic {
  font-style: italic;
}

#anurzbccuf .gt_super {
  font-size: 65%;
}

#anurzbccuf .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}

#anurzbccuf .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}

#anurzbccuf .gt_indent_1 {
  text-indent: 5px;
}

#anurzbccuf .gt_indent_2 {
  text-indent: 10px;
}

#anurzbccuf .gt_indent_3 {
  text-indent: 15px;
}

#anurzbccuf .gt_indent_4 {
  text-indent: 20px;
}

#anurzbccuf .gt_indent_5 {
  text-indent: 25px;
}

#anurzbccuf .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}

#anurzbccuf div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>
<table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false">
  <thead>
    <tr class="gt_heading">
      <td colspan="5" class="gt_heading gt_title gt_font_normal gt_bottom_border" style>Memory of the Condition by Belief: probability of each answer per Belief (marginal means)</td>
    </tr>
    
    <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="1" colspan="1" scope="col" id="Belief">Belief</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="1" colspan="1" scope="col" id="Response">Response</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Median">Median</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="CI_low">CI_low</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="CI_high">CI_high</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr><td headers="Belief" class="gt_row gt_center">Human Original</td>
<td headers="Response" class="gt_row gt_center">Human Original</td>
<td headers="Median" class="gt_row gt_right">0.25</td>
<td headers="CI_low" class="gt_row gt_right">0.23</td>
<td headers="CI_high" class="gt_row gt_right">0.26</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">Human Forgery</td>
<td headers="Response" class="gt_row gt_center gt_striped">Human Original</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.22</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.20</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.25</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">AI Original</td>
<td headers="Response" class="gt_row gt_center">Human Original</td>
<td headers="Median" class="gt_row gt_right">0.19</td>
<td headers="CI_low" class="gt_row gt_right">0.17</td>
<td headers="CI_high" class="gt_row gt_right">0.21</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">AI Copy</td>
<td headers="Response" class="gt_row gt_center gt_striped">Human Original</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.20</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.18</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.21</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">Human Original</td>
<td headers="Response" class="gt_row gt_center">Human Forgery</td>
<td headers="Median" class="gt_row gt_right">0.07</td>
<td headers="CI_low" class="gt_row gt_right">0.06</td>
<td headers="CI_high" class="gt_row gt_right">0.08</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">Human Forgery</td>
<td headers="Response" class="gt_row gt_center gt_striped">Human Forgery</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.07</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.06</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.09</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">AI Original</td>
<td headers="Response" class="gt_row gt_center">Human Forgery</td>
<td headers="Median" class="gt_row gt_right">0.05</td>
<td headers="CI_low" class="gt_row gt_right">0.04</td>
<td headers="CI_high" class="gt_row gt_right">0.06</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">AI Copy</td>
<td headers="Response" class="gt_row gt_center gt_striped">Human Forgery</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.06</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.05</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.07</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">Human Original</td>
<td headers="Response" class="gt_row gt_center">AI-Generated</td>
<td headers="Median" class="gt_row gt_right">0.12</td>
<td headers="CI_low" class="gt_row gt_right">0.11</td>
<td headers="CI_high" class="gt_row gt_right">0.13</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">Human Forgery</td>
<td headers="Response" class="gt_row gt_center gt_striped">AI-Generated</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.14</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.12</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.16</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">AI Original</td>
<td headers="Response" class="gt_row gt_center">AI-Generated</td>
<td headers="Median" class="gt_row gt_right">0.19</td>
<td headers="CI_low" class="gt_row gt_right">0.17</td>
<td headers="CI_high" class="gt_row gt_right">0.21</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">AI Copy</td>
<td headers="Response" class="gt_row gt_center gt_striped">AI-Generated</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.16</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.14</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.17</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">Human Original</td>
<td headers="Response" class="gt_row gt_center">Not recognized</td>
<td headers="Median" class="gt_row gt_right">0.56</td>
<td headers="CI_low" class="gt_row gt_right">0.55</td>
<td headers="CI_high" class="gt_row gt_right">0.58</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">Human Forgery</td>
<td headers="Response" class="gt_row gt_center gt_striped">Not recognized</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.56</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.54</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.59</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center">AI Original</td>
<td headers="Response" class="gt_row gt_center">Not recognized</td>
<td headers="Median" class="gt_row gt_right">0.57</td>
<td headers="CI_low" class="gt_row gt_right">0.55</td>
<td headers="CI_high" class="gt_row gt_right">0.59</td></tr>
    <tr><td headers="Belief" class="gt_row gt_center gt_striped">AI Copy</td>
<td headers="Response" class="gt_row gt_center gt_striped">Not recognized</td>
<td headers="Median" class="gt_row gt_right gt_striped">0.58</td>
<td headers="CI_low" class="gt_row gt_right gt_striped">0.56</td>
<td headers="CI_high" class="gt_row gt_right gt_striped">0.60</td></tr>
  </tbody>
  
</table>
</div>
```


::: {.callout-note collapse="true" title="Memory of the Condition by Belief: probability of each answer per Belief (marginal means) (Markdown table, for text readers)"}

|Belief         |Response       |Median |CI_low |CI_high |
|:--------------|:--------------|:------|:------|:-------|
|Human Original |Human Original |0.25   |0.23   |0.26    |
|Human Forgery  |Human Original |0.22   |0.20   |0.25    |
|AI Original    |Human Original |0.19   |0.17   |0.21    |
|AI Copy        |Human Original |0.20   |0.18   |0.21    |
|Human Original |Human Forgery  |0.07   |0.06   |0.08    |
|Human Forgery  |Human Forgery  |0.07   |0.06   |0.09    |
|AI Original    |Human Forgery  |0.05   |0.04   |0.06    |
|AI Copy        |Human Forgery  |0.06   |0.05   |0.07    |
|Human Original |AI-Generated   |0.12   |0.11   |0.13    |
|Human Forgery  |AI-Generated   |0.14   |0.12   |0.16    |
|AI Original    |AI-Generated   |0.19   |0.17   |0.21    |
|AI Copy        |AI-Generated   |0.16   |0.14   |0.17    |
|Human Original |Not recognized |0.56   |0.55   |0.58    |
|Human Forgery  |Not recognized |0.56   |0.54   |0.59    |
|AI Original    |Not recognized |0.57   |0.55   |0.59    |
|AI Copy        |Not recognized |0.58   |0.56   |0.60    |

:::

::: {.callout-note collapse="true" title="Memory of the Condition by Belief: all 120 contrasts (Markdown table, for text readers)"}

|Level1         |Response1      |Level2         |Response2      |Median |CI_low |CI_high |pd   |Effect   |
|:--------------|:--------------|:--------------|:--------------|:------|:------|:-------|:----|:--------|
|Human Original |Human Original |Human Forgery  |Human Original |0.02   |0.00   |0.05    |0.95 |n.s.     |
|Human Original |Human Original |AI Original    |Human Original |0.05   |0.03   |0.08    |1.00 |Positive |
|Human Original |Human Original |AI Copy        |Human Original |0.05   |0.03   |0.07    |1.00 |Positive |
|Human Original |Human Original |Human Original |Human Forgery  |0.18   |0.16   |0.19    |1.00 |Positive |
|Human Original |Human Original |Human Forgery  |Human Forgery  |0.17   |0.16   |0.19    |1.00 |Positive |
|Human Original |Human Original |AI Original    |Human Forgery  |0.19   |0.18   |0.21    |1.00 |Positive |
|Human Original |Human Original |AI Copy        |Human Forgery  |0.18   |0.17   |0.20    |1.00 |Positive |
|Human Original |Human Original |Human Original |AI-Generated   |0.13   |0.11   |0.14    |1.00 |Positive |
|Human Original |Human Original |Human Forgery  |AI-Generated   |0.11   |0.08   |0.13    |1.00 |Positive |
|Human Original |Human Original |AI Original    |AI-Generated   |0.06   |0.04   |0.08    |1.00 |Positive |
|Human Original |Human Original |AI Copy        |AI-Generated   |0.09   |0.07   |0.11    |1.00 |Positive |
|Human Original |Human Original |Human Original |Not recognized |-0.32  |-0.34  |-0.30   |1.00 |Negative |
|Human Original |Human Original |Human Forgery  |Not recognized |-0.32  |-0.34  |-0.29   |1.00 |Negative |
|Human Original |Human Original |AI Original    |Not recognized |-0.32  |-0.34  |-0.30   |1.00 |Negative |
|Human Original |Human Original |AI Copy        |Not recognized |-0.34  |-0.36  |-0.31   |1.00 |Negative |
|Human Forgery  |Human Original |AI Original    |Human Original |0.03   |0.01   |0.06    |0.99 |Positive |
|Human Forgery  |Human Original |AI Copy        |Human Original |0.03   |0.00   |0.06    |0.99 |Positive |
|Human Forgery  |Human Original |Human Original |Human Forgery  |0.15   |0.13   |0.18    |1.00 |Positive |
|Human Forgery  |Human Original |Human Forgery  |Human Forgery  |0.15   |0.13   |0.18    |1.00 |Positive |
|Human Forgery  |Human Original |AI Original    |Human Forgery  |0.17   |0.15   |0.20    |1.00 |Positive |
|Human Forgery  |Human Original |AI Copy        |Human Forgery  |0.16   |0.14   |0.19    |1.00 |Positive |
|Human Forgery  |Human Original |Human Original |AI-Generated   |0.11   |0.08   |0.13    |1.00 |Positive |
|Human Forgery  |Human Original |Human Forgery  |AI-Generated   |0.09   |0.05   |0.12    |1.00 |Positive |
|Human Forgery  |Human Original |AI Original    |AI-Generated   |0.04   |0.01   |0.06    |1.00 |Positive |
|Human Forgery  |Human Original |AI Copy        |AI-Generated   |0.07   |0.04   |0.09    |1.00 |Positive |
|Human Forgery  |Human Original |Human Original |Not recognized |-0.34  |-0.36  |-0.31   |1.00 |Negative |
|Human Forgery  |Human Original |Human Forgery  |Not recognized |-0.34  |-0.38  |-0.30   |1.00 |Negative |
|Human Forgery  |Human Original |AI Original    |Not recognized |-0.34  |-0.37  |-0.31   |1.00 |Negative |
|Human Forgery  |Human Original |AI Copy        |Not recognized |-0.36  |-0.39  |-0.33   |1.00 |Negative |
|AI Original    |Human Original |AI Copy        |Human Original |0.00   |-0.03  |0.02    |0.66 |n.s.     |
|AI Original    |Human Original |Human Original |Human Forgery  |0.12   |0.10   |0.14    |1.00 |Positive |
|AI Original    |Human Original |Human Forgery  |Human Forgery  |0.12   |0.10   |0.14    |1.00 |Positive |
|AI Original    |Human Original |AI Original    |Human Forgery  |0.14   |0.12   |0.16    |1.00 |Positive |
|AI Original    |Human Original |AI Copy        |Human Forgery  |0.13   |0.11   |0.15    |1.00 |Positive |
|AI Original    |Human Original |Human Original |AI-Generated   |0.07   |0.05   |0.09    |1.00 |Positive |
|AI Original    |Human Original |Human Forgery  |AI-Generated   |0.05   |0.03   |0.08    |1.00 |Positive |
|AI Original    |Human Original |AI Original    |AI-Generated   |0.00   |-0.02  |0.03    |0.59 |n.s.     |
|AI Original    |Human Original |AI Copy        |AI-Generated   |0.03   |0.01   |0.05    |1.00 |Positive |
|AI Original    |Human Original |Human Original |Not recognized |-0.37  |-0.39  |-0.35   |1.00 |Negative |
|AI Original    |Human Original |Human Forgery  |Not recognized |-0.37  |-0.40  |-0.34   |1.00 |Negative |
|AI Original    |Human Original |AI Original    |Not recognized |-0.38  |-0.41  |-0.34   |1.00 |Negative |
|AI Original    |Human Original |AI Copy        |Not recognized |-0.39  |-0.42  |-0.37   |1.00 |Negative |
|AI Copy        |Human Original |Human Original |Human Forgery  |0.13   |0.11   |0.14    |1.00 |Positive |
|AI Copy        |Human Original |Human Forgery  |Human Forgery  |0.12   |0.10   |0.14    |1.00 |Positive |
|AI Copy        |Human Original |AI Original    |Human Forgery  |0.14   |0.12   |0.16    |1.00 |Positive |
|AI Copy        |Human Original |AI Copy        |Human Forgery  |0.13   |0.11   |0.15    |1.00 |Positive |
|AI Copy        |Human Original |Human Original |AI-Generated   |0.08   |0.06   |0.10    |1.00 |Positive |
|AI Copy        |Human Original |Human Forgery  |AI-Generated   |0.06   |0.03   |0.08    |1.00 |Positive |
|AI Copy        |Human Original |AI Original    |AI-Generated   |0.01   |-0.02  |0.03    |0.75 |n.s.     |
|AI Copy        |Human Original |AI Copy        |AI-Generated   |0.04   |0.01   |0.06    |1.00 |Positive |
|AI Copy        |Human Original |Human Original |Not recognized |-0.37  |-0.39  |-0.35   |1.00 |Negative |
|AI Copy        |Human Original |Human Forgery  |Not recognized |-0.37  |-0.40  |-0.34   |1.00 |Negative |
|AI Copy        |Human Original |AI Original    |Not recognized |-0.37  |-0.40  |-0.35   |1.00 |Negative |
|AI Copy        |Human Original |AI Copy        |Not recognized |-0.39  |-0.42  |-0.36   |1.00 |Negative |
|Human Original |Human Forgery  |Human Forgery  |Human Forgery  |0.00   |-0.02  |0.01    |0.60 |n.s.     |
|Human Original |Human Forgery  |AI Original    |Human Forgery  |0.02   |0.01   |0.03    |1.00 |Positive |
|Human Original |Human Forgery  |AI Copy        |Human Forgery  |0.01   |0.00   |0.02    |0.90 |n.s.     |
|Human Original |Human Forgery  |Human Original |AI-Generated   |-0.05  |-0.06  |-0.04   |1.00 |Negative |
|Human Original |Human Forgery  |Human Forgery  |AI-Generated   |-0.07  |-0.09  |-0.05   |1.00 |Negative |
|Human Original |Human Forgery  |AI Original    |AI-Generated   |-0.12  |-0.14  |-0.10   |1.00 |Negative |
|Human Original |Human Forgery  |AI Copy        |AI-Generated   |-0.09  |-0.10  |-0.07   |1.00 |Negative |
|Human Original |Human Forgery  |Human Original |Not recognized |-0.49  |-0.51  |-0.48   |1.00 |Negative |
|Human Original |Human Forgery  |Human Forgery  |Not recognized |-0.49  |-0.52  |-0.47   |1.00 |Negative |
|Human Original |Human Forgery  |AI Original    |Not recognized |-0.50  |-0.52  |-0.48   |1.00 |Negative |
|Human Original |Human Forgery  |AI Copy        |Not recognized |-0.51  |-0.53  |-0.49   |1.00 |Negative |
|Human Forgery  |Human Forgery  |AI Original    |Human Forgery  |0.02   |0.00   |0.04    |0.99 |Positive |
|Human Forgery  |Human Forgery  |AI Copy        |Human Forgery  |0.01   |-0.01  |0.03    |0.88 |n.s.     |
|Human Forgery  |Human Forgery  |Human Original |AI-Generated   |-0.05  |-0.06  |-0.03   |1.00 |Negative |
|Human Forgery  |Human Forgery  |Human Forgery  |AI-Generated   |-0.07  |-0.09  |-0.04   |1.00 |Negative |
|Human Forgery  |Human Forgery  |AI Original    |AI-Generated   |-0.12  |-0.14  |-0.09   |1.00 |Negative |
|Human Forgery  |Human Forgery  |AI Copy        |AI-Generated   |-0.09  |-0.11  |-0.07   |1.00 |Negative |
|Human Forgery  |Human Forgery  |Human Original |Not recognized |-0.49  |-0.51  |-0.47   |1.00 |Negative |
|Human Forgery  |Human Forgery  |Human Forgery  |Not recognized |-0.49  |-0.52  |-0.46   |1.00 |Negative |
|Human Forgery  |Human Forgery  |AI Original    |Not recognized |-0.50  |-0.52  |-0.47   |1.00 |Negative |
|Human Forgery  |Human Forgery  |AI Copy        |Not recognized |-0.51  |-0.53  |-0.49   |1.00 |Negative |
|AI Original    |Human Forgery  |AI Copy        |Human Forgery  |-0.01  |-0.03  |0.00    |0.94 |n.s.     |
|AI Original    |Human Forgery  |Human Original |AI-Generated   |-0.07  |-0.08  |-0.05   |1.00 |Negative |
|AI Original    |Human Forgery  |Human Forgery  |AI-Generated   |-0.09  |-0.11  |-0.07   |1.00 |Negative |
|AI Original    |Human Forgery  |AI Original    |AI-Generated   |-0.14  |-0.16  |-0.12   |1.00 |Negative |
|AI Original    |Human Forgery  |AI Copy        |AI-Generated   |-0.11  |-0.12  |-0.09   |1.00 |Negative |
|AI Original    |Human Forgery  |Human Original |Not recognized |-0.51  |-0.53  |-0.50   |1.00 |Negative |
|AI Original    |Human Forgery  |Human Forgery  |Not recognized |-0.51  |-0.54  |-0.48   |1.00 |Negative |
|AI Original    |Human Forgery  |AI Original    |Not recognized |-0.52  |-0.54  |-0.49   |1.00 |Negative |
|AI Original    |Human Forgery  |AI Copy        |Not recognized |-0.53  |-0.55  |-0.51   |1.00 |Negative |
|AI Copy        |Human Forgery  |Human Original |AI-Generated   |-0.06  |-0.07  |-0.04   |1.00 |Negative |
|AI Copy        |Human Forgery  |Human Forgery  |AI-Generated   |-0.08  |-0.10  |-0.06   |1.00 |Negative |
|AI Copy        |Human Forgery  |AI Original    |AI-Generated   |-0.13  |-0.14  |-0.11   |1.00 |Negative |
|AI Copy        |Human Forgery  |AI Copy        |AI-Generated   |-0.10  |-0.11  |-0.08   |1.00 |Negative |
|AI Copy        |Human Forgery  |Human Original |Not recognized |-0.50  |-0.52  |-0.49   |1.00 |Negative |
|AI Copy        |Human Forgery  |Human Forgery  |Not recognized |-0.50  |-0.53  |-0.47   |1.00 |Negative |
|AI Copy        |Human Forgery  |AI Original    |Not recognized |-0.51  |-0.53  |-0.48   |1.00 |Negative |
|AI Copy        |Human Forgery  |AI Copy        |Not recognized |-0.52  |-0.54  |-0.50   |1.00 |Negative |
|Human Original |AI-Generated   |Human Forgery  |AI-Generated   |-0.02  |-0.04  |0.00    |0.98 |Negative |
|Human Original |AI-Generated   |AI Original    |AI-Generated   |-0.07  |-0.09  |-0.05   |1.00 |Negative |
|Human Original |AI-Generated   |AI Copy        |AI-Generated   |-0.04  |-0.06  |-0.02   |1.00 |Negative |
|Human Original |AI-Generated   |Human Original |Not recognized |-0.45  |-0.46  |-0.43   |1.00 |Negative |
|Human Original |AI-Generated   |Human Forgery  |Not recognized |-0.44  |-0.47  |-0.42   |1.00 |Negative |
|Human Original |AI-Generated   |AI Original    |Not recognized |-0.45  |-0.47  |-0.43   |1.00 |Negative |
|Human Original |AI-Generated   |AI Copy        |Not recognized |-0.46  |-0.48  |-0.44   |1.00 |Negative |
|Human Forgery  |AI-Generated   |AI Original    |AI-Generated   |-0.05  |-0.07  |-0.02   |1.00 |Negative |
|Human Forgery  |AI-Generated   |AI Copy        |AI-Generated   |-0.02  |-0.04  |0.01    |0.94 |n.s.     |
|Human Forgery  |AI-Generated   |Human Original |Not recognized |-0.42  |-0.45  |-0.40   |1.00 |Negative |
|Human Forgery  |AI-Generated   |Human Forgery  |Not recognized |-0.42  |-0.46  |-0.39   |1.00 |Negative |
|Human Forgery  |AI-Generated   |AI Original    |Not recognized |-0.43  |-0.45  |-0.40   |1.00 |Negative |
|Human Forgery  |AI-Generated   |AI Copy        |Not recognized |-0.44  |-0.47  |-0.42   |1.00 |Negative |
|AI Original    |AI-Generated   |AI Copy        |AI-Generated   |0.03   |0.01   |0.05    |1.00 |Positive |
|AI Original    |AI-Generated   |Human Original |Not recognized |-0.38  |-0.40  |-0.36   |1.00 |Negative |
|AI Original    |AI-Generated   |Human Forgery  |Not recognized |-0.37  |-0.40  |-0.35   |1.00 |Negative |
|AI Original    |AI-Generated   |AI Original    |Not recognized |-0.38  |-0.41  |-0.35   |1.00 |Negative |
|AI Original    |AI-Generated   |AI Copy        |Not recognized |-0.39  |-0.42  |-0.37   |1.00 |Negative |
|AI Copy        |AI-Generated   |Human Original |Not recognized |-0.41  |-0.43  |-0.39   |1.00 |Negative |
|AI Copy        |AI-Generated   |Human Forgery  |Not recognized |-0.40  |-0.43  |-0.38   |1.00 |Negative |
|AI Copy        |AI-Generated   |AI Original    |Not recognized |-0.41  |-0.43  |-0.39   |1.00 |Negative |
|AI Copy        |AI-Generated   |AI Copy        |Not recognized |-0.42  |-0.45  |-0.40   |1.00 |Negative |
|Human Original |Not recognized |Human Forgery  |Not recognized |0.00   |-0.03  |0.03    |0.55 |n.s.     |
|Human Original |Not recognized |AI Original    |Not recognized |0.00   |-0.03  |0.02    |0.64 |n.s.     |
|Human Original |Not recognized |AI Copy        |Not recognized |-0.02  |-0.04  |0.00    |0.94 |n.s.     |
|Human Forgery  |Not recognized |AI Original    |Not recognized |-0.01  |-0.04  |0.03    |0.65 |n.s.     |
|Human Forgery  |Not recognized |AI Copy        |Not recognized |-0.02  |-0.05  |0.01    |0.90 |n.s.     |
|AI Original    |Not recognized |AI Copy        |Not recognized |-0.01  |-0.04  |0.01    |0.85 |n.s.     |

:::
:::
:::



::: {.cell}

```{.r .cell-code}
c <- estimates$MemoryConditionBelief$contrasts
make_contrasts(c, answer = "AI-Generated",
               title = "Memory of the Condition by Belief: recalling 'AI-Generated', by own belief")
```

::: {.cell-output-display}

```{=html}
<div id="utbfqwtari" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#utbfqwtari table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#utbfqwtari thead, #utbfqwtari tbody, #utbfqwtari tfoot, #utbfqwtari tr, #utbfqwtari td, #utbfqwtari th {
  border-style: none;
}

#utbfqwtari p {
  margin: 0;
  padding: 0;
}

#utbfqwtari .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 16px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #A8A8A8;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #A8A8A8;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
}

#utbfqwtari .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}

#utbfqwtari .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#utbfqwtari .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#utbfqwtari .gt_heading {
  background-color: #FFFFFF;
  text-align: center;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#utbfqwtari .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#utbfqwtari .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#utbfqwtari .gt_col_heading {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#utbfqwtari .gt_column_spanner_outer {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#utbfqwtari .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#utbfqwtari .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#utbfqwtari .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#utbfqwtari .gt_spanner_row {
  border-bottom-style: hidden;
}

#utbfqwtari .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}

#utbfqwtari .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: middle;
}

#utbfqwtari .gt_from_md > :first-child {
  margin-top: 0;
}

#utbfqwtari .gt_from_md > :last-child {
  margin-bottom: 0;
}

#utbfqwtari .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  overflow-x: hidden;
}

#utbfqwtari .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
}

#utbfqwtari .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}

#utbfqwtari .gt_row_group_first td {
  border-top-width: 2px;
}

#utbfqwtari .gt_row_group_first th {
  border-top-width: 2px;
}

#utbfqwtari .gt_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#utbfqwtari .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D3D3D3;
}

#utbfqwtari .gt_first_summary_row.thick {
  border-top-width: 2px;
}

#utbfqwtari .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#utbfqwtari .gt_grand_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#utbfqwtari .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D3D3D3;
}

#utbfqwtari .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D3D3D3;
}

#utbfqwtari .gt_striped {
  background-color: rgba(128, 128, 128, 0.05);
}

#utbfqwtari .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#utbfqwtari .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#utbfqwtari .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#utbfqwtari .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#utbfqwtari .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#utbfqwtari .gt_left {
  text-align: left;
}

#utbfqwtari .gt_center {
  text-align: center;
}

#utbfqwtari .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#utbfqwtari .gt_font_normal {
  font-weight: normal;
}

#utbfqwtari .gt_font_bold {
  font-weight: bold;
}

#utbfqwtari .gt_font_italic {
  font-style: italic;
}

#utbfqwtari .gt_super {
  font-size: 65%;
}

#utbfqwtari .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}

#utbfqwtari .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}

#utbfqwtari .gt_indent_1 {
  text-indent: 5px;
}

#utbfqwtari .gt_indent_2 {
  text-indent: 10px;
}

#utbfqwtari .gt_indent_3 {
  text-indent: 15px;
}

#utbfqwtari .gt_indent_4 {
  text-indent: 20px;
}

#utbfqwtari .gt_indent_5 {
  text-indent: 25px;
}

#utbfqwtari .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}

#utbfqwtari div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>
<table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false">
  <thead>
    <tr class="gt_heading">
      <td colspan="6" class="gt_heading gt_title gt_font_normal gt_bottom_border" style>Memory of the Condition by Belief: recalling 'AI-Generated', by own belief</td>
    </tr>
    
    <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Category">Category</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Level1">Level1</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Level2">Level2</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Median">Median</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="CI">CI</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="pd">pd</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr><td headers="Category" class="gt_row gt_left">AI-Generated</td>
<td headers="Level1" class="gt_row gt_left">Human Original</td>
<td headers="Level2" class="gt_row gt_left">AI Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FFD9CC; color: #000000;">-0.07</td>
<td headers="CI" class="gt_row gt_left">[-0.09, -0.05]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">AI-Generated</td>
<td headers="Level1" class="gt_row gt_left">Human Forgery</td>
<td headers="Level2" class="gt_row gt_left">AI Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FFE4DB; color: #000000;">-0.05</td>
<td headers="CI" class="gt_row gt_left">[-0.07, -0.02]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">AI-Generated</td>
<td headers="Level1" class="gt_row gt_left">Human Original</td>
<td headers="Level2" class="gt_row gt_left">AI Copy</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FFE9E2; color: #000000;">-0.04</td>
<td headers="CI" class="gt_row gt_left">[-0.06, -0.02]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">AI-Generated</td>
<td headers="Level1" class="gt_row gt_left">AI Original</td>
<td headers="Level2" class="gt_row gt_left">AI Copy</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #F3FFEE; color: #000000;">0.03</td>
<td headers="CI" class="gt_row gt_left">[ 0.01,  0.05]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">99.62%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">AI-Generated</td>
<td headers="Level1" class="gt_row gt_left">Human Original</td>
<td headers="Level2" class="gt_row gt_left">Human Forgery</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FFF4EF; color: #000000;">-0.02</td>
<td headers="CI" class="gt_row gt_left">[-0.04,  0.00]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFEB3B; color: #000000;">97.78%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">AI-Generated</td>
<td headers="Level1" class="gt_row gt_left">Human Forgery</td>
<td headers="Level2" class="gt_row gt_left">AI Copy</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FFF5F1; color: #000000;">-0.02</td>
<td headers="CI" class="gt_row gt_left">[-0.04,  0.01]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFFFFF; color: #000000;">94.30%</td></tr>
  </tbody>
  
</table>
</div>
```


::: {.callout-note collapse="true" title="Memory of the Condition by Belief: recalling 'AI-Generated', by own belief (Markdown table, for text readers)"}

|Category     |Level1         |Level2        |Median |CI             |pd     |Effect   |
|:------------|:--------------|:-------------|:------|:--------------|:------|:--------|
|AI-Generated |Human Original |AI Original   |-0.07  |[-0.09, -0.05] |100%   |Negative |
|AI-Generated |Human Forgery  |AI Original   |-0.05  |[-0.07, -0.02] |100%   |Negative |
|AI-Generated |Human Original |AI Copy       |-0.04  |[-0.06, -0.02] |100%   |Negative |
|AI-Generated |AI Original    |AI Copy       |0.03   |[ 0.01,  0.05] |99.62% |Positive |
|AI-Generated |Human Original |Human Forgery |-0.02  |[-0.04,  0.00] |97.78% |Negative |
|AI-Generated |Human Forgery  |AI Copy       |-0.02  |[-0.04,  0.01] |94.30% |n.s.     |

:::

:::

```{.r .cell-code}
make_contrasts(c, answer = "Human Original",
               title = "Memory of the Condition by Belief: recalling 'Human Original', by own belief")
```

::: {.cell-output-display}

```{=html}
<div id="cugqhtxptt" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#cugqhtxptt table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#cugqhtxptt thead, #cugqhtxptt tbody, #cugqhtxptt tfoot, #cugqhtxptt tr, #cugqhtxptt td, #cugqhtxptt th {
  border-style: none;
}

#cugqhtxptt p {
  margin: 0;
  padding: 0;
}

#cugqhtxptt .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 16px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #A8A8A8;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #A8A8A8;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
}

#cugqhtxptt .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}

#cugqhtxptt .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#cugqhtxptt .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#cugqhtxptt .gt_heading {
  background-color: #FFFFFF;
  text-align: center;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#cugqhtxptt .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#cugqhtxptt .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#cugqhtxptt .gt_col_heading {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#cugqhtxptt .gt_column_spanner_outer {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#cugqhtxptt .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#cugqhtxptt .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#cugqhtxptt .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#cugqhtxptt .gt_spanner_row {
  border-bottom-style: hidden;
}

#cugqhtxptt .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}

#cugqhtxptt .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: middle;
}

#cugqhtxptt .gt_from_md > :first-child {
  margin-top: 0;
}

#cugqhtxptt .gt_from_md > :last-child {
  margin-bottom: 0;
}

#cugqhtxptt .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  overflow-x: hidden;
}

#cugqhtxptt .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
}

#cugqhtxptt .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}

#cugqhtxptt .gt_row_group_first td {
  border-top-width: 2px;
}

#cugqhtxptt .gt_row_group_first th {
  border-top-width: 2px;
}

#cugqhtxptt .gt_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#cugqhtxptt .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D3D3D3;
}

#cugqhtxptt .gt_first_summary_row.thick {
  border-top-width: 2px;
}

#cugqhtxptt .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#cugqhtxptt .gt_grand_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#cugqhtxptt .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D3D3D3;
}

#cugqhtxptt .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D3D3D3;
}

#cugqhtxptt .gt_striped {
  background-color: rgba(128, 128, 128, 0.05);
}

#cugqhtxptt .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#cugqhtxptt .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#cugqhtxptt .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#cugqhtxptt .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#cugqhtxptt .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#cugqhtxptt .gt_left {
  text-align: left;
}

#cugqhtxptt .gt_center {
  text-align: center;
}

#cugqhtxptt .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#cugqhtxptt .gt_font_normal {
  font-weight: normal;
}

#cugqhtxptt .gt_font_bold {
  font-weight: bold;
}

#cugqhtxptt .gt_font_italic {
  font-style: italic;
}

#cugqhtxptt .gt_super {
  font-size: 65%;
}

#cugqhtxptt .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}

#cugqhtxptt .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}

#cugqhtxptt .gt_indent_1 {
  text-indent: 5px;
}

#cugqhtxptt .gt_indent_2 {
  text-indent: 10px;
}

#cugqhtxptt .gt_indent_3 {
  text-indent: 15px;
}

#cugqhtxptt .gt_indent_4 {
  text-indent: 20px;
}

#cugqhtxptt .gt_indent_5 {
  text-indent: 25px;
}

#cugqhtxptt .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}

#cugqhtxptt div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>
<table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false">
  <thead>
    <tr class="gt_heading">
      <td colspan="6" class="gt_heading gt_title gt_font_normal gt_bottom_border" style>Memory of the Condition by Belief: recalling 'Human Original', by own belief</td>
    </tr>
    
    <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Category">Category</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Level1">Level1</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Level2">Level2</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Median">Median</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="CI">CI</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="pd">pd</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Level1" class="gt_row gt_left">Human Original</td>
<td headers="Level2" class="gt_row gt_left">AI Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #E9FFE0; color: #000000;">0.05</td>
<td headers="CI" class="gt_row gt_left">[ 0.03, 0.08]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Level1" class="gt_row gt_left">Human Original</td>
<td headers="Level2" class="gt_row gt_left">AI Copy</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #EBFFE3; color: #000000;">0.05</td>
<td headers="CI" class="gt_row gt_left">[ 0.03, 0.07]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">100%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Level1" class="gt_row gt_left">Human Forgery</td>
<td headers="Level2" class="gt_row gt_left">AI Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #F1FFEC; color: #000000;">0.03</td>
<td headers="CI" class="gt_row gt_left">[ 0.01, 0.06]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">99.40%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Level1" class="gt_row gt_left">Human Forgery</td>
<td headers="Level2" class="gt_row gt_left">AI Copy</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #F3FFEF; color: #000000;">0.03</td>
<td headers="CI" class="gt_row gt_left">[ 0.00, 0.06]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFEB3B; color: #000000;">98.52%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Level1" class="gt_row gt_left">Human Original</td>
<td headers="Level2" class="gt_row gt_left">Human Forgery</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #F6FFF3; color: #000000;">0.02</td>
<td headers="CI" class="gt_row gt_left">[ 0.00, 0.05]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFF59D; color: #000000;">95.23%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Original</td>
<td headers="Level1" class="gt_row gt_left">AI Original</td>
<td headers="Level2" class="gt_row gt_left">AI Copy</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FFFCFB; color: #000000;">0.00</td>
<td headers="CI" class="gt_row gt_left">[-0.03, 0.02]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFFFFF; color: #000000;">66.12%</td></tr>
  </tbody>
  
</table>
</div>
```


::: {.callout-note collapse="true" title="Memory of the Condition by Belief: recalling 'Human Original', by own belief (Markdown table, for text readers)"}

|Category       |Level1         |Level2        |Median |CI            |pd     |Effect   |
|:--------------|:--------------|:-------------|:------|:-------------|:------|:--------|
|Human Original |Human Original |AI Original   |0.05   |[ 0.03, 0.08] |100%   |Positive |
|Human Original |Human Original |AI Copy       |0.05   |[ 0.03, 0.07] |100%   |Positive |
|Human Original |Human Forgery  |AI Original   |0.03   |[ 0.01, 0.06] |99.40% |Positive |
|Human Original |Human Forgery  |AI Copy       |0.03   |[ 0.00, 0.06] |98.52% |Positive |
|Human Original |Human Original |Human Forgery |0.02   |[ 0.00, 0.05] |95.23% |n.s.     |
|Human Original |AI Original    |AI Copy       |0.00   |[-0.03, 0.02] |66.12% |n.s.     |

:::

:::

```{.r .cell-code}
make_contrasts(c, answer = "Human Forgery",
               title = "Memory of the Condition by Belief: recalling 'Human Forgery', by own belief")
```

::: {.cell-output-display}

```{=html}
<div id="eacbvubhwo" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#eacbvubhwo table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#eacbvubhwo thead, #eacbvubhwo tbody, #eacbvubhwo tfoot, #eacbvubhwo tr, #eacbvubhwo td, #eacbvubhwo th {
  border-style: none;
}

#eacbvubhwo p {
  margin: 0;
  padding: 0;
}

#eacbvubhwo .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 16px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #A8A8A8;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #A8A8A8;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
}

#eacbvubhwo .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}

#eacbvubhwo .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#eacbvubhwo .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#eacbvubhwo .gt_heading {
  background-color: #FFFFFF;
  text-align: center;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#eacbvubhwo .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#eacbvubhwo .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#eacbvubhwo .gt_col_heading {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#eacbvubhwo .gt_column_spanner_outer {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#eacbvubhwo .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#eacbvubhwo .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#eacbvubhwo .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#eacbvubhwo .gt_spanner_row {
  border-bottom-style: hidden;
}

#eacbvubhwo .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}

#eacbvubhwo .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: middle;
}

#eacbvubhwo .gt_from_md > :first-child {
  margin-top: 0;
}

#eacbvubhwo .gt_from_md > :last-child {
  margin-bottom: 0;
}

#eacbvubhwo .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  overflow-x: hidden;
}

#eacbvubhwo .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
}

#eacbvubhwo .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}

#eacbvubhwo .gt_row_group_first td {
  border-top-width: 2px;
}

#eacbvubhwo .gt_row_group_first th {
  border-top-width: 2px;
}

#eacbvubhwo .gt_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#eacbvubhwo .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D3D3D3;
}

#eacbvubhwo .gt_first_summary_row.thick {
  border-top-width: 2px;
}

#eacbvubhwo .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#eacbvubhwo .gt_grand_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#eacbvubhwo .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D3D3D3;
}

#eacbvubhwo .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D3D3D3;
}

#eacbvubhwo .gt_striped {
  background-color: rgba(128, 128, 128, 0.05);
}

#eacbvubhwo .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#eacbvubhwo .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#eacbvubhwo .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#eacbvubhwo .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#eacbvubhwo .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#eacbvubhwo .gt_left {
  text-align: left;
}

#eacbvubhwo .gt_center {
  text-align: center;
}

#eacbvubhwo .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#eacbvubhwo .gt_font_normal {
  font-weight: normal;
}

#eacbvubhwo .gt_font_bold {
  font-weight: bold;
}

#eacbvubhwo .gt_font_italic {
  font-style: italic;
}

#eacbvubhwo .gt_super {
  font-size: 65%;
}

#eacbvubhwo .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}

#eacbvubhwo .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}

#eacbvubhwo .gt_indent_1 {
  text-indent: 5px;
}

#eacbvubhwo .gt_indent_2 {
  text-indent: 10px;
}

#eacbvubhwo .gt_indent_3 {
  text-indent: 15px;
}

#eacbvubhwo .gt_indent_4 {
  text-indent: 20px;
}

#eacbvubhwo .gt_indent_5 {
  text-indent: 25px;
}

#eacbvubhwo .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}

#eacbvubhwo div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>
<table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false">
  <thead>
    <tr class="gt_heading">
      <td colspan="6" class="gt_heading gt_title gt_font_normal gt_bottom_border" style>Memory of the Condition by Belief: recalling 'Human Forgery', by own belief</td>
    </tr>
    
    <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Category">Category</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Level1">Level1</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Level2">Level2</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Median">Median</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="CI">CI</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="pd">pd</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr><td headers="Category" class="gt_row gt_left">Human Forgery</td>
<td headers="Level1" class="gt_row gt_left">Human Forgery</td>
<td headers="Level2" class="gt_row gt_left">AI Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #F7FFF3; color: #000000;">0.02</td>
<td headers="CI" class="gt_row gt_left">[ 0.00, 0.04]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">99.38%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Forgery</td>
<td headers="Level1" class="gt_row gt_left">Human Original</td>
<td headers="Level2" class="gt_row gt_left">AI Original</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #F8FFF4; color: #000000;">0.02</td>
<td headers="CI" class="gt_row gt_left">[ 0.01, 0.03]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFC107; color: #000000;">99.88%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Forgery</td>
<td headers="Level1" class="gt_row gt_left">AI Original</td>
<td headers="Level2" class="gt_row gt_left">AI Copy</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FFF9F7; color: #000000;">-0.01</td>
<td headers="CI" class="gt_row gt_left">[-0.03, 0.00]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFFFFF; color: #000000;">93.53%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Forgery</td>
<td headers="Level1" class="gt_row gt_left">Human Forgery</td>
<td headers="Level2" class="gt_row gt_left">AI Copy</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FBFFF9; color: #000000;">0.01</td>
<td headers="CI" class="gt_row gt_left">[-0.01, 0.03]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFFFFF; color: #000000;">87.58%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Forgery</td>
<td headers="Level1" class="gt_row gt_left">Human Original</td>
<td headers="Level2" class="gt_row gt_left">AI Copy</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FCFFFA; color: #000000;">0.01</td>
<td headers="CI" class="gt_row gt_left">[ 0.00, 0.02]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFFFFF; color: #000000;">89.95%</td></tr>
    <tr><td headers="Category" class="gt_row gt_left">Human Forgery</td>
<td headers="Level1" class="gt_row gt_left">Human Original</td>
<td headers="Level2" class="gt_row gt_left">Human Forgery</td>
<td headers="Median" class="gt_row gt_right" style="background-color: #FFFEFD; color: #000000;">0.00</td>
<td headers="CI" class="gt_row gt_left">[-0.02, 0.01]</td>
<td headers="pd" class="gt_row gt_right" style="background-color: #FFFFFF; color: #000000;">59.88%</td></tr>
  </tbody>
  
</table>
</div>
```


::: {.callout-note collapse="true" title="Memory of the Condition by Belief: recalling 'Human Forgery', by own belief (Markdown table, for text readers)"}

|Category      |Level1         |Level2        |Median |CI            |pd     |Effect   |
|:-------------|:--------------|:-------------|:------|:-------------|:------|:--------|
|Human Forgery |Human Forgery  |AI Original   |0.02   |[ 0.00, 0.04] |99.38% |Positive |
|Human Forgery |Human Original |AI Original   |0.02   |[ 0.01, 0.03] |99.88% |Positive |
|Human Forgery |AI Original    |AI Copy       |-0.01  |[-0.03, 0.00] |93.53% |n.s.     |
|Human Forgery |Human Forgery  |AI Copy       |0.01   |[-0.01, 0.03] |87.58% |n.s.     |
|Human Forgery |Human Original |AI Copy       |0.01   |[ 0.00, 0.02] |89.95% |n.s.     |
|Human Forgery |Human Original |Human Forgery |0.00   |[-0.02, 0.01] |59.88% |n.s.     |

:::

:::
:::


Among **recognised** items only (each answer probability divided by the
probability of recognising the item, per draw), and the difference from the
Human Original belief:


```{.r .cell-code}
D <- estimates$MemoryConditionBelief$draws # draws x Belief x answer
rec <- 1 - D[, , "Not recognized"]
describe_pp <- function(x) {
  ci <- bayestestR::eti(x)
  data.frame(Median = 100 * median(x), CI_low = 100 * ci$CI_low, CI_high = 100 * ci$CI_high,
             pd = as.numeric(bayestestR::p_direction(x)))
}
dat_rec <- bind_rows(lapply(setdiff(dimnames(D)[[3]], "Not recognized"), function(a) {
  bind_rows(lapply(dimnames(D)[[2]], function(b) {
    p <- D[, b, a] / rec[, b]
    p0 <- D[, "Human Original", a] / rec[, "Human Original"]
    cbind(data.frame(Answer = a, Belief = b),
          setNames(describe_pp(p)[1:3], c("P", "P_low", "P_high")),
          describe_pp(p - p0))
  }))
})) |>
  mutate(P = sprintf("%s [%s, %s]", insight::format_value(P), insight::format_value(P_low), insight::format_value(P_high)),
         Diff = ifelse(Belief == "Human Original", "", insight::format_value(Median)),
         CI = ifelse(Belief == "Human Original", "", sprintf("[%s, %s]", insight::format_value(CI_low), insight::format_value(CI_high))),
         pd_fmt = ifelse(Belief == "Human Original", "", insight::format_pd(pd, name = NULL)),
         Effect = ifelse(Belief == "Human Original", "",
                         ifelse(sign(CI_low) != sign(CI_high), "n.s.", ifelse(Median < 0, "Negative", "Positive")))) |>
  rename(Contrast = Answer)
make_tables(dat_rec, c("Contrast", "Belief", "P", "Diff", "CI", "pd_fmt", "Effect"),
            "Memory of the Condition by Belief: P(recalled label | recognised), in %, and difference from the Human Original belief (percentage points)")
```

```{=html}
<div id="cdenphvosn" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#cdenphvosn table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#cdenphvosn thead, #cdenphvosn tbody, #cdenphvosn tfoot, #cdenphvosn tr, #cdenphvosn td, #cdenphvosn th {
  border-style: none;
}

#cdenphvosn p {
  margin: 0;
  padding: 0;
}

#cdenphvosn .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 13px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 3px;
  border-top-color: #D5D5D5;
  border-right-style: solid;
  border-right-width: 3px;
  border-right-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 3px;
  border-bottom-color: #D5D5D5;
  border-left-style: solid;
  border-left-width: 3px;
  border-left-color: #D5D5D5;
}

#cdenphvosn .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}

#cdenphvosn .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#cdenphvosn .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#cdenphvosn .gt_heading {
  background-color: #FFFFFF;
  text-align: left;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#cdenphvosn .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#cdenphvosn .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#cdenphvosn .gt_col_heading {
  color: #FFFFFF;
  background-color: #000000;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#cdenphvosn .gt_column_spanner_outer {
  color: #FFFFFF;
  background-color: #000000;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#cdenphvosn .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#cdenphvosn .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#cdenphvosn .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#cdenphvosn .gt_spanner_row {
  border-bottom-style: hidden;
}

#cdenphvosn .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}

#cdenphvosn .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  vertical-align: middle;
}

#cdenphvosn .gt_from_md > :first-child {
  margin-top: 0;
}

#cdenphvosn .gt_from_md > :last-child {
  margin-bottom: 0;
}

#cdenphvosn .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D5D5D5;
  border-left-style: solid;
  border-left-width: 1px;
  border-left-color: #D5D5D5;
  border-right-style: solid;
  border-right-width: 1px;
  border-right-color: #D5D5D5;
  vertical-align: middle;
  overflow-x: hidden;
}

#cdenphvosn .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #5F5F5F;
  padding-left: 5px;
  padding-right: 5px;
}

#cdenphvosn .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}

#cdenphvosn .gt_row_group_first td {
  border-top-width: 2px;
}

#cdenphvosn .gt_row_group_first th {
  border-top-width: 2px;
}

#cdenphvosn .gt_summary_row {
  color: #333333;
  background-color: #D5D5D5;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#cdenphvosn .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D5D5D5;
}

#cdenphvosn .gt_first_summary_row.thick {
  border-top-width: 2px;
}

#cdenphvosn .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#cdenphvosn .gt_grand_summary_row {
  color: #FFFFFF;
  background-color: #929292;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#cdenphvosn .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D5D5D5;
}

#cdenphvosn .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D5D5D5;
}

#cdenphvosn .gt_striped {
  background-color: #F4F4F4;
}

#cdenphvosn .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#cdenphvosn .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#cdenphvosn .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#cdenphvosn .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#cdenphvosn .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#cdenphvosn .gt_left {
  text-align: left;
}

#cdenphvosn .gt_center {
  text-align: center;
}

#cdenphvosn .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#cdenphvosn .gt_font_normal {
  font-weight: normal;
}

#cdenphvosn .gt_font_bold {
  font-weight: bold;
}

#cdenphvosn .gt_font_italic {
  font-style: italic;
}

#cdenphvosn .gt_super {
  font-size: 65%;
}

#cdenphvosn .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}

#cdenphvosn .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}

#cdenphvosn .gt_indent_1 {
  text-indent: 5px;
}

#cdenphvosn .gt_indent_2 {
  text-indent: 10px;
}

#cdenphvosn .gt_indent_3 {
  text-indent: 15px;
}

#cdenphvosn .gt_indent_4 {
  text-indent: 20px;
}

#cdenphvosn .gt_indent_5 {
  text-indent: 25px;
}

#cdenphvosn .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}

#cdenphvosn div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>
<table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false">
  <thead>
    <tr class="gt_heading">
      <td colspan="6" class="gt_heading gt_title gt_font_normal gt_bottom_border" style>Memory of the Condition by Belief: P(recalled label | recognised), in %, and difference from the Human Original belief (percentage points)</td>
    </tr>
    
    <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Belief">Belief</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="P">P</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Diff">Diff</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="CI">CI</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="pd_fmt">pd_fmt</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Effect">Effect</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="Human Original">Human Original</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="Human Original  Belief" class="gt_row gt_left">Human Original</td>
<td headers="Human Original  P" class="gt_row gt_left">56.49 [54.33, 58.62]</td>
<td headers="Human Original  Diff" class="gt_row gt_right"></td>
<td headers="Human Original  CI" class="gt_row gt_left"></td>
<td headers="Human Original  pd_fmt" class="gt_row gt_right"></td>
<td headers="Human Original  Effect" class="gt_row gt_left"></td></tr>
    <tr><td headers="Human Original  Belief" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Human Forgery</td>
<td headers="Human Original  P" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">51.40 [47.52, 55.33]</td>
<td headers="Human Original  Diff" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">-5.09</td>
<td headers="Human Original  CI" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">[-9.61, -0.73]</td>
<td headers="Human Original  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">98.90%</td>
<td headers="Human Original  Effect" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="Human Original  Belief" class="gt_row gt_left" style="background-color: #FFEBEE;">AI Original</td>
<td headers="Human Original  P" class="gt_row gt_left" style="background-color: #FFEBEE;">44.25 [40.96, 47.46]</td>
<td headers="Human Original  Diff" class="gt_row gt_right" style="background-color: #FFEBEE;">-12.21</td>
<td headers="Human Original  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-16.17, -8.30]</td>
<td headers="Human Original  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="Human Original  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="Human Original  Belief" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">AI Copy</td>
<td headers="Human Original  P" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">47.02 [43.87, 50.17]</td>
<td headers="Human Original  Diff" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">-9.53</td>
<td headers="Human Original  CI" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">[-13.36, -5.51]</td>
<td headers="Human Original  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">100%</td>
<td headers="Human Original  Effect" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="Human Forgery">Human Forgery</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="Human Forgery  Belief" class="gt_row gt_left">Human Original</td>
<td headers="Human Forgery  P" class="gt_row gt_left">16.23 [14.70, 17.81]</td>
<td headers="Human Forgery  Diff" class="gt_row gt_right"></td>
<td headers="Human Forgery  CI" class="gt_row gt_left"></td>
<td headers="Human Forgery  pd_fmt" class="gt_row gt_right"></td>
<td headers="Human Forgery  Effect" class="gt_row gt_left"></td></tr>
    <tr><td headers="Human Forgery  Belief" class="gt_row gt_left gt_striped" style="color: #9E9E9E;">Human Forgery</td>
<td headers="Human Forgery  P" class="gt_row gt_left gt_striped" style="color: #9E9E9E;">16.60 [13.74, 19.62]</td>
<td headers="Human Forgery  Diff" class="gt_row gt_right gt_striped" style="color: #9E9E9E;">0.36</td>
<td headers="Human Forgery  CI" class="gt_row gt_left gt_striped" style="color: #9E9E9E;">[-2.97, 3.78]</td>
<td headers="Human Forgery  pd_fmt" class="gt_row gt_right gt_striped" style="color: #9E9E9E;">59.30%</td>
<td headers="Human Forgery  Effect" class="gt_row gt_left gt_striped" style="color: #9E9E9E;">n.s.</td></tr>
    <tr><td headers="Human Forgery  Belief" class="gt_row gt_left" style="background-color: #FFEBEE;">AI Original</td>
<td headers="Human Forgery  P" class="gt_row gt_left" style="background-color: #FFEBEE;">12.08 [9.96, 14.39]</td>
<td headers="Human Forgery  Diff" class="gt_row gt_right" style="background-color: #FFEBEE;">-4.18</td>
<td headers="Human Forgery  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-6.83, -1.33]</td>
<td headers="Human Forgery  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">99.80%</td>
<td headers="Human Forgery  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="Human Forgery  Belief" class="gt_row gt_left gt_striped" style="color: #9E9E9E;">AI Copy</td>
<td headers="Human Forgery  P" class="gt_row gt_left gt_striped" style="color: #9E9E9E;">15.03 [12.91, 17.40]</td>
<td headers="Human Forgery  Diff" class="gt_row gt_right gt_striped" style="color: #9E9E9E;">-1.21</td>
<td headers="Human Forgery  CI" class="gt_row gt_left gt_striped" style="color: #9E9E9E;">[-3.82, 1.61]</td>
<td headers="Human Forgery  pd_fmt" class="gt_row gt_right gt_striped" style="color: #9E9E9E;">79.85%</td>
<td headers="Human Forgery  Effect" class="gt_row gt_left gt_striped" style="color: #9E9E9E;">n.s.</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="AI-Generated">AI-Generated</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="AI-Generated  Belief" class="gt_row gt_left">Human Original</td>
<td headers="AI-Generated  P" class="gt_row gt_left">27.28 [25.25, 29.29]</td>
<td headers="AI-Generated  Diff" class="gt_row gt_right"></td>
<td headers="AI-Generated  CI" class="gt_row gt_left"></td>
<td headers="AI-Generated  pd_fmt" class="gt_row gt_right"></td>
<td headers="AI-Generated  Effect" class="gt_row gt_left"></td></tr>
    <tr><td headers="AI-Generated  Belief" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Human Forgery</td>
<td headers="AI-Generated  P" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">31.96 [28.39, 35.83]</td>
<td headers="AI-Generated  Diff" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">4.66</td>
<td headers="AI-Generated  CI" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">[0.48, 9.07]</td>
<td headers="AI-Generated  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">98.52%</td>
<td headers="AI-Generated  Effect" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr><td headers="AI-Generated  Belief" class="gt_row gt_left" style="background-color: #E8F5E9;">AI Original</td>
<td headers="AI-Generated  P" class="gt_row gt_left" style="background-color: #E8F5E9;">43.61 [40.41, 46.86]</td>
<td headers="AI-Generated  Diff" class="gt_row gt_right" style="background-color: #E8F5E9;">16.39</td>
<td headers="AI-Generated  CI" class="gt_row gt_left" style="background-color: #E8F5E9;">[12.42, 20.24]</td>
<td headers="AI-Generated  pd_fmt" class="gt_row gt_right" style="background-color: #E8F5E9;">100%</td>
<td headers="AI-Generated  Effect" class="gt_row gt_left" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr><td headers="AI-Generated  Belief" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">AI Copy</td>
<td headers="AI-Generated  P" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">37.95 [34.77, 41.04]</td>
<td headers="AI-Generated  Diff" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">10.70</td>
<td headers="AI-Generated  CI" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">[6.88, 14.46]</td>
<td headers="AI-Generated  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">100%</td>
<td headers="AI-Generated  Effect" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Positive</td></tr>
  </tbody>
  
</table>
</div>
```


::: {.callout-note collapse="true" title="Memory of the Condition by Belief: P(recalled label | recognised), in %, and difference from the Human Original belief (percentage points) (Markdown table, for text readers)"}

|Contrast       |Belief         |P                    |Diff   |CI              |pd_fmt |Effect   |
|:--------------|:--------------|:--------------------|:------|:---------------|:------|:--------|
|Human Original |Human Original |56.49 [54.33, 58.62] |       |                |       |         |
|Human Original |Human Forgery  |51.40 [47.52, 55.33] |-5.09  |[-9.61, -0.73]  |98.90% |Negative |
|Human Original |AI Original    |44.25 [40.96, 47.46] |-12.21 |[-16.17, -8.30] |100%   |Negative |
|Human Original |AI Copy        |47.02 [43.87, 50.17] |-9.53  |[-13.36, -5.51] |100%   |Negative |
|Human Forgery  |Human Original |16.23 [14.70, 17.81] |       |                |       |         |
|Human Forgery  |Human Forgery  |16.60 [13.74, 19.62] |0.36   |[-2.97, 3.78]   |59.30% |n.s.     |
|Human Forgery  |AI Original    |12.08 [9.96, 14.39]  |-4.18  |[-6.83, -1.33]  |99.80% |Negative |
|Human Forgery  |AI Copy        |15.03 [12.91, 17.40] |-1.21  |[-3.82, 1.61]   |79.85% |n.s.     |
|AI-Generated   |Human Original |27.28 [25.25, 29.29] |       |                |       |         |
|AI-Generated   |Human Forgery  |31.96 [28.39, 35.83] |4.66   |[0.48, 9.07]    |98.52% |Positive |
|AI-Generated   |AI Original    |43.61 [40.41, 46.86] |16.39  |[12.42, 20.24]  |100%   |Positive |
|AI-Generated   |AI Copy        |37.95 [34.77, 41.04] |10.70  |[6.88, 14.46]   |100%   |Positive |

:::


::: {.cell}

```{.r .cell-code}
make_memory_summary(estimates$MemoryConditionBelief)
```

::: {.cell-output-display}

::: {.callout-tip title="Summary of credible effects (generated from the tables above)"}

**Memory of the Condition by Belief.** Each row of the model is the probability of one answer. The differences below are between Belief levels *within* the same answer, in percentage points, as posterior medians with 95% CI; `pd` is the probability of direction. An effect is called credible when the CI excludes 0. Contrasts *across* answers are in the full table above.

- **Human Original**: Human Original - AI Original 5.49 pp [3.41, 7.60]; Human Original - AI Copy 5.00 pp [2.92, 7.07]; Human Forgery - AI Original 3.37 pp [0.73, 6.07]; Human Forgery - AI Copy 2.89 pp [0.27, 5.58]. The other 2 pair(s) are not credible.
- **Human Forgery**: Human Forgery - AI Original 2.03 pp [0.42, 3.75]; Human Original - AI Original 1.86 pp [0.61, 3.05]. The other 4 pair(s) are not credible.
- **AI-Generated**: Human Original - AI Original -6.95 pp [-8.93, -5.01]; Human Forgery - AI Original -4.87 pp [-7.30, -2.32]; Human Original - AI Copy -3.95 pp [-5.75, -2.18]; AI Original - AI Copy 2.97 pp [0.77, 5.29]; Human Original - Human Forgery -2.09 pp [-4.22, -0.05]. The other 1 pair(s) are not credible.
- **Not recognized**: no credible difference between any pair of Belief levels.

:::

:::
:::


## Summary

- `data/results_memory_contrasts.csv`: every contrast (level × answer pair), probability scale, with `pd` and `Credible`.
- `data/results_memory_means.csv`: probability of each answer per level.


::: {.cell}

```{.r .cell-code}
results_memory_contrasts <- bind_rows(lapply(unname(estimates), function(e) {
  d <- as.data.frame(e$contrasts)
  d$Model <- e$outcome
  d$Predictor <- e$by
  d$Credible <- sign(d$CI_low) == sign(d$CI_high)
  d[c("Model", "Predictor", "Level1", "Response1", "Level2", "Response2",
      "Median", "CI_low", "CI_high", "pd", "Credible")]
})) |>
  arrange(Model, Response1, Response2, Level1, Level2)
write.csv(results_memory_contrasts, "../data/results_memory_contrasts.csv", row.names = FALSE)

results_memory_means <- bind_rows(lapply(unname(estimates), function(e) {
  d <- as.data.frame(e$means)
  data.frame(Model = e$outcome, Predictor = e$by, Level = as.character(d[[e$by]]),
             Response = as.character(d$Response), Median = d$Median,
             CI_low = d$CI_low, CI_high = d$CI_high)
})) |>
  arrange(Model, Level, Response)
write.csv(results_memory_means, "../data/results_memory_means.csv", row.names = FALSE)

make_tables(bind_rows(lapply(unname(estimates), `[[`, "diag")),
            c("Model", "Family", "N_obs", "N_participants", "Chains", "Draws",
              "Max_Rhat", "Min_ESS_ratio", "Divergent_pct", "Criterion"),
            "Convergence of the memory models")
```

::: {.cell-output-display}

```{=html}
<div id="jvpppqmcof" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#jvpppqmcof table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#jvpppqmcof thead, #jvpppqmcof tbody, #jvpppqmcof tfoot, #jvpppqmcof tr, #jvpppqmcof td, #jvpppqmcof th {
  border-style: none;
}

#jvpppqmcof p {
  margin: 0;
  padding: 0;
}

#jvpppqmcof .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 13px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 3px;
  border-top-color: #D5D5D5;
  border-right-style: solid;
  border-right-width: 3px;
  border-right-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 3px;
  border-bottom-color: #D5D5D5;
  border-left-style: solid;
  border-left-width: 3px;
  border-left-color: #D5D5D5;
}

#jvpppqmcof .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}

#jvpppqmcof .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#jvpppqmcof .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#jvpppqmcof .gt_heading {
  background-color: #FFFFFF;
  text-align: left;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#jvpppqmcof .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#jvpppqmcof .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#jvpppqmcof .gt_col_heading {
  color: #FFFFFF;
  background-color: #000000;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#jvpppqmcof .gt_column_spanner_outer {
  color: #FFFFFF;
  background-color: #000000;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#jvpppqmcof .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#jvpppqmcof .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#jvpppqmcof .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#jvpppqmcof .gt_spanner_row {
  border-bottom-style: hidden;
}

#jvpppqmcof .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}

#jvpppqmcof .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  vertical-align: middle;
}

#jvpppqmcof .gt_from_md > :first-child {
  margin-top: 0;
}

#jvpppqmcof .gt_from_md > :last-child {
  margin-bottom: 0;
}

#jvpppqmcof .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D5D5D5;
  border-left-style: solid;
  border-left-width: 1px;
  border-left-color: #D5D5D5;
  border-right-style: solid;
  border-right-width: 1px;
  border-right-color: #D5D5D5;
  vertical-align: middle;
  overflow-x: hidden;
}

#jvpppqmcof .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #5F5F5F;
  padding-left: 5px;
  padding-right: 5px;
}

#jvpppqmcof .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}

#jvpppqmcof .gt_row_group_first td {
  border-top-width: 2px;
}

#jvpppqmcof .gt_row_group_first th {
  border-top-width: 2px;
}

#jvpppqmcof .gt_summary_row {
  color: #333333;
  background-color: #D5D5D5;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#jvpppqmcof .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D5D5D5;
}

#jvpppqmcof .gt_first_summary_row.thick {
  border-top-width: 2px;
}

#jvpppqmcof .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#jvpppqmcof .gt_grand_summary_row {
  color: #FFFFFF;
  background-color: #929292;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#jvpppqmcof .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D5D5D5;
}

#jvpppqmcof .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D5D5D5;
}

#jvpppqmcof .gt_striped {
  background-color: #F4F4F4;
}

#jvpppqmcof .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#jvpppqmcof .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#jvpppqmcof .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#jvpppqmcof .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#jvpppqmcof .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#jvpppqmcof .gt_left {
  text-align: left;
}

#jvpppqmcof .gt_center {
  text-align: center;
}

#jvpppqmcof .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#jvpppqmcof .gt_font_normal {
  font-weight: normal;
}

#jvpppqmcof .gt_font_bold {
  font-weight: bold;
}

#jvpppqmcof .gt_font_italic {
  font-style: italic;
}

#jvpppqmcof .gt_super {
  font-size: 65%;
}

#jvpppqmcof .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}

#jvpppqmcof .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}

#jvpppqmcof .gt_indent_1 {
  text-indent: 5px;
}

#jvpppqmcof .gt_indent_2 {
  text-indent: 10px;
}

#jvpppqmcof .gt_indent_3 {
  text-indent: 15px;
}

#jvpppqmcof .gt_indent_4 {
  text-indent: 20px;
}

#jvpppqmcof .gt_indent_5 {
  text-indent: 25px;
}

#jvpppqmcof .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}

#jvpppqmcof div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>
<table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false">
  <thead>
    <tr class="gt_heading">
      <td colspan="10" class="gt_heading gt_title gt_font_normal gt_bottom_border" style>Convergence of the memory models</td>
    </tr>
    
    <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Model">Model</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Family">Family</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="N_obs">N_obs</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="N_participants">N_participants</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Chains">Chains</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Draws">Draws</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Max_Rhat">Max_Rhat</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Min_ESS_ratio">Min_ESS_ratio</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Divergent_pct">Divergent_pct</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Criterion">Criterion</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr><td headers="Model" class="gt_row gt_left">MemoryCondition</td>
<td headers="Family" class="gt_row gt_left">Categorical</td>
<td headers="N_obs" class="gt_row gt_right">21120</td>
<td headers="N_participants" class="gt_row gt_right">220</td>
<td headers="Chains" class="gt_row gt_right">8</td>
<td headers="Draws" class="gt_row gt_right">4000</td>
<td headers="Max_Rhat" class="gt_row gt_right">1.131</td>
<td headers="Min_ESS_ratio" class="gt_row gt_right">0.011</td>
<td headers="Divergent_pct" class="gt_row gt_right">1.45</td>
<td headers="Criterion" class="gt_row gt_left">loo</td></tr>
    <tr><td headers="Model" class="gt_row gt_left gt_striped">MemoryBelief</td>
<td headers="Family" class="gt_row gt_left gt_striped">Categorical</td>
<td headers="N_obs" class="gt_row gt_right gt_striped">21120</td>
<td headers="N_participants" class="gt_row gt_right gt_striped">220</td>
<td headers="Chains" class="gt_row gt_right gt_striped">8</td>
<td headers="Draws" class="gt_row gt_right gt_striped">4000</td>
<td headers="Max_Rhat" class="gt_row gt_right gt_striped">1.043</td>
<td headers="Min_ESS_ratio" class="gt_row gt_right gt_striped">0.035</td>
<td headers="Divergent_pct" class="gt_row gt_right gt_striped">0.00</td>
<td headers="Criterion" class="gt_row gt_left gt_striped">loo</td></tr>
    <tr><td headers="Model" class="gt_row gt_left">MemoryConditionBelief</td>
<td headers="Family" class="gt_row gt_left">Categorical</td>
<td headers="N_obs" class="gt_row gt_right">10416</td>
<td headers="N_participants" class="gt_row gt_right">217</td>
<td headers="Chains" class="gt_row gt_right">8</td>
<td headers="Draws" class="gt_row gt_right">4000</td>
<td headers="Max_Rhat" class="gt_row gt_right">1.031</td>
<td headers="Min_ESS_ratio" class="gt_row gt_right">0.078</td>
<td headers="Divergent_pct" class="gt_row gt_right">0.00</td>
<td headers="Criterion" class="gt_row gt_left">loo</td></tr>
  </tbody>
  
</table>
</div>
```


::: {.callout-note collapse="true" title="Convergence of the memory models (Markdown table, for text readers)"}

|Model                 |Family      | N_obs| N_participants| Chains| Draws| Max_Rhat| Min_ESS_ratio| Divergent_pct|Criterion |
|:---------------------|:-----------|-----:|--------------:|------:|-----:|--------:|-------------:|-------------:|:---------|
|MemoryCondition       |Categorical | 21120|            220|      8|  4000|    1.131|         0.011|          1.45|loo       |
|MemoryBelief          |Categorical | 21120|            220|      8|  4000|    1.043|         0.035|          0.00|loo       |
|MemoryConditionBelief |Categorical | 10416|            217|      8|  4000|    1.031|         0.078|          0.00|loo       |

:::

:::
:::



::: {.cell}

```{.r .cell-code}
credible <- results_memory_contrasts |>
  filter(Credible, Response1 == Response2) |>
  mutate(Answer = Response1,
         Contrast = paste(Level1, "-", Level2),
         Diff_pp = insight::format_value(100 * Median),
         CI = sprintf("[%s, %s]", insight::format_value(100 * CI_low), insight::format_value(100 * CI_high)),
         pd_fmt = insight::format_pd(pd, name = NULL),
         Effect = ifelse(Median < 0, "Negative", "Positive")) |>
  arrange(Model, Answer, desc(abs(Median))) |>
  select(Model, Answer, Contrast, Diff_pp, CI, pd_fmt, Effect)

make_tables(credible, names(credible),
            "Credible differences in the probability of each answer between levels, in percentage points")
```

::: {.cell-output-display}

```{=html}
<div id="qoiswwkibi" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#qoiswwkibi table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#qoiswwkibi thead, #qoiswwkibi tbody, #qoiswwkibi tfoot, #qoiswwkibi tr, #qoiswwkibi td, #qoiswwkibi th {
  border-style: none;
}

#qoiswwkibi p {
  margin: 0;
  padding: 0;
}

#qoiswwkibi .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 13px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 3px;
  border-top-color: #D5D5D5;
  border-right-style: solid;
  border-right-width: 3px;
  border-right-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 3px;
  border-bottom-color: #D5D5D5;
  border-left-style: solid;
  border-left-width: 3px;
  border-left-color: #D5D5D5;
}

#qoiswwkibi .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}

#qoiswwkibi .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#qoiswwkibi .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#qoiswwkibi .gt_heading {
  background-color: #FFFFFF;
  text-align: left;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#qoiswwkibi .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#qoiswwkibi .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#qoiswwkibi .gt_col_heading {
  color: #FFFFFF;
  background-color: #000000;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#qoiswwkibi .gt_column_spanner_outer {
  color: #FFFFFF;
  background-color: #000000;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#qoiswwkibi .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#qoiswwkibi .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#qoiswwkibi .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#qoiswwkibi .gt_spanner_row {
  border-bottom-style: hidden;
}

#qoiswwkibi .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}

#qoiswwkibi .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
  vertical-align: middle;
}

#qoiswwkibi .gt_from_md > :first-child {
  margin-top: 0;
}

#qoiswwkibi .gt_from_md > :last-child {
  margin-bottom: 0;
}

#qoiswwkibi .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D5D5D5;
  border-left-style: solid;
  border-left-width: 1px;
  border-left-color: #D5D5D5;
  border-right-style: solid;
  border-right-width: 1px;
  border-right-color: #D5D5D5;
  vertical-align: middle;
  overflow-x: hidden;
}

#qoiswwkibi .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #5F5F5F;
  padding-left: 5px;
  padding-right: 5px;
}

#qoiswwkibi .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}

#qoiswwkibi .gt_row_group_first td {
  border-top-width: 2px;
}

#qoiswwkibi .gt_row_group_first th {
  border-top-width: 2px;
}

#qoiswwkibi .gt_summary_row {
  color: #333333;
  background-color: #D5D5D5;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#qoiswwkibi .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D5D5D5;
}

#qoiswwkibi .gt_first_summary_row.thick {
  border-top-width: 2px;
}

#qoiswwkibi .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#qoiswwkibi .gt_grand_summary_row {
  color: #FFFFFF;
  background-color: #929292;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#qoiswwkibi .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D5D5D5;
}

#qoiswwkibi .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D5D5D5;
}

#qoiswwkibi .gt_striped {
  background-color: #F4F4F4;
}

#qoiswwkibi .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D5D5D5;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D5D5D5;
}

#qoiswwkibi .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#qoiswwkibi .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#qoiswwkibi .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#qoiswwkibi .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#qoiswwkibi .gt_left {
  text-align: left;
}

#qoiswwkibi .gt_center {
  text-align: center;
}

#qoiswwkibi .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#qoiswwkibi .gt_font_normal {
  font-weight: normal;
}

#qoiswwkibi .gt_font_bold {
  font-weight: bold;
}

#qoiswwkibi .gt_font_italic {
  font-style: italic;
}

#qoiswwkibi .gt_super {
  font-size: 65%;
}

#qoiswwkibi .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}

#qoiswwkibi .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}

#qoiswwkibi .gt_indent_1 {
  text-indent: 5px;
}

#qoiswwkibi .gt_indent_2 {
  text-indent: 10px;
}

#qoiswwkibi .gt_indent_3 {
  text-indent: 15px;
}

#qoiswwkibi .gt_indent_4 {
  text-indent: 20px;
}

#qoiswwkibi .gt_indent_5 {
  text-indent: 25px;
}

#qoiswwkibi .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}

#qoiswwkibi div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>
<table class="gt_table" data-quarto-disable-processing="false" data-quarto-bootstrap="false">
  <thead>
    <tr class="gt_heading">
      <td colspan="6" class="gt_heading gt_title gt_font_normal gt_bottom_border" style>Credible differences in the probability of each answer between levels, in percentage points</td>
    </tr>
    
    <tr class="gt_col_headings">
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Model">Model</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Answer">Answer</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="Diff_pp">Diff_pp</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="CI">CI</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1" scope="col" id="pd_fmt">pd_fmt</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1" scope="col" id="Effect">Effect</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="None - AI Original">None - AI Original</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="None - AI Original  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="None - AI Original  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">AI Copy</td>
<td headers="None - AI Original  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-3.84</td>
<td headers="None - AI Original  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-5.06, -2.75]</td>
<td headers="None - AI Original  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="None - AI Original  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="None - AI Original  Model" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="None - AI Original  Answer" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">AI Original</td>
<td headers="None - AI Original  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">-11.99</td>
<td headers="None - AI Original  CI" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">[-15.04, -9.22]</td>
<td headers="None - AI Original  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">100%</td>
<td headers="None - AI Original  Effect" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="None - AI Original  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="None - AI Original  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">Human Forgery</td>
<td headers="None - AI Original  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-3.19</td>
<td headers="None - AI Original  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-4.70, -1.85]</td>
<td headers="None - AI Original  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="None - AI Original  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="None - AI Original  Model" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="None - AI Original  Answer" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Human Original</td>
<td headers="None - AI Original  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">-6.01</td>
<td headers="None - AI Original  CI" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">[-8.33, -3.77]</td>
<td headers="None - AI Original  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">100%</td>
<td headers="None - AI Original  Effect" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="None - AI Original  Model" class="gt_row gt_left" style="background-color: #E8F5E9;">MemoryBelief</td>
<td headers="None - AI Original  Answer" class="gt_row gt_left" style="background-color: #E8F5E9;">Not recognized</td>
<td headers="None - AI Original  Diff_pp" class="gt_row gt_right" style="background-color: #E8F5E9;">25.14</td>
<td headers="None - AI Original  CI" class="gt_row gt_left" style="background-color: #E8F5E9;">[19.75, 30.08]</td>
<td headers="None - AI Original  pd_fmt" class="gt_row gt_right" style="background-color: #E8F5E9;">100%</td>
<td headers="None - AI Original  Effect" class="gt_row gt_left" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="None - AI Copy">None - AI Copy</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="None - AI Copy  Model" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="None - AI Copy  Answer" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">AI Copy</td>
<td headers="None - AI Copy  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">-3.40</td>
<td headers="None - AI Copy  CI" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">[-4.55, -2.41]</td>
<td headers="None - AI Copy  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">100%</td>
<td headers="None - AI Copy  Effect" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="None - AI Copy  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="None - AI Copy  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">AI Original</td>
<td headers="None - AI Copy  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-8.99</td>
<td headers="None - AI Copy  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-11.64, -6.56]</td>
<td headers="None - AI Copy  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="None - AI Copy  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="None - AI Copy  Model" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="None - AI Copy  Answer" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Human Forgery</td>
<td headers="None - AI Copy  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">-4.60</td>
<td headers="None - AI Copy  CI" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">[-6.14, -3.14]</td>
<td headers="None - AI Copy  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">100%</td>
<td headers="None - AI Copy  Effect" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="None - AI Copy  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="None - AI Copy  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">Human Original</td>
<td headers="None - AI Copy  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-7.12</td>
<td headers="None - AI Copy  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-9.51, -4.80]</td>
<td headers="None - AI Copy  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="None - AI Copy  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="None - AI Copy  Model" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">MemoryBelief</td>
<td headers="None - AI Copy  Answer" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Not recognized</td>
<td headers="None - AI Copy  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">24.20</td>
<td headers="None - AI Copy  CI" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">[19.18, 29.17]</td>
<td headers="None - AI Copy  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">100%</td>
<td headers="None - AI Copy  Effect" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="None - Human Forgery">None - Human Forgery</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="None - Human Forgery  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="None - Human Forgery  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">AI Copy</td>
<td headers="None - Human Forgery  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-2.80</td>
<td headers="None - Human Forgery  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-4.21, -1.70]</td>
<td headers="None - Human Forgery  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="None - Human Forgery  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="None - Human Forgery  Model" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="None - Human Forgery  Answer" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">AI Original</td>
<td headers="None - Human Forgery  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">-6.44</td>
<td headers="None - Human Forgery  CI" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">[-9.10, -4.07]</td>
<td headers="None - Human Forgery  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">100%</td>
<td headers="None - Human Forgery  Effect" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="None - Human Forgery  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="None - Human Forgery  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">Human Forgery</td>
<td headers="None - Human Forgery  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-5.78</td>
<td headers="None - Human Forgery  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-7.60, -4.08]</td>
<td headers="None - Human Forgery  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="None - Human Forgery  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="None - Human Forgery  Model" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="None - Human Forgery  Answer" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Human Original</td>
<td headers="None - Human Forgery  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">-10.94</td>
<td headers="None - Human Forgery  CI" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">[-13.75, -8.15]</td>
<td headers="None - Human Forgery  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">100%</td>
<td headers="None - Human Forgery  Effect" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="None - Human Forgery  Model" class="gt_row gt_left" style="background-color: #E8F5E9;">MemoryBelief</td>
<td headers="None - Human Forgery  Answer" class="gt_row gt_left" style="background-color: #E8F5E9;">Not recognized</td>
<td headers="None - Human Forgery  Diff_pp" class="gt_row gt_right" style="background-color: #E8F5E9;">26.05</td>
<td headers="None - Human Forgery  CI" class="gt_row gt_left" style="background-color: #E8F5E9;">[20.71, 31.17]</td>
<td headers="None - Human Forgery  pd_fmt" class="gt_row gt_right" style="background-color: #E8F5E9;">100%</td>
<td headers="None - Human Forgery  Effect" class="gt_row gt_left" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="AI Original - Human Original">AI Original - Human Original</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="AI Original - Human Original  Model" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">MemoryBelief</td>
<td headers="AI Original - Human Original  Answer" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">AI Copy</td>
<td headers="AI Original - Human Original  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">2.05</td>
<td headers="AI Original - Human Original  CI" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">[1.03, 3.16]</td>
<td headers="AI Original - Human Original  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">100%</td>
<td headers="AI Original - Human Original  Effect" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr><td headers="AI Original - Human Original  Model" class="gt_row gt_left" style="background-color: #E8F5E9;">MemoryBelief</td>
<td headers="AI Original - Human Original  Answer" class="gt_row gt_left" style="background-color: #E8F5E9;">AI Original</td>
<td headers="AI Original - Human Original  Diff_pp" class="gt_row gt_right" style="background-color: #E8F5E9;">6.47</td>
<td headers="AI Original - Human Original  CI" class="gt_row gt_left" style="background-color: #E8F5E9;">[4.65, 8.52]</td>
<td headers="AI Original - Human Original  pd_fmt" class="gt_row gt_right" style="background-color: #E8F5E9;">100%</td>
<td headers="AI Original - Human Original  Effect" class="gt_row gt_left" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr><td headers="AI Original - Human Original  Model" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="AI Original - Human Original  Answer" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Human Forgery</td>
<td headers="AI Original - Human Original  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">-1.37</td>
<td headers="AI Original - Human Original  CI" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">[-2.58, -0.05]</td>
<td headers="AI Original - Human Original  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">97.80%</td>
<td headers="AI Original - Human Original  Effect" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="AI Original - Human Original  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="AI Original - Human Original  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">Human Original</td>
<td headers="AI Original - Human Original  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-8.02</td>
<td headers="AI Original - Human Original  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-9.95, -6.15]</td>
<td headers="AI Original - Human Original  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="AI Original - Human Original  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="None - Human Original">None - Human Original</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="None - Human Original  Model" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="None - Human Original  Answer" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">AI Copy</td>
<td headers="None - Human Original  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">-1.79</td>
<td headers="None - Human Original  CI" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">[-2.51, -1.12]</td>
<td headers="None - Human Original  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">100%</td>
<td headers="None - Human Original  Effect" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="None - Human Original  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="None - Human Original  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">AI Original</td>
<td headers="None - Human Original  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-5.52</td>
<td headers="None - Human Original  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-7.56, -3.57]</td>
<td headers="None - Human Original  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="None - Human Original  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="None - Human Original  Model" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="None - Human Original  Answer" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Human Forgery</td>
<td headers="None - Human Original  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">-4.55</td>
<td headers="None - Human Original  CI" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">[-5.78, -3.34]</td>
<td headers="None - Human Original  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">100%</td>
<td headers="None - Human Original  Effect" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="None - Human Original  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="None - Human Original  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">Human Original</td>
<td headers="None - Human Original  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-14.08</td>
<td headers="None - Human Original  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-16.68, -11.39]</td>
<td headers="None - Human Original  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="None - Human Original  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="None - Human Original  Model" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">MemoryBelief</td>
<td headers="None - Human Original  Answer" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Not recognized</td>
<td headers="None - Human Original  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">25.98</td>
<td headers="None - Human Original  CI" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">[20.93, 30.73]</td>
<td headers="None - Human Original  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">100%</td>
<td headers="None - Human Original  Effect" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="AI Copy - Human Original">AI Copy - Human Original</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="AI Copy - Human Original  Model" class="gt_row gt_left" style="background-color: #E8F5E9;">MemoryBelief</td>
<td headers="AI Copy - Human Original  Answer" class="gt_row gt_left" style="background-color: #E8F5E9;">AI Copy</td>
<td headers="AI Copy - Human Original  Diff_pp" class="gt_row gt_right" style="background-color: #E8F5E9;">1.60</td>
<td headers="AI Copy - Human Original  CI" class="gt_row gt_left" style="background-color: #E8F5E9;">[0.68, 2.66]</td>
<td headers="AI Copy - Human Original  pd_fmt" class="gt_row gt_right" style="background-color: #E8F5E9;">100%</td>
<td headers="AI Copy - Human Original  Effect" class="gt_row gt_left" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr><td headers="AI Copy - Human Original  Model" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">MemoryBelief</td>
<td headers="AI Copy - Human Original  Answer" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">AI Original</td>
<td headers="AI Copy - Human Original  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">3.49</td>
<td headers="AI Copy - Human Original  CI" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">[1.87, 5.19]</td>
<td headers="AI Copy - Human Original  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">100%</td>
<td headers="AI Copy - Human Original  Effect" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr><td headers="AI Copy - Human Original  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="AI Copy - Human Original  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">Human Original</td>
<td headers="AI Copy - Human Original  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-6.90</td>
<td headers="AI Copy - Human Original  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-8.79, -5.09]</td>
<td headers="AI Copy - Human Original  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="AI Copy - Human Original  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="AI Original - Human Forgery">AI Original - Human Forgery</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="AI Original - Human Forgery  Model" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">MemoryBelief</td>
<td headers="AI Original - Human Forgery  Answer" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">AI Original</td>
<td headers="AI Original - Human Forgery  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">5.54</td>
<td headers="AI Original - Human Forgery  CI" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">[3.27, 7.87]</td>
<td headers="AI Original - Human Forgery  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">100%</td>
<td headers="AI Original - Human Forgery  Effect" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr><td headers="AI Original - Human Forgery  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="AI Original - Human Forgery  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">Human Forgery</td>
<td headers="AI Original - Human Forgery  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-2.56</td>
<td headers="AI Original - Human Forgery  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-4.32, -0.89]</td>
<td headers="AI Original - Human Forgery  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">99.92%</td>
<td headers="AI Original - Human Forgery  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="AI Original - Human Forgery  Model" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="AI Original - Human Forgery  Answer" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Human Original</td>
<td headers="AI Original - Human Forgery  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">-4.89</td>
<td headers="AI Original - Human Forgery  CI" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">[-7.27, -2.61]</td>
<td headers="AI Original - Human Forgery  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">100%</td>
<td headers="AI Original - Human Forgery  Effect" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="AI Copy - AI Original">AI Copy - AI Original</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="AI Copy - AI Original  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="AI Copy - AI Original  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">AI Original</td>
<td headers="AI Copy - AI Original  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-2.97</td>
<td headers="AI Copy - AI Original  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-5.19, -0.88]</td>
<td headers="AI Copy - AI Original  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">99.83%</td>
<td headers="AI Copy - AI Original  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="AI Copy - Human Forgery">AI Copy - Human Forgery</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="AI Copy - Human Forgery  Model" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">MemoryBelief</td>
<td headers="AI Copy - Human Forgery  Answer" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">AI Original</td>
<td headers="AI Copy - Human Forgery  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">2.54</td>
<td headers="AI Copy - Human Forgery  CI" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">[0.41, 4.63]</td>
<td headers="AI Copy - Human Forgery  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">99.02%</td>
<td headers="AI Copy - Human Forgery  Effect" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr><td headers="AI Copy - Human Forgery  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="AI Copy - Human Forgery  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">Human Original</td>
<td headers="AI Copy - Human Forgery  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-3.77</td>
<td headers="AI Copy - Human Forgery  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-6.17, -1.46]</td>
<td headers="AI Copy - Human Forgery  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">99.95%</td>
<td headers="AI Copy - Human Forgery  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="Human Forgery - Human Original">Human Forgery - Human Original</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="Human Forgery - Human Original  Model" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">MemoryBelief</td>
<td headers="Human Forgery - Human Original  Answer" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Human Original</td>
<td headers="Human Forgery - Human Original  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">-3.16</td>
<td headers="Human Forgery - Human Original  CI" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">[-5.27, -0.98]</td>
<td headers="Human Forgery - Human Original  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">99.62%</td>
<td headers="Human Forgery - Human Original  Effect" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="New Items - Human Original">New Items - Human Original</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="New Items - Human Original  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryCondition</td>
<td headers="New Items - Human Original  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">AI-Generated</td>
<td headers="New Items - Human Original  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-11.15</td>
<td headers="New Items - Human Original  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-13.44, -8.84]</td>
<td headers="New Items - Human Original  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="New Items - Human Original  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="New Items - Human Original  Model" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">MemoryCondition</td>
<td headers="New Items - Human Original  Answer" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Human Forgery</td>
<td headers="New Items - Human Original  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">-4.65</td>
<td headers="New Items - Human Original  CI" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">[-5.70, -3.68]</td>
<td headers="New Items - Human Original  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">100%</td>
<td headers="New Items - Human Original  Effect" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="New Items - Human Original  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryCondition</td>
<td headers="New Items - Human Original  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">Human Original</td>
<td headers="New Items - Human Original  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-16.66</td>
<td headers="New Items - Human Original  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-19.31, -14.11]</td>
<td headers="New Items - Human Original  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="New Items - Human Original  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="New Items - Human Original  Model" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">MemoryCondition</td>
<td headers="New Items - Human Original  Answer" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Not recognized</td>
<td headers="New Items - Human Original  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">32.50</td>
<td headers="New Items - Human Original  CI" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">[28.02, 36.86]</td>
<td headers="New Items - Human Original  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">100%</td>
<td headers="New Items - Human Original  Effect" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="New Items - AI-Generated">New Items - AI-Generated</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="New Items - AI-Generated  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryCondition</td>
<td headers="New Items - AI-Generated  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">AI-Generated</td>
<td headers="New Items - AI-Generated  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-10.92</td>
<td headers="New Items - AI-Generated  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-13.25, -8.70]</td>
<td headers="New Items - AI-Generated  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="New Items - AI-Generated  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="New Items - AI-Generated  Model" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">MemoryCondition</td>
<td headers="New Items - AI-Generated  Answer" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Human Forgery</td>
<td headers="New Items - AI-Generated  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">-4.84</td>
<td headers="New Items - AI-Generated  CI" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">[-5.94, -3.83]</td>
<td headers="New Items - AI-Generated  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">100%</td>
<td headers="New Items - AI-Generated  Effect" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="New Items - AI-Generated  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryCondition</td>
<td headers="New Items - AI-Generated  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">Human Original</td>
<td headers="New Items - AI-Generated  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-15.38</td>
<td headers="New Items - AI-Generated  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-18.06, -12.84]</td>
<td headers="New Items - AI-Generated  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="New Items - AI-Generated  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="New Items - AI-Generated  Model" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">MemoryCondition</td>
<td headers="New Items - AI-Generated  Answer" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Not recognized</td>
<td headers="New Items - AI-Generated  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">31.22</td>
<td headers="New Items - AI-Generated  CI" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">[26.65, 35.59]</td>
<td headers="New Items - AI-Generated  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">100%</td>
<td headers="New Items - AI-Generated  Effect" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="New Items - Human Forgery">New Items - Human Forgery</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="New Items - Human Forgery  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryCondition</td>
<td headers="New Items - Human Forgery  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">AI-Generated</td>
<td headers="New Items - Human Forgery  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-10.30</td>
<td headers="New Items - Human Forgery  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-12.51, -8.11]</td>
<td headers="New Items - Human Forgery  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="New Items - Human Forgery  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="New Items - Human Forgery  Model" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">MemoryCondition</td>
<td headers="New Items - Human Forgery  Answer" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Human Forgery</td>
<td headers="New Items - Human Forgery  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">-5.02</td>
<td headers="New Items - Human Forgery  CI" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">[-6.12, -3.98]</td>
<td headers="New Items - Human Forgery  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">100%</td>
<td headers="New Items - Human Forgery  Effect" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="New Items - Human Forgery  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryCondition</td>
<td headers="New Items - Human Forgery  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">Human Original</td>
<td headers="New Items - Human Forgery  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-15.85</td>
<td headers="New Items - Human Forgery  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-18.46, -13.29]</td>
<td headers="New Items - Human Forgery  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="New Items - Human Forgery  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="New Items - Human Forgery  Model" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">MemoryCondition</td>
<td headers="New Items - Human Forgery  Answer" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Not recognized</td>
<td headers="New Items - Human Forgery  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">31.22</td>
<td headers="New Items - Human Forgery  CI" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">[26.71, 35.51]</td>
<td headers="New Items - Human Forgery  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">100%</td>
<td headers="New Items - Human Forgery  Effect" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="Human Original - AI Original">Human Original - AI Original</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="Human Original - AI Original  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryConditionBelief</td>
<td headers="Human Original - AI Original  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">AI-Generated</td>
<td headers="Human Original - AI Original  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-6.95</td>
<td headers="Human Original - AI Original  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-8.93, -5.01]</td>
<td headers="Human Original - AI Original  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="Human Original - AI Original  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="Human Original - AI Original  Model" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">MemoryConditionBelief</td>
<td headers="Human Original - AI Original  Answer" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Human Forgery</td>
<td headers="Human Original - AI Original  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">1.86</td>
<td headers="Human Original - AI Original  CI" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">[0.61, 3.05]</td>
<td headers="Human Original - AI Original  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">99.88%</td>
<td headers="Human Original - AI Original  Effect" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr><td headers="Human Original - AI Original  Model" class="gt_row gt_left" style="background-color: #E8F5E9;">MemoryConditionBelief</td>
<td headers="Human Original - AI Original  Answer" class="gt_row gt_left" style="background-color: #E8F5E9;">Human Original</td>
<td headers="Human Original - AI Original  Diff_pp" class="gt_row gt_right" style="background-color: #E8F5E9;">5.49</td>
<td headers="Human Original - AI Original  CI" class="gt_row gt_left" style="background-color: #E8F5E9;">[3.41, 7.60]</td>
<td headers="Human Original - AI Original  pd_fmt" class="gt_row gt_right" style="background-color: #E8F5E9;">100%</td>
<td headers="Human Original - AI Original  Effect" class="gt_row gt_left" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="Human Forgery - AI Original">Human Forgery - AI Original</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="Human Forgery - AI Original  Model" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">MemoryConditionBelief</td>
<td headers="Human Forgery - AI Original  Answer" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">AI-Generated</td>
<td headers="Human Forgery - AI Original  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">-4.87</td>
<td headers="Human Forgery - AI Original  CI" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">[-7.30, -2.32]</td>
<td headers="Human Forgery - AI Original  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">100%</td>
<td headers="Human Forgery - AI Original  Effect" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="Human Forgery - AI Original  Model" class="gt_row gt_left" style="background-color: #E8F5E9;">MemoryConditionBelief</td>
<td headers="Human Forgery - AI Original  Answer" class="gt_row gt_left" style="background-color: #E8F5E9;">Human Forgery</td>
<td headers="Human Forgery - AI Original  Diff_pp" class="gt_row gt_right" style="background-color: #E8F5E9;">2.03</td>
<td headers="Human Forgery - AI Original  CI" class="gt_row gt_left" style="background-color: #E8F5E9;">[0.42, 3.75]</td>
<td headers="Human Forgery - AI Original  pd_fmt" class="gt_row gt_right" style="background-color: #E8F5E9;">99.38%</td>
<td headers="Human Forgery - AI Original  Effect" class="gt_row gt_left" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr><td headers="Human Forgery - AI Original  Model" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">MemoryConditionBelief</td>
<td headers="Human Forgery - AI Original  Answer" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Human Original</td>
<td headers="Human Forgery - AI Original  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">3.37</td>
<td headers="Human Forgery - AI Original  CI" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">[0.73, 6.07]</td>
<td headers="Human Forgery - AI Original  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">99.40%</td>
<td headers="Human Forgery - AI Original  Effect" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="Human Original - AI Copy">Human Original - AI Copy</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="Human Original - AI Copy  Model" class="gt_row gt_left" style="background-color: #FFEBEE;">MemoryConditionBelief</td>
<td headers="Human Original - AI Copy  Answer" class="gt_row gt_left" style="background-color: #FFEBEE;">AI-Generated</td>
<td headers="Human Original - AI Copy  Diff_pp" class="gt_row gt_right" style="background-color: #FFEBEE;">-3.95</td>
<td headers="Human Original - AI Copy  CI" class="gt_row gt_left" style="background-color: #FFEBEE;">[-5.75, -2.18]</td>
<td headers="Human Original - AI Copy  pd_fmt" class="gt_row gt_right" style="background-color: #FFEBEE;">100%</td>
<td headers="Human Original - AI Copy  Effect" class="gt_row gt_left" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr><td headers="Human Original - AI Copy  Model" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">MemoryConditionBelief</td>
<td headers="Human Original - AI Copy  Answer" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Human Original</td>
<td headers="Human Original - AI Copy  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">5.00</td>
<td headers="Human Original - AI Copy  CI" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">[2.92, 7.07]</td>
<td headers="Human Original - AI Copy  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #E8F5E9;">100%</td>
<td headers="Human Original - AI Copy  Effect" class="gt_row gt_left gt_striped" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="AI Original - AI Copy">AI Original - AI Copy</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="AI Original - AI Copy  Model" class="gt_row gt_left" style="background-color: #E8F5E9;">MemoryConditionBelief</td>
<td headers="AI Original - AI Copy  Answer" class="gt_row gt_left" style="background-color: #E8F5E9;">AI-Generated</td>
<td headers="AI Original - AI Copy  Diff_pp" class="gt_row gt_right" style="background-color: #E8F5E9;">2.97</td>
<td headers="AI Original - AI Copy  CI" class="gt_row gt_left" style="background-color: #E8F5E9;">[0.77, 5.29]</td>
<td headers="AI Original - AI Copy  pd_fmt" class="gt_row gt_right" style="background-color: #E8F5E9;">99.62%</td>
<td headers="AI Original - AI Copy  Effect" class="gt_row gt_left" style="background-color: #E8F5E9;">Positive</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="Human Original - Human Forgery">Human Original - Human Forgery</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="Human Original - Human Forgery  Model" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">MemoryConditionBelief</td>
<td headers="Human Original - Human Forgery  Answer" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">AI-Generated</td>
<td headers="Human Original - Human Forgery  Diff_pp" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">-2.09</td>
<td headers="Human Original - Human Forgery  CI" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">[-4.22, -0.05]</td>
<td headers="Human Original - Human Forgery  pd_fmt" class="gt_row gt_right gt_striped" style="background-color: #FFEBEE;">97.78%</td>
<td headers="Human Original - Human Forgery  Effect" class="gt_row gt_left gt_striped" style="background-color: #FFEBEE;">Negative</td></tr>
    <tr class="gt_group_heading_row">
      <th colspan="6" class="gt_group_heading" scope="colgroup" id="Human Forgery - AI Copy">Human Forgery - AI Copy</th>
    </tr>
    <tr class="gt_row_group_first"><td headers="Human Forgery - AI Copy  Model" class="gt_row gt_left" style="background-color: #E8F5E9;">MemoryConditionBelief</td>
<td headers="Human Forgery - AI Copy  Answer" class="gt_row gt_left" style="background-color: #E8F5E9;">Human Original</td>
<td headers="Human Forgery - AI Copy  Diff_pp" class="gt_row gt_right" style="background-color: #E8F5E9;">2.89</td>
<td headers="Human Forgery - AI Copy  CI" class="gt_row gt_left" style="background-color: #E8F5E9;">[0.27, 5.58]</td>
<td headers="Human Forgery - AI Copy  pd_fmt" class="gt_row gt_right" style="background-color: #E8F5E9;">98.52%</td>
<td headers="Human Forgery - AI Copy  Effect" class="gt_row gt_left" style="background-color: #E8F5E9;">Positive</td></tr>
  </tbody>
  
</table>
</div>
```


::: {.callout-note collapse="true" title="Credible differences in the probability of each answer between levels, in percentage points (Markdown table, for text readers)"}

|Model                 |Answer         |Contrast                       |Diff_pp |CI               |pd_fmt |Effect   |
|:---------------------|:--------------|:------------------------------|:-------|:----------------|:------|:--------|
|MemoryBelief          |AI Copy        |None - AI Original             |-3.84   |[-5.06, -2.75]   |100%   |Negative |
|MemoryBelief          |AI Copy        |None - AI Copy                 |-3.40   |[-4.55, -2.41]   |100%   |Negative |
|MemoryBelief          |AI Copy        |None - Human Forgery           |-2.80   |[-4.21, -1.70]   |100%   |Negative |
|MemoryBelief          |AI Copy        |AI Original - Human Original   |2.05    |[1.03, 3.16]     |100%   |Positive |
|MemoryBelief          |AI Copy        |None - Human Original          |-1.79   |[-2.51, -1.12]   |100%   |Negative |
|MemoryBelief          |AI Copy        |AI Copy - Human Original       |1.60    |[0.68, 2.66]     |100%   |Positive |
|MemoryBelief          |AI Original    |None - AI Original             |-11.99  |[-15.04, -9.22]  |100%   |Negative |
|MemoryBelief          |AI Original    |None - AI Copy                 |-8.99   |[-11.64, -6.56]  |100%   |Negative |
|MemoryBelief          |AI Original    |AI Original - Human Original   |6.47    |[4.65, 8.52]     |100%   |Positive |
|MemoryBelief          |AI Original    |None - Human Forgery           |-6.44   |[-9.10, -4.07]   |100%   |Negative |
|MemoryBelief          |AI Original    |AI Original - Human Forgery    |5.54    |[3.27, 7.87]     |100%   |Positive |
|MemoryBelief          |AI Original    |None - Human Original          |-5.52   |[-7.56, -3.57]   |100%   |Negative |
|MemoryBelief          |AI Original    |AI Copy - Human Original       |3.49    |[1.87, 5.19]     |100%   |Positive |
|MemoryBelief          |AI Original    |AI Copy - AI Original          |-2.97   |[-5.19, -0.88]   |99.83% |Negative |
|MemoryBelief          |AI Original    |AI Copy - Human Forgery        |2.54    |[0.41, 4.63]     |99.02% |Positive |
|MemoryBelief          |Human Forgery  |None - Human Forgery           |-5.78   |[-7.60, -4.08]   |100%   |Negative |
|MemoryBelief          |Human Forgery  |None - AI Copy                 |-4.60   |[-6.14, -3.14]   |100%   |Negative |
|MemoryBelief          |Human Forgery  |None - Human Original          |-4.55   |[-5.78, -3.34]   |100%   |Negative |
|MemoryBelief          |Human Forgery  |None - AI Original             |-3.19   |[-4.70, -1.85]   |100%   |Negative |
|MemoryBelief          |Human Forgery  |AI Original - Human Forgery    |-2.56   |[-4.32, -0.89]   |99.92% |Negative |
|MemoryBelief          |Human Forgery  |AI Original - Human Original   |-1.37   |[-2.58, -0.05]   |97.80% |Negative |
|MemoryBelief          |Human Original |None - Human Original          |-14.08  |[-16.68, -11.39] |100%   |Negative |
|MemoryBelief          |Human Original |None - Human Forgery           |-10.94  |[-13.75, -8.15]  |100%   |Negative |
|MemoryBelief          |Human Original |AI Original - Human Original   |-8.02   |[-9.95, -6.15]   |100%   |Negative |
|MemoryBelief          |Human Original |None - AI Copy                 |-7.12   |[-9.51, -4.80]   |100%   |Negative |
|MemoryBelief          |Human Original |AI Copy - Human Original       |-6.90   |[-8.79, -5.09]   |100%   |Negative |
|MemoryBelief          |Human Original |None - AI Original             |-6.01   |[-8.33, -3.77]   |100%   |Negative |
|MemoryBelief          |Human Original |AI Original - Human Forgery    |-4.89   |[-7.27, -2.61]   |100%   |Negative |
|MemoryBelief          |Human Original |AI Copy - Human Forgery        |-3.77   |[-6.17, -1.46]   |99.95% |Negative |
|MemoryBelief          |Human Original |Human Forgery - Human Original |-3.16   |[-5.27, -0.98]   |99.62% |Negative |
|MemoryBelief          |Not recognized |None - Human Forgery           |26.05   |[20.71, 31.17]   |100%   |Positive |
|MemoryBelief          |Not recognized |None - Human Original          |25.98   |[20.93, 30.73]   |100%   |Positive |
|MemoryBelief          |Not recognized |None - AI Original             |25.14   |[19.75, 30.08]   |100%   |Positive |
|MemoryBelief          |Not recognized |None - AI Copy                 |24.20   |[19.18, 29.17]   |100%   |Positive |
|MemoryCondition       |AI-Generated   |New Items - Human Original     |-11.15  |[-13.44, -8.84]  |100%   |Negative |
|MemoryCondition       |AI-Generated   |New Items - AI-Generated       |-10.92  |[-13.25, -8.70]  |100%   |Negative |
|MemoryCondition       |AI-Generated   |New Items - Human Forgery      |-10.30  |[-12.51, -8.11]  |100%   |Negative |
|MemoryCondition       |Human Forgery  |New Items - Human Forgery      |-5.02   |[-6.12, -3.98]   |100%   |Negative |
|MemoryCondition       |Human Forgery  |New Items - AI-Generated       |-4.84   |[-5.94, -3.83]   |100%   |Negative |
|MemoryCondition       |Human Forgery  |New Items - Human Original     |-4.65   |[-5.70, -3.68]   |100%   |Negative |
|MemoryCondition       |Human Original |New Items - Human Original     |-16.66  |[-19.31, -14.11] |100%   |Negative |
|MemoryCondition       |Human Original |New Items - Human Forgery      |-15.85  |[-18.46, -13.29] |100%   |Negative |
|MemoryCondition       |Human Original |New Items - AI-Generated       |-15.38  |[-18.06, -12.84] |100%   |Negative |
|MemoryCondition       |Not recognized |New Items - Human Original     |32.50   |[28.02, 36.86]   |100%   |Positive |
|MemoryCondition       |Not recognized |New Items - Human Forgery      |31.22   |[26.71, 35.51]   |100%   |Positive |
|MemoryCondition       |Not recognized |New Items - AI-Generated       |31.22   |[26.65, 35.59]   |100%   |Positive |
|MemoryConditionBelief |AI-Generated   |Human Original - AI Original   |-6.95   |[-8.93, -5.01]   |100%   |Negative |
|MemoryConditionBelief |AI-Generated   |Human Forgery - AI Original    |-4.87   |[-7.30, -2.32]   |100%   |Negative |
|MemoryConditionBelief |AI-Generated   |Human Original - AI Copy       |-3.95   |[-5.75, -2.18]   |100%   |Negative |
|MemoryConditionBelief |AI-Generated   |AI Original - AI Copy          |2.97    |[0.77, 5.29]     |99.62% |Positive |
|MemoryConditionBelief |AI-Generated   |Human Original - Human Forgery |-2.09   |[-4.22, -0.05]   |97.78% |Negative |
|MemoryConditionBelief |Human Forgery  |Human Forgery - AI Original    |2.03    |[0.42, 3.75]     |99.38% |Positive |
|MemoryConditionBelief |Human Forgery  |Human Original - AI Original   |1.86    |[0.61, 3.05]     |99.88% |Positive |
|MemoryConditionBelief |Human Original |Human Original - AI Original   |5.49    |[3.41, 7.60]     |100%   |Positive |
|MemoryConditionBelief |Human Original |Human Original - AI Copy       |5.00    |[2.92, 7.07]     |100%   |Positive |
|MemoryConditionBelief |Human Original |Human Forgery - AI Original    |3.37    |[0.73, 6.07]     |99.40% |Positive |
|MemoryConditionBelief |Human Original |Human Forgery - AI Copy        |2.89    |[0.27, 5.58]     |98.52% |Positive |

:::

:::
:::

