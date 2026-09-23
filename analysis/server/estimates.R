# Post-processing of one fitted model: diagnostics, marginal means, contrasts,
# marginal CHOCO parameters and reduced posterior-predictive draws. No output
# formatting. Run on the cluster by extract_model.R (get_estimates()) and
# sourced by 3_models.qmd / 4_memory.qmd for the registries and
# prep_contrasts(). Requires dplyr and modelbased attached; everything else is
# namespace-qualified.


# `%||%` is base only from R 4.4; the cluster runs R 4.3.2 and marginaleffects needs it.
if (!exists("%||%", envir = baseenv())) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}


# Registry ------------------------------------------------------------------
# 3_models.qmd outcomes. label/family/scale are printed; the rest drive get_estimates():
#   backend         emmeans (default) or marginaleffects (ordinal models)
#   range           scale width for the % conversion (NULL = already 0-1, NA = unbounded)
#   extra_contrast  a second contrast table over another factor
#   marginal        marginal CHOCO parameters for the density figures
#   marginal_emo    the same by Condition x Emotion
#   discrete        list(iterations=): predicted response-category proportions
#   density         list(iterations=, by=): per-draw predictive densities
#   individual      dpars for get_individual() (participant-level indices)
outcome_info <- list(
  Beauty = list(
    label = "Beauty", family = "CHOCO",
    scale = "analog slider rescaled to 0 (Ugly) - 1 (Beautiful)",
    marginal = TRUE, marginal_emo = TRUE,
    individual = c("mu", "confright", "confleft", "precright", "precleft")
  ),
  Beauty2 = list(
    label = "Beauty (follow-up)", family = "CHOCO",
    scale = "analog slider rescaled to 0 (Ugly) - 1 (Beautiful), rated again in the follow-up session after the debrief",
    marginal = TRUE
  ),
  Reality = list(
    label = "Syntheticness", family = "CHOCO",
    scale = "slider rescaled to 0 (AI-Generated) - 1 (Human Creation); higher = judged more human",
    marginal = TRUE,
    individual = c("mu", "confright", "confleft", "precright", "precleft")
  ),
  Authenticity = list(
    label = "Authenticity", family = "CHOCO",
    scale = "slider rescaled to 0 (Copy / Forgery) - 1 (Original Creation)",
    marginal = TRUE,
    individual = c("mu", "confright", "confleft", "precright", "precleft")
  ),
  Artificiality = list(
    label = "Perceived Artificiality", family = "CHOCO",
    scale = "slider rescaled to 0 (Very Human) - 1 (Very Artificial), follow-up, items judged 'new' only",
    marginal = TRUE
  ),
  Valence = list(
    label = "Valence", family = "Discrete Beta (k = 7)",
    scale = "7-point pictorial scale coded 1 (Negative) - 7 (Positive); `response` differences are reported in % of the 6-point range",
    range = 6, discrete = list(iterations = 100),
    individual = c("mu", "phi")
  ),
  Meaning = list(
    label = "Meaning", family = "Discrete Beta (k = 6) with zero hurdle",
    scale = "0 (Not at all) - 6 (Very much); `response` differences are reported in % of the 6-point range; `pzero` is the probability of answering exactly 0",
    range = 6, discrete = list(iterations = 100),
    individual = c("mu", "phi", "pzero")
  ),
  Worth = list(
    label = "Worth", family = "Cumulative (ordinal)",
    scale = "6 ordered categories $0, $10, $100, $1,000, $10,000, $100,000; `response - <k>` rows are differences in the probability of choosing category k",
    backend = "marginaleffects", discrete = list(iterations = 100),
    individual = c("mu", "disc")
  ),
  SelfRelevance = list(
    label = "Self-Relevance", family = "Cumulative (ordinal)",
    scale = "7 ordered categories 0 (Not at all) - 6 (Very much); `response - <k>` rows are differences in the probability of choosing category k",
    backend = "marginaleffects", discrete = list(iterations = 100)
  ),
  Entropy = list(
    label = "Gaze Entropy", family = "Beta",
    scale = "normalised spatial entropy of gaze in (0, 1); higher = more dispersed gaze",
    extra_contrast = "Emotion",
    density = list(iterations = 50, by = "Condition")
  ),
  pLeft = list(
    label = "Gaze Laterality (pLeft)", family = "Zero-one-inflated Beta",
    scale = "proportion of gaze samples on the left half of the image (0 - 1)",
    extra_contrast = "Emotion",
    density = list(iterations = 50, by = "Condition")
  ),
  pCenter = list(
    label = "Gaze Centeredness (pCenter)", family = "Zero-one-inflated Beta",
    scale = "proportion of gaze samples in the central region of the image (0 - 1)",
    extra_contrast = "Emotion",
    density = list(iterations = 50, by = "Condition")
  ),
  Shift = list(
    label = "Gaze Max. Shift", family = "LogNormal",
    scale = "largest within-trial relocation of the gaze centroid, in stimulus widths",
    range = NA, extra_contrast = "Emotion",
    density = list(iterations = 500, by = c("Condition", "Emotion"))
  )
)

# 4_memory.qmd categorical models. `by` = the factor contrasted and plotted.
memory_info <- list(
  MemoryCondition = list(
    label = "Memory of the Experimental Condition",
    family = "Categorical", by = "Condition"
  ),
  MemoryBelief = list(
    label = "Memory of Beliefs",
    family = "Categorical", by = "Belief"
  )
)

contrast_order <- c("AI-Generated - Human Original", "Human Forgery - Human Original", "AI-Generated - Human Forgery")

# Parameters reported in % (x100); `response` is x100/range unless range = NA.
pct_params <- c("mu", "confright", "confleft", "pex", "bex", "pmid", "pzero", "zoi", "coi")

get_scale_factor <- function(parameter, outcome) {
  info <- outcome_info[[outcome]]
  rng <- if (is.null(info$range)) 1 else info$range
  is_resp <- parameter == "response" | grepl("^response", parameter)
  ifelse(parameter %in% pct_params, 100,
    ifelse(is_resp & !is.na(rng), 100 / rng, NA_real_))
}


# Helpers -------------------------------------------------------------------

# estimate_*() results carry the whole fit (attr "model", "datagrid", formula
# environments); drop them, plus any attribute > 256 KB. See AGENT.md 4.7a.
strip_model <- function(x, max_attr_bytes = 262144) {
  for (n in intersect(names(attributes(x)), c("model", "datagrid"))) {
    attr(x, n) <- NULL
  }
  for (n in names(attributes(x))) {
    if (inherits(attr(x, n), "formula")) environment(attr(x, n)) <- baseenv()
  }
  structural <- c("names", "row.names", "class")
  for (n in setdiff(names(attributes(x)), structural)) {
    if (length(serialize(attr(x, n), NULL)) > max_attr_bytes) attr(x, n) <- NULL
  }
  x
}

# Explicit data so insight::get_data() does not search the calling environment.
model_data <- function(m) m$data


# Diagnostics ---------------------------------------------------------------

get_diagnostics <- function(m, outcome, family = NULL) {
  if (is.null(family)) family <- outcome_info[[outcome]]$family
  if (is.null(family)) family <- m$family$family
  rh <- brms::rhat(m)
  ne <- brms::neff_ratio(m)
  np <- brms::nuts_params(m, pars = "divergent__")
  data.frame(
    Model = outcome,
    Family = family,
    N_obs = nrow(m$data),
    N_participants = length(unique(m$data$Participant)),
    Chains = brms::nchains(m),
    Draws = brms::ndraws(m),
    Max_Rhat = round(max(rh, na.rm = TRUE), 3),
    Min_ESS_ratio = round(min(ne, na.rm = TRUE), 3),
    Divergent_pct = round(100 * mean(np$Value), 2),
    Criterion = paste(names(m$criteria), collapse = ", "),
    check.names = FALSE
  )
}

# Summary + convergence for every non-`r_` parameter.
get_convergence <- function(m) {
  vars <- brms::variables(m)
  keep <- vars[!startsWith(vars, "r_")]
  # Subset inside as_draws_array() to avoid materialising the `r_` columns
  d <- brms::as_draws_array(m, variable = keep)
  s <- posterior::summarise_draws(
    d,
    posterior::default_summary_measures(),
    posterior::default_convergence_measures()
  )
  as.data.frame(s)
}


# Marginal means ------------------------------------------------------------

get_means <- function(m) {
  if (m$family$family == "cumulative") {
    # Ordinal: probability of each category per condition
    out <- estimate_means(m, by = "Condition", predict = "response", backend = "marginaleffects",
                          test = NULL, iterations = 500) |>
      strip_model() |>
      as.data.frame()
  } else {
    out <- estimate_means(m, by = "Condition", predict = "response", backend = "emmeans", test = NULL) |>
      strip_model() |>
      as.data.frame()
  }
  names(out)[names(out) %in% c("Probability", "Mean", "Median")] <- "Estimate"
  out[intersect(c("Condition", "Response", "Estimate", "CI_low", "CI_high"), names(out))]
}


# Contrasts -----------------------------------------------------------------

get_contrasts <- function(m, outcome = "Beauty", contrast = "Condition", by = NULL, backend = "emmeans") {
  dat_con <- data.frame()

  params <- c("response", "mu", insight::find_auxiliary(m))
  if (outcome %in% c("Worth", "SelfRelevance")) params <- params[!params %in% c("disc")]
  if (outcome %in% c("pLeft", "pCenter")) params <- params[!params %in% c("zoi", "coi")]
  for (par in params) {
    if (!is.null(by) && par %in% c("pmid", "pex", "bex", "disc")) next

    c <- estimate_contrasts(m, contrast = contrast, by = by, predict = par,
                            backend = backend, test = "pd", iterations = 500) |>
      strip_model()

    if (outcome %in% c("Worth", "SelfRelevance") && par == "response") {
      c <- filter(c, Response1 == Response2)
      c <- mutate(c, Parameter = paste0("response - ", Response1))
      c <- datawizard::data_remove(c, c("Response1", "Response2"))
    } else {
      c <- mutate(c, Parameter = par)
    }

    dat_con <- rbind(dat_con, c)
  }

  if (backend == "marginaleffects") dat_con <- datawizard::data_rename(dat_con, select = "Median", "Difference")
  dat_con$Outcome <- outcome
  # Some backends parenthesise level labels
  unparen <- function(x) sub("\\)", "", sub("\\(", "", x))
  dat_con$Contrast <- paste(unparen(dat_con$Level1), "-", unparen(dat_con$Level2))

  rez_con <- filter(dat_con, sign(CI_low) == sign(CI_high))
  if (nrow(rez_con) == 0) {
    rez_con <- data.frame(Contrast = unique(dat_con$Contrast), Parameters = "None")
  } else {
    rez_con <- rez_con |>
      insight::format_table(zap_small = TRUE) |>
      mutate(param_string = paste0(Parameter, " (", Difference, ", ", CI, ")")) |>
      summarise(Parameters = paste(param_string, collapse = "; "), .by = "Contrast")
  }

  list(rez_con = rez_con, dat_con = dat_con)
}

# Derived columns the report prints (Credible, Effect, % scaling, formatted strings).
# Also re-run by the notebook on stored contrasts.
prep_contrasts <- function(dat_con, outcome) {
  dat_con <- as.data.frame(dat_con)
  dat_con$Credible <- sign(dat_con$CI_low) == sign(dat_con$CI_high)
  dat_con$Effect <- ifelse(!dat_con$Credible, "n.s.", ifelse(dat_con$Difference < 0, "Negative", "Positive"))
  dat_con$Contrast <- factor(dat_con$Contrast, levels = unique(c(contrast_order, unique(dat_con$Contrast))))
  # Percent of scale range where the parameter has one (see get_scale_factor)
  k <- get_scale_factor(dat_con$Parameter, outcome)
  dat_con$Unit <- ifelse(is.na(k), "raw", "%")
  dat_con$Difference_pct <- dat_con$Difference * k
  dat_con$CI_low_pct <- dat_con$CI_low * k
  dat_con$CI_high_pct <- dat_con$CI_high * k
  shown <- function(raw, pct) ifelse(is.na(k), raw, pct)
  d <- shown(dat_con$Difference, dat_con$Difference_pct)
  lo <- shown(dat_con$CI_low, dat_con$CI_low_pct)
  hi <- shown(dat_con$CI_high, dat_con$CI_high_pct)
  dat_con$Diff <- insight::format_value(d, zap_small = TRUE)
  dat_con$CI <- sprintf("[%s, %s]", insight::format_value(lo, zap_small = TRUE), insight::format_value(hi, zap_small = TRUE))
  dat_con$pd_fmt <- if ("pd" %in% names(dat_con)) insight::format_pd(dat_con$pd, name = NULL) else ""
  dat_con[order(dat_con$Contrast), ]
}


# Marginal CHOCO parameters -------------------------------------------------
# The notebook evaluates dcogmod_choco() on these (get_marginal_densities()).

get_marginal_parameters <- function(m, by = "Condition") {
  dat_par <- estimate_means(m, by = by, predict = "response", backend = "emmeans", test = NULL) |>
    strip_model() |>
    datawizard::data_rename(
      select = c("Probability", "CI_low", "CI_high"),
      replacement = c("Mean", "Mean_low", "Mean_high")
    )

  for (par in c("mu", "confright", "confleft", "precright", "precleft", "pex", "bex", "pmid")) {
    if (par %in% c("pex", "bex", "pmid")) by <- "Condition" # not modelled by Emotion
    dat_par <- estimate_means(m, by = by, predict = par, backend = "emmeans", test = NULL) |>
      strip_model() |>
      datawizard::data_rename(
        select = c("CI_low", "CI_high"),
        replacement = paste0(tools::toTitleCase(par), c("_low", "_high"))
      ) |>
      full_join(dat_par, by = by)
  }
  dat_par
}


# Reductions of the posterior-predictive draws ------------------------------
# The full keep_iterations object is up to ~150 MB; only these summaries travel.

# Proportion of predicted responses per category, summarised across draws.
get_discrete_summary <- function(pred, by = "Condition") {
  bayestestR::reshape_iterations(pred) |>
    summarize(N = n(), .by = all_of(c(by, "iter_group", "iter_value"))) |>
    mutate(p = N / sum(N), .by = all_of(c(by, "iter_group"))) |>
    summarise(
      median = median(p),
      lower = quantile(p, .025),
      upper = quantile(p, .975),
      .by = all_of(c(by, "iter_value"))
    )
}

# One kernel density per draw (same as ggplot's stat_density, bw.nrd0).
get_density_curves <- function(pred, by = "Condition", n = 200) {
  long <- bayestestR::reshape_iterations(pred)
  grp <- c(by, "iter_group")
  keys <- long[grp]
  split(seq_len(nrow(long)), keys, drop = TRUE) |>
    lapply(function(i) {
      v <- long$iter_value[i]
      v <- v[is.finite(v)]
      if (length(v) < 2) return(NULL)
      d <- stats::density(v, bw = "nrd0", n = n)
      cbind(keys[i[1], , drop = FALSE], data.frame(x = d$x, y = d$y), row.names = NULL)
    }) |>
    bind_rows()
}


# Report --------------------------------------------------------------------

get_report <- function(est) {
  list(
    outcome = est$outcome,
    extra_title = "contrasts between stimulus emotion quadrants",
    diag = est$diag,
    means = est$means,
    contrasts = prep_contrasts(est$contrasts, est$outcome),
    contrasts_emo = prep_contrasts(est$contrasts_emo, est$outcome),
    contrasts_extra = if (!is.null(est$contrasts_extra)) prep_contrasts(est$contrasts_extra, est$outcome) else NULL
  )
}


# Driver (called by extract_model.R) -----------------------------------------

get_estimates <- function(m, outcome, verbose = TRUE) {
  if (!is.null(memory_info[[outcome]])) {
    return(get_memory_estimates(m, outcome, verbose = verbose))
  }
  info <- outcome_info[[outcome]]
  if (is.null(info)) {
    stop("no registry entry for '", outcome, "' -- add one to outcome_info ",
         "(a 3_models.qmd outcome) or memory_info (a 4_memory.qmd model) ",
         "in estimates.R before extracting it", call. = FALSE)
  }
  backend <- if (is.null(info$backend)) "emmeans" else info$backend
  step <- function(what) if (verbose) cat("**", outcome, "-", what, ":", format(Sys.time()), "\n")

  est <- list(
    outcome = outcome,
    label = info$label,
    family = info$family,
    created = Sys.time(),
    ndraws = brms::ndraws(m),
    nchains = brms::nchains(m)
  )

  step("diagnostics")
  est$diag <- get_diagnostics(m, outcome)
  est$convergence <- get_convergence(m)

  step("marginal means")
  est$means <- get_means(m)

  # $*_credible: one-line digest of the credible contrasts
  step("contrasts (Condition)")
  rez <- get_contrasts(m, outcome, contrast = "Condition", backend = backend)
  est$contrasts <- rez$dat_con
  est$contrasts_credible <- rez$rez_con

  step("contrasts (Condition | Emotion)")
  est$contrasts_emo <- get_contrasts(m, outcome, contrast = "Condition", by = "Emotion", backend = backend)$dat_con

  if (!is.null(info$extra_contrast)) {
    step(paste0("contrasts (", info$extra_contrast, ")"))
    rez2 <- get_contrasts(m, outcome, contrast = info$extra_contrast, backend = backend)
    est$contrasts_extra <- rez2$dat_con
    est$contrasts_extra_credible <- rez2$rez_con
  }

  if (isTRUE(info$marginal)) {
    step("marginal parameters")
    est$marginal <- get_marginal_parameters(m)
  }
  if (isTRUE(info$marginal_emo)) {
    step("marginal parameters (Condition x Emotion)")
    est$marginal_emo <- get_marginal_parameters(m, by = c("Condition", "Emotion"))
  }

  if (!is.null(info$discrete)) {
    step("posterior predictions (discrete)")
    pred <- estimate_prediction(m, data = model_data(m), ci = NULL,
                                iterations = info$discrete$iterations,
                                keep_iterations = TRUE, centrality = "median") |>
      strip_model()
    est$discrete <- get_discrete_summary(pred, by = "Condition")
    est$discrete_emo <- get_discrete_summary(pred, by = c("Condition", "Emotion"))
    rm(pred)
  }

  if (!is.null(info$density)) {
    step("posterior predictions (densities)")
    pred <- estimate_prediction(m, data = model_data(m), ci = NULL,
                                iterations = info$density$iterations,
                                keep_iterations = TRUE) |>
      strip_model()
    est$density <- get_density_curves(pred, by = info$density$by)
    rm(pred)
  }

  step("report")
  est$report <- get_report(est)
  est
}


# Driver: the memory models --------------------------------------------------
# modelbased defaults (backend included), as in the original notebook.

get_memory_estimates <- function(m, outcome, verbose = TRUE) {
  info <- memory_info[[outcome]]
  step <- function(what) if (verbose) cat("**", outcome, "-", what, ":", format(Sys.time()), "\n")

  est <- list(
    outcome = outcome,
    label = info$label,
    family = info$family,
    by = info$by,
    created = Sys.time(),
    ndraws = brms::ndraws(m),
    nchains = brms::nchains(m)
  )

  step("diagnostics")
  est$diag <- get_diagnostics(m, outcome, family = info$family)
  est$convergence <- get_convergence(m)

  step(paste0("marginal means (", info$by, ")"))
  est$means <- as.data.frame(strip_model(estimate_means(m, by = info$by)))

  step(paste0("contrasts (", info$by, ")"))
  est$contrasts <- as.data.frame(strip_model(
    estimate_contrasts(m, contrast = info$by, test = "pd")
  ))

  est
}


# Participant-level indices ---------------------------------------------------
# For each participant and dpar, on the link scale, averaged over Emotion, with
# item effects excluded (items are assigned to conditions per participant):
#   Baseline  Human Original
#   Forgery   Human Forgery - Human Original
#   AI        AI-Generated  - Human Original
# A dpar whose participant term has no Condition slope (e.g. Worth's `disc`)
# gets a Baseline only. Returns the posterior Mean and SD of each index, and
# SD_rel: the SD of the index relative to the sample mean of the same draw,
# i.e. without the uncertainty of the population effect shared by all
# participants.

# The `( ... | Participant)` term of a dpar's formula, as a re_formula.
participant_term <- function(m, dpar) {
  f <- if (dpar == "mu") m$formula$formula else m$formula$pforms[[dpar]]
  f <- paste(deparse(f), collapse = " ")
  term <- regmatches(f, regexpr("\\([^()]*\\|\\s*Participant\\s*\\)", f))
  if (length(term) == 0) stop("no participant term for dpar '", dpar, "'", call. = FALSE)
  stats::as.formula(paste("~", term))
}

get_individual <- function(m, outcome, verbose = TRUE) {
  if (!is.null(memory_info[[outcome]])) return(get_memory_individual(m, outcome, verbose))
  params <- outcome_info[[outcome]]$individual
  if (is.null(params)) {
    stop("no `individual` dpars for '", outcome, "' in outcome_info", call. = FALSE)
  }
  step <- function(what) if (verbose) cat("**", outcome, "-", what, ":", format(Sys.time()), "\n")

  d <- m$data
  grid <- expand.grid(
    Participant = sort(unique(as.character(d$Participant))),
    Condition = levels(factor(d$Condition)),
    Emotion = levels(factor(d$Emotion)),
    stringsAsFactors = FALSE
  )
  participants <- unique(grid$Participant)
  # Columns of the prediction matrix per condition, one block per emotion,
  # participants in the same order within each block.
  blocks <- lapply(split(seq_len(nrow(grid)), grid$Condition), function(i) split(i, grid$Emotion[i]))

  rez <- lapply(params, function(p) {
    step(p)
    re <- participant_term(m, p)
    eta <- brms::posterior_linpred(m, newdata = grid, dpar = p, transform = FALSE, re_formula = re)
    cond <- lapply(blocks, function(b) Reduce(`+`, lapply(b, function(j) eta[, j, drop = FALSE])) / length(b))
    base <- cond[["Human Original"]]
    idx <- list(Baseline = base)
    if (grepl("Condition", deparse(re))) {
      idx$Forgery <- cond[["Human Forgery"]] - base
      idx$AI <- cond[["AI-Generated"]] - base
    }
    bind_rows(lapply(names(idx), function(k) data.frame(
      Participant = participants, Parameter = p, Index = k,
      Mean = colMeans(idx[[k]]),
      SD = apply(idx[[k]], 2, stats::sd),
      SD_rel = apply(idx[[k]] - rowMeans(idx[[k]]), 2, stats::sd)
    )))
  })

  list(
    outcome = outcome,
    created = Sys.time(),
    ndraws = brms::ndraws(m),
    individual = bind_rows(rez)
  )
}


# Memory models: participant-level recognition, accuracy and response
# tendencies from the predicted answer probabilities (item effects excluded),
# on the logit scale. Accuracy and tendencies are conditional on recognition:
#   Recognition  Hits (old items recognised), False alarms (new items "seen")
#   Accuracy     Correct: P(recalled answer = actual level), averaged over levels
#   Tendency     P(answer = k), averaged over the actual levels

get_memory_individual <- function(m, outcome, verbose = TRUE) {
  by <- memory_info[[outcome]]$by
  d <- m$data
  levels_by <- levels(factor(d[[by]]))
  grid <- expand.grid(Participant = sort(unique(as.character(d$Participant))),
                      Level = levels_by, stringsAsFactors = FALSE)
  names(grid)[2] <- by
  participants <- unique(grid$Participant)

  if (verbose) cat("**", outcome, "- predictions :", format(Sys.time()), "\n")
  p <- brms::posterior_epred(m, newdata = grid, re_formula = participant_term(m, "mu"))
  P <- function(level, answer) p[, grid[[by]] == level, answer] # draws x participants

  old <- setdiff(levels_by, c("New Items", "None"))
  answers <- setdiff(dimnames(p)[[3]], "Not recognized")
  recognised <- lapply(setNames(nm = old), function(l) 1 - P(l, "Not recognized"))
  given_recognised <- function(l, a) P(l, a) / recognised[[l]]
  average <- function(x) Reduce(`+`, x) / length(x)

  idx <- list()
  if ("New Items" %in% levels_by) {
    idx[["Recognition_Hits"]] <- average(recognised)
    idx[["Recognition_False alarms"]] <- 1 - P("New Items", "Not recognized")
  }
  idx[["Accuracy_Correct"]] <- average(lapply(intersect(old, answers), function(l) given_recognised(l, l)))
  for (a in answers) idx[[paste0("Tendency_", a)]] <- average(lapply(old, function(l) given_recognised(l, a)))

  logit <- function(x) stats::qlogis(pmin(pmax(x, 1e-6), 1 - 1e-6))
  rez <- bind_rows(lapply(names(idx), function(k) {
    x <- logit(idx[[k]])
    data.frame(Participant = participants, Parameter = sub("_.*", "", k), Index = sub("^[^_]*_", "", k),
               Mean = colMeans(x), SD = apply(x, 2, stats::sd),
               SD_rel = apply(x - rowMeans(x), 2, stats::sd))
  }))

  list(outcome = outcome, created = Sys.time(), ndraws = brms::ndraws(m), individual = rez)
}
