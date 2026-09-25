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
  ),
  # Recalled label by own Phase-2 belief, averaged over the label shown.
  # estimate = "observed": see memory_observed() -- modelbased's "typical"
  # grid crosses every participant x item x Belief x Condition (127k rows x 4
  # answers x 4000 draws) and ran out of 128 GB on 2026-09-23 (job 11407268).
  MemoryConditionBelief = list(
    label = "Memory of the Condition by Belief",
    family = "Categorical", by = "Belief", estimate = "observed"
  )
)

# Determinants of reality beliefs: belief ~ Condition * <mediator>. `grid` is
# where the population-level predictions are evaluated: coarse over the whole
# range (for the figure), fine around 0 where the per-condition means of the
# centred mediator sit (for mediation_effects()).
mediation_grid <- sort(unique(round(c(seq(-0.6, 0.6, by = 0.05), seq(-0.12, 0.12, by = 0.005)), 3)))
# ...plus pairs of points 0.01 apart around +/-0.2 and +/-0.4 (about 1 and 2 SD
# of Beauty_w), for grid_slopes(at = ) on a model whose slope is not constant
mediation_grid_quad <- sort(unique(round(c(mediation_grid, outer(c(-0.4, -0.2, 0.2, 0.4), c(-0.005, 0.005), "+")), 3)))
mediation_info <- list(
  # individual: dpars whose participant-level mediator slope 7_correlates.qmd
  # uses (get_mediation_individual(), `./hpc individual RealityBeauty`)
  RealityBeauty = list(
    label = "Syntheticness by Phase-1 Beauty", family = "CHOCO",
    outcome = "Reality", mediator = "Beauty_w", grid = mediation_grid,
    dpars = c("mu", "confright", "confleft"), individual = "mu"
  ),
  AuthenticityBeauty = list(
    label = "Authenticity by Phase-1 Beauty", family = "CHOCO",
    outcome = "Authenticity", mediator = "Beauty_w", grid = mediation_grid,
    dpars = c("mu", "confright", "confleft")
  ),
  # Shape check (models.R): AuthenticityBeauty with a quadratic Beauty_w term.
  # The grid predictions carry the curvature; grid_slopes(at = ) gives the
  # slope below / at / above the participant's mean beauty. Read by its own
  # section of 5_realitydeterminants.qmd (shape_models, below).
  AuthenticityBeautyQuad = list(
    label = "Authenticity by Phase-1 Beauty (quadratic)", family = "CHOCO",
    outcome = "Authenticity", mediator = "Beauty_w", grid = mediation_grid_quad,
    dpars = c("mu", "confright", "confleft")
  ),
  # Robustness: + label-free follow-up beauty, held at 0 (its participant
  # mean) in every prediction; its own slope is extracted as a covariate slope.
  RealityBeautyControl = list(
    label = "Syntheticness by Phase-1 Beauty, controlling follow-up Beauty", family = "CHOCO",
    outcome = "Reality", mediator = "Beauty_w", grid = mediation_grid,
    dpars = c("mu", "confright", "confleft"), covariates = c(Beauty2_w = 0)
  ),
  AuthenticityBeautyControl = list(
    label = "Authenticity by Phase-1 Beauty, controlling follow-up Beauty", family = "CHOCO",
    outcome = "Authenticity", mediator = "Beauty_w", grid = mediation_grid,
    dpars = c("mu", "confright", "confleft"), covariates = c(Beauty2_w = 0)
  ),
  # Not a mediation: the same grid machinery with `by` = Type (Old / New
  # items), for the slope of artificiality on follow-up beauty per Type
  # (grid_slopes()); mediation_effects() does not apply.
  ArtificialityBeauty = list(
    label = "Perceived Artificiality by follow-up Beauty", family = "CHOCO",
    outcome = "PerceivedArtificiality", mediator = "Beauty2_w", by = "Type",
    grid = mediation_grid, dpars = c("mu", "confright", "confleft")
  ),
  # Self-relevance as a moderator (6_selfrelevance.qmd; models.R, BeautySR,
  # ...). Not mediations -- the label does not move SR, so mediation_effects()
  # does not apply -- but the same grid over SR_w per label, which
  # moderation_effects() turns into the label contrast at low / average / high
  # SR and the SR slope per label. Beauty2_w, where present, is held at 0 and
  # its own slopes come from covariate_slopes(). `outcome` is the rating, for
  # the % scaling (Meaning: range 6).
  BeautySR = list(
    label = "Phase-1 Beauty by Self-Relevance", family = "CHOCO",
    outcome = "Beauty", mediator = "SR_w", grid = mediation_grid,
    dpars = c("mu", "confright", "confleft")
  ),
  BeautySRControl = list(
    label = "Phase-1 Beauty by Self-Relevance, controlling follow-up Beauty", family = "CHOCO",
    outcome = "Beauty", mediator = "SR_w", grid = mediation_grid,
    dpars = c("mu", "confright", "confleft"), covariates = c(Beauty2_w = 0)
  ),
  # Within + between persons: SR_w on the grid, the participant's mean SR
  # (SR_b, centred) held at 0 and extracted as a covariate slope, whose
  # differences between labels (covariate_slopes(pairs = TRUE)) are the
  # between-person moderation of the label gap.
  BeautySRBetween = list(
    label = "Phase-1 Beauty by within- and between-person Self-Relevance", family = "CHOCO",
    outcome = "Beauty", mediator = "SR_w", grid = mediation_grid,
    dpars = c("mu", "confright", "confleft"), covariates = c(SR_b = 0)
  ),
  MeaningSR = list(
    label = "Phase-1 Meaning by Self-Relevance", family = "Discrete Beta (k = 6) with zero hurdle",
    outcome = "Meaning", mediator = "SR_w", grid = mediation_grid,
    dpars = c("mu", "pzero")
  ),
  # Items judged new, by Type (as ArtificialityBeauty), with SR on the grid
  # and follow-up beauty as the covariate: grid_slopes() / covariate_slopes().
  ArtificialitySR = list(
    label = "Perceived Artificiality by Self-Relevance and follow-up Beauty", family = "CHOCO",
    outcome = "PerceivedArtificiality", mediator = "SR_w", by = "Type",
    grid = mediation_grid, dpars = c("mu", "confright", "confleft"), covariates = c(Beauty2_w = 0)
  )
)

# Joint appraisal mediators (models.R, RealityAppraisal / AuthenticityAppraisal):
# get_appraisal_estimates() / appraisal_effects().
appraisal_info <- list(
  RealityAppraisal = list(
    label = "Syntheticness by Phase-1 appraisal", family = "CHOCO", outcome = "Reality",
    mediators = c("Beauty_w", "Valence_w", "Meaning_w", "Worth_w"), dpars = c("mu", "confright", "confleft")
  ),
  AuthenticityAppraisal = list(
    label = "Authenticity by Phase-1 appraisal", family = "CHOCO", outcome = "Authenticity",
    mediators = c("Beauty_w", "Valence_w", "Meaning_w", "Worth_w"), dpars = c("mu", "confright", "confleft")
  ),
  # Self-relevance and reality beliefs (models.R, RealitySR / AuthenticitySR):
  # Phase-1 beauty, SR and follow-up beauty as joint predictors. The `cues`
  # give each one's slope under each label; SR and Beauty2 are label-free, so
  # their indirect effects should be ~0 and the Beauty_w decomposition is the
  # RealityBeautyControl one with SR added.
  RealitySR = list(
    label = "Syntheticness by Phase-1 Beauty, Self-Relevance and follow-up Beauty", family = "CHOCO",
    outcome = "Reality", mediators = c("Beauty_w", "SR_w", "Beauty2_w"), dpars = c("mu", "confright", "confleft")
  ),
  AuthenticitySR = list(
    label = "Authenticity by Phase-1 Beauty, Self-Relevance and follow-up Beauty", family = "CHOCO",
    outcome = "Authenticity", mediators = c("Beauty_w", "SR_w", "Beauty2_w"), dpars = c("mu", "confright", "confleft")
  )
)

# The self-relevance entries of mediation_info / appraisal_info: read by
# 6_selfrelevance.qmd, left out by 5_realitydeterminants.qmd.
sr_models <- c("BeautySR", "BeautySRControl", "BeautySRBetween", "MeaningSR", "RealitySR", "AuthenticitySR", "ArtificialitySR")
# Shape checks (2026-09-24): left out of 5_realitydeterminants.qmd's main
# registries and read, when extracted, by its "Exploratory checks" section.
shape_models <- c("AuthenticityBeautyQuad")

# Categorical memory models with continuous predictors (models.R,
# MemoryAppraisal): answer probabilities over a grid of each predictor
# (get_memory_grid_estimates()), read by 4_memory.qmd, "Memory by Phase-1
# Appraisal". Kept out of memory_info, whose models 4_memory.qmd tabulates
# together. `predictors`: the centred ratings, each with a quadratic term.
memory_grid_info <- list(
  MemoryAppraisal = list(
    label = "Memory by Phase-1 Beauty and Valence", family = "Categorical",
    predictors = c("Beauty_w", "Valence_w")
  )
)

# Item-level determinants (models.R, RealityItems / AuthenticityItems):
# get_items_estimates().
items_info <- list(
  RealityItems = list(
    label = "Syntheticness by item properties", family = "CHOCO", outcome = "Reality",
    norms = c("Norms_Liking_z", "Norms_Valence_z", "Norms_Arousal_z", "Norms_Complexity_z", "Norms_Familiarity_z"),
    dpars = c("mu", "confright", "confleft")
  ),
  AuthenticityItems = list(
    label = "Authenticity by item properties", family = "CHOCO", outcome = "Authenticity",
    norms = c("Norms_Liking_z", "Norms_Valence_z", "Norms_Arousal_z", "Norms_Complexity_z", "Norms_Familiarity_z"),
    dpars = c("mu", "confright", "confleft")
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

get_means <- function(m, by = "Condition") {
  if (m$family$family == "cumulative") {
    # Ordinal: probability of each category per condition
    out <- estimate_means(m, by = by, predict = "response", backend = "marginaleffects",
                          test = NULL, iterations = 500) |>
      strip_model() |>
      as.data.frame()
  } else {
    out <- estimate_means(m, by = by, predict = "response", backend = "emmeans", test = NULL) |>
      strip_model() |>
      as.data.frame()
  }
  names(out)[names(out) %in% c("Probability", "Mean", "Median")] <- "Estimate"
  out[intersect(c(by, "Response", "Estimate", "CI_low", "CI_high"), names(out))]
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
  if (!is.null(memory_grid_info[[outcome]])) {
    return(get_memory_grid_estimates(m, outcome, verbose = verbose))
  }
  if (!is.null(mediation_info[[outcome]])) {
    return(get_mediation_estimates(m, outcome, verbose = verbose))
  }
  if (!is.null(appraisal_info[[outcome]])) {
    return(get_appraisal_estimates(m, outcome, verbose = verbose))
  }
  if (!is.null(items_info[[outcome]])) {
    return(get_items_estimates(m, outcome, verbose = verbose))
  }
  info <- outcome_info[[outcome]]
  if (is.null(info)) {
    stop("no registry entry for '", outcome, "' -- add one to outcome_info ",
         "(a 3_models.qmd outcome), memory_info / memory_grid_info (a 4_memory.qmd model), mediation_info, appraisal_info or items_info ",
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

  if (identical(info$estimate, "observed")) {
    step(paste0("marginal means and contrasts over the observed trials (", info$by, ")"))
    est <- c(est, memory_observed(m, info$by))
    return(est)
  }

  step(paste0("marginal means (", info$by, ")"))
  est$means <- as.data.frame(strip_model(estimate_means(m, by = info$by)))

  step(paste0("contrasts (", info$by, ")"))
  est$contrasts <- as.data.frame(strip_model(
    estimate_contrasts(m, contrast = info$by, test = "pd")
  ))

  est
}

# Marginal means of a categorical model as counterfactual averages over the
# observed trials: every row of the model's data with `by` set to each level
# in turn, participant and item effects included, averaged per draw. The same
# quantity as the "typical" grid (which averages over every participant x
# item combination) at a fraction of the memory: one level is
# rows x answers x draws (10,416 x 4 x 4,000 = 1.3 GB), reduced at once.
# Returns what get_memory_estimates() returns otherwise -- `means` (one row per
# level x answer) and `contrasts` (every pair of level x answer cells), with
# Median, 95% ETI and pd -- plus `draws` (draws x levels x answers).
memory_observed <- function(m, by) {
  d <- m$data
  lv <- levels(factor(d[[by]]))
  draws <- lapply(setNames(nm = lv), function(l) {
    nd <- d
    nd[[by]] <- factor(l, levels = lv)
    p <- brms::posterior_epred(m, newdata = nd) # draws x rows x answers
    apply(p, c(1, 3), mean)
  })
  answers <- colnames(draws[[1]])
  D <- array(unlist(draws), dim = c(nrow(draws[[1]]), length(answers), length(lv)),
             dimnames = list(NULL, answers, lv))
  D <- aperm(D, c(1, 3, 2)) # draws x levels x answers

  describe <- function(x) {
    c(Median = stats::median(x), CI_low = unname(stats::quantile(x, 0.025)),
      CI_high = unname(stats::quantile(x, 0.975)), pd = as.numeric(bayestestR::p_direction(x)))
  }
  cells <- expand.grid(Level = lv, Response = answers, stringsAsFactors = FALSE)
  means <- cbind(cells, t(vapply(seq_len(nrow(cells)), function(i) {
    describe(D[, cells$Level[i], cells$Response[i]])
  }, numeric(4))))
  names(means)[1] <- by
  means[[by]] <- factor(means[[by]], levels = lv)
  means$Response <- factor(means$Response, levels = answers)

  pairs <- utils::combn(nrow(cells), 2)
  contrasts <- do.call(rbind, lapply(seq_len(ncol(pairs)), function(k) {
    i <- pairs[1, k]
    j <- pairs[2, k]
    x <- D[, cells$Level[i], cells$Response[i]] - D[, cells$Level[j], cells$Response[j]]
    data.frame(Level1 = cells$Level[i], Response1 = cells$Response[i],
               Level2 = cells$Level[j], Response2 = cells$Response[j], t(describe(x)))
  }))

  list(means = means, contrasts = contrasts, draws = D)
}

# Categorical memory models with continuous predictors (memory_grid_info,
# MemoryAppraisal). Population-level (re_formula = NA) answer probabilities,
# averaged over the labels shown, over a grid of each predictor:
#   unique  that predictor moves, the others stay at 0 (the participant's mean)
#   joint   the others follow it along their within-person regression on it
#           (the ratings' typical co-variation: a work rated more beautiful is
#           usually rated more positive too)
# Grid: -0.6..0.6 by 0.05, plus -2 / -1 / +1 / +2 SD of the predictor over
# trials (`At`). Also the fixed effects (median, 95% HDI, pd), the predictors'
# SDs and the joint-path slopes. memory_grid_effects() turns `draws` (draws x
# grid rows x answers) into recognition and answers-given-recognition.
get_memory_grid_estimates <- function(m, outcome, verbose = TRUE) {
  info <- memory_grid_info[[outcome]]
  preds <- info$predictors
  step <- function(what) if (verbose) cat("**", outcome, "-", what, ":", format(Sys.time()), "\n")

  est <- list(outcome = outcome, label = info$label, family = info$family,
              predictors = preds, created = Sys.time(),
              ndraws = brms::ndraws(m), nchains = brms::nchains(m))

  step("diagnostics")
  est$diag <- get_diagnostics(m, outcome, family = info$family)
  est$convergence <- get_convergence(m)

  step("fixed effects")
  b <- as.data.frame(brms::as_draws_df(m, variable = "^b_", regex = TRUE))
  b <- b[grepl("^b_", names(b))]
  est$fixed <- do.call(rbind, lapply(names(b), function(v) {
    ci <- bayestestR::hdi(b[[v]], ci = 0.95)
    data.frame(Parameter = v, Median = stats::median(b[[v]]), CI_low = ci$CI_low,
               CI_high = ci$CI_high, pd = as.numeric(bayestestR::p_direction(b[[v]])))
  }))

  step("predictions over the predictor grid")
  d <- model_data(m)
  sds <- vapply(setNames(nm = preds), function(p) stats::sd(d[[p]]), numeric(1))
  # joint[a, b]: within-person slope of rating b on rating a (both centred)
  joint <- outer(preds, preds, Vectorize(function(a, b) {
    if (a == b) 1 else unname(stats::coef(stats::lm(d[[b]] ~ 0 + d[[a]])))
  }))
  dimnames(joint) <- list(preds, preds)
  rows <- list()
  for (p in preds) for (type in c("unique", "joint")) {
    sd_pts <- c(-2, -1, 1, 2) * sds[[p]]
    x <- sort(unique(c(round(seq(-0.6, 0.6, by = 0.05), 3), sd_pts)))
    r <- data.frame(Type = type, Predictor = p, x = x,
                    At = ifelse(x == 0, "Mean", NA_character_))
    r$At[match(sd_pts, x)] <- c("-2 SD", "-1 SD", "+1 SD", "+2 SD")
    for (o in preds) r[[o]] <- if (o == p) x else if (type == "joint") joint[p, o] * x else 0
    rows[[length(rows) + 1]] <- r
  }
  base <- do.call(rbind, rows)
  lv <- levels(d$Condition)
  nd <- base[rep(seq_len(nrow(base)), each = length(lv)), preds, drop = FALSE]
  nd$Condition <- factor(rep(lv, times = nrow(base)), levels = lv)
  p <- brms::posterior_epred(m, newdata = nd, re_formula = NA) # draws x rows x answers
  idx <- rep(seq_len(nrow(base)), each = length(lv))
  D <- array(NA_real_, dim = c(dim(p)[1], nrow(base), dim(p)[3]),
             dimnames = list(NULL, NULL, dimnames(p)[[3]]))
  for (i in seq_len(nrow(base))) D[, i, ] <- apply(p[, idx == i, , drop = FALSE], c(1, 3), mean)

  est$grid <- base
  est$draws <- D
  est$sd <- sds
  est$joint <- joint
  est
}

# From get_memory_grid_estimates(): per predictor and path (unique / joint),
#   curves   median and 95% HDI along the grid of P(recognised) and of each
#            answer given recognition, in %
#   effects  the same at -2 / -1 / +1 / +2 SD minus at the mean, and
#            "Extremity" = the average of -2 SD and +2 SD minus the mean
#            (> 0: both extremes above the mean, a U), "Asymmetry" = +2 SD
#            minus -2 SD; percentage points
memory_grid_effects <- function(est) {
  g <- est$grid
  D <- est$draws
  answers <- setdiff(dimnames(D)[[3]], "Not recognized")
  rec <- 1 - D[, , "Not recognized"]
  outs <- c(list(Recognised = rec), lapply(setNames(nm = answers), function(a) D[, , a] / rec))
  describe <- function(x) {
    ci <- bayestestR::hdi(x, ci = 0.95)
    data.frame(Median = stats::median(x), CI_low = ci$CI_low, CI_high = ci$CI_high,
               pd = as.numeric(bayestestR::p_direction(x)))
  }
  what <- function(k) if (k == "Recognised") "P(recognised)" else paste0("P(", k, " | recognised)")
  curves <- do.call(rbind, lapply(names(outs), function(k) {
    X <- 100 * outs[[k]]
    ci <- apply(X, 2, function(x) unlist(bayestestR::hdi(x, ci = 0.95)[c("CI_low", "CI_high")]))
    cbind(g[c("Type", "Predictor", "x", "At")], Outcome = what(k),
          Median = apply(X, 2, stats::median), CI_low = ci[1, ], CI_high = ci[2, ])
  }))
  effects <- do.call(rbind, lapply(names(outs), function(k) {
    X <- 100 * outs[[k]]
    do.call(rbind, lapply(split(seq_len(nrow(g)), paste(g$Type, g$Predictor)), function(i) {
      col <- function(a) X[, i[which(g$At[i] == a)]]
      diffs <- list(`-2 SD` = col("-2 SD") - col("Mean"), `-1 SD` = col("-1 SD") - col("Mean"),
                    `+1 SD` = col("+1 SD") - col("Mean"), `+2 SD` = col("+2 SD") - col("Mean"),
                    Extremity = (col("-2 SD") + col("+2 SD")) / 2 - col("Mean"),
                    Asymmetry = col("+2 SD") - col("-2 SD"))
      do.call(rbind, lapply(names(diffs), function(e) {
        cbind(Type = g$Type[i[1]], Predictor = g$Predictor[i[1]], Outcome = what(k), Effect = e, describe(diffs[[e]]))
      }))
    }))
  }))
  rownames(curves) <- rownames(effects) <- NULL
  list(curves = curves, effects = effects)
}



# Determinants of reality beliefs -------------------------------------------
# Belief ~ Condition * mediator (models.R, RealityBeauty / AuthenticityBeauty).
# The standard tables are evaluated at mediator = 0 (its mean: it is centred
# within participant), so the Condition contrasts are the label effect at
# average beauty. On top of that, the population-level (re_formula = NA)
# predicted response for every Condition x grid value, per draw, and the
# per-participant mean of the mediator in each condition. mediation_effects()
# turns those into direct / indirect effects and slopes; it runs in the
# notebook, as it only needs these few MB.

get_mediation_estimates <- function(m, outcome, verbose = TRUE) {
  info <- mediation_info[[outcome]]
  med <- info$mediator
  by <- if (is.null(info$by)) "Condition" else info$by
  step <- function(what) if (verbose) cat("**", outcome, "-", what, ":", format(Sys.time()), "\n")

  est <- list(
    outcome = outcome,
    label = info$label,
    family = info$family,
    mediator = med,
    by = by,
    created = Sys.time(),
    ndraws = brms::ndraws(m),
    nchains = brms::nchains(m)
  )

  step("diagnostics")
  est$diag <- get_diagnostics(m, outcome, family = info$family)
  est$convergence <- get_convergence(m)

  step(paste0("marginal means (", by, ", covariates at 0)"))
  est$means <- get_means(m, by = by)

  step(paste0("contrasts (", by, ", covariates at 0)"))
  rez <- get_contrasts(m, outcome, contrast = by)
  est$contrasts <- rez$dat_con
  est$contrasts_credible <- rez$rez_con

  step("predictions over the mediator grid")
  d <- model_data(m)
  lv <- levels(d[[by]])
  grid <- expand.grid(g = lv, x = info$grid)
  names(grid) <- c(by, med)
  grid[[by]] <- factor(grid[[by]], levels = lv)
  for (cv in names(info$covariates)) grid[[cv]] <- info$covariates[[cv]]
  est$grid <- grid
  est$grid_draws <- brms::posterior_epred(m, newdata = grid, re_formula = NA) # draws x rows
  # The same for the distributional parameters (response scale of each dpar),
  # to show whether the label and beauty act on the choice (mu: probability of
  # the right-hand side) or on the confidence within a side
  est$grid_dpars <- lapply(setNames(nm = info$dpars), function(par) {
    brms::posterior_epred(m, newdata = grid, re_formula = NA, dpar = par)
  })

  # Other covariates (e.g. Beauty2_w): predictions at their value +/- h, per
  # level of `by`, mediator at 0 -> covariate_slopes() in the notebook
  est$covariate_grid <- lapply(setNames(nm = names(info$covariates)), function(cv) {
    h <- 0.05
    g2 <- expand.grid(g = lv, delta = c(-h, h))
    names(g2)[1] <- by
    g2[[by]] <- factor(g2[[by]], levels = lv)
    g2[[med]] <- 0
    for (o in names(info$covariates)) g2[[o]] <- info$covariates[[o]]
    g2[[cv]] <- g2[[cv]] + g2$delta
    list(grid = g2, draws = brms::posterior_epred(m, newdata = g2, re_formula = NA),
         dpars = lapply(setNames(nm = info$dpars), function(par) {
           brms::posterior_epred(m, newdata = g2, re_formula = NA, dpar = par)
         }))
  })

  est$mediator_means <- stats::aggregate(
    stats::as.formula(paste(med, "~ Participant +", by)), data = d, FUN = mean
  )
  # Spread of the (centred) mediator over trials: where moderation_effects()
  # evaluates "low" and "high"
  est$mediator_summary <- c(SD = stats::sd(d[[med]]),
                            stats::quantile(d[[med]], c(0.1, 0.25, 0.5, 0.75, 0.9)))
  est
}

# Slope of the prediction on the mediator at 0, per level of `by`, and the
# pairwise differences between levels, per 0.1 of the mediator, x100 (% of the
# outcome slider, or percentage points of a dpar). For models where
# mediation_effects() does not apply (ArtificialityBeauty: by = Type).
# `range`: the response's scale range (6 for Meaning), so `response` slopes
# are in % of the scale; dpars are always in percentage points. `at`: where
# the slope is taken (default the participant's mean, 0); other values need
# grid points at `at` +/- h (mediation_grid_quad has them at +/-0.2, +/-0.4).
grid_slopes <- function(est, par = "response", h = 0.005, range = 1, at = 0) {
  by <- if (is.null(est$by)) "Condition" else est$by
  g <- est$grid
  P <- if (par == "response") est$grid_draws else est$grid_dpars[[par]]
  k <- if (par == "response") 100 / range else 100
  lv <- levels(g[[by]])
  pt <- function(l, x) {
    i <- which(g[[by]] == l & abs(g[[est$mediator]] - x) < 1e-9)
    if (length(i) != 1) stop("no grid point at ", est$mediator, " = ", x, " for ", l, call. = FALSE)
    P[, i]
  }
  slope <- lapply(setNames(nm = lv), function(l) (pt(l, at + h) - pt(l, at - h)) / (2 * h) * 0.1 * k)
  describe <- function(x) {
    ci <- bayestestR::hdi(x, ci = 0.95)
    data.frame(Median = stats::median(x), CI_low = ci$CI_low, CI_high = ci$CI_high,
               pd = as.numeric(bayestestR::p_direction(x)))
  }
  pairs <- utils::combn(lv, 2)
  rbind(
    do.call(rbind, lapply(lv, function(l) cbind(Level = l, describe(slope[[l]])))),
    do.call(rbind, lapply(seq_len(ncol(pairs)), function(k) {
      cbind(Level = paste(pairs[2, k], "-", pairs[1, k]), describe(slope[[pairs[2, k]]] - slope[[pairs[1, k]]]))
    }))
  )
}

# The same for a covariate held constant in the grid (est$covariate_grid),
# per 0.1 of the covariate. `pairs = TRUE` adds the pairwise differences
# between levels (e.g. how the label gap changes with follow-up beauty).
covariate_slopes <- function(est, covariate, par = "response", range = 1, pairs = FALSE) {
  by <- if (is.null(est$by)) "Condition" else est$by
  cg <- est$covariate_grid[[covariate]]
  P <- if (par == "response") cg$draws else cg$dpars[[par]]
  k <- if (par == "response") 100 / range else 100
  g <- cg$grid
  lv <- levels(g[[by]])
  h <- max(g$delta)
  describe <- function(x) {
    ci <- bayestestR::hdi(x, ci = 0.95)
    data.frame(Median = stats::median(x), CI_low = ci$CI_low, CI_high = ci$CI_high,
               pd = as.numeric(bayestestR::p_direction(x)))
  }
  slope <- lapply(setNames(nm = lv), function(l) {
    (P[, g[[by]] == l & g$delta > 0] - P[, g[[by]] == l & g$delta < 0]) / (2 * h) * 0.1 * k
  })
  out <- do.call(rbind, lapply(lv, function(l) cbind(Level = l, describe(slope[[l]]))))
  if (pairs) {
    pr <- if (by == "Condition") strsplit(contrast_order, " - ", fixed = TRUE) else {
      cb <- utils::combn(lv, 2)
      lapply(seq_len(ncol(cb)), function(j) c(cb[2, j], cb[1, j]))
    }
    out <- rbind(out, do.call(rbind, lapply(pr, function(p) {
      cbind(Level = paste(p[1], "-", p[2]), describe(slope[[p[1]]] - slope[[p[2]]]))
    })))
  }
  out
}

# Moderation of the label effect by the grid variable (self-relevance: the
# BeautySR / BeautySRControl / MeaningSR entries of mediation_info), from
# get_mediation_estimates(). With E[Y | c, x] the population-level prediction
# (linear interpolation along the grid; covariates held at 0):
#   gaps    the label contrast E[Y | c1, x] - E[Y | c0, x] at each value of
#           `at` (default: -1 SD, 0, +1 SD of the centred moderator over
#           trials), and "High - Low", its change from the lowest to the
#           highest value of `at` (the interaction on the response scale)
#   slopes  dE[Y]/dx at x = 0 per label, per 0.1 of the moderator (10% of the
#           SR scale), and their differences between labels
# x100, or x100 / range for `response` (range = 6 for Meaning): % of the
# rating's scale, or percentage points of a dpar.
moderation_effects <- function(est, par = "response", at = NULL, range = 1, h = 0.005) {
  med <- est$mediator
  g <- est$grid
  P <- if (par == "response") est$grid_draws else est$grid_dpars[[par]]
  if (is.null(P)) stop("no grid predictions for '", par, "' -- re-run ./hpc extract ", est$outcome, call. = FALSE)
  k <- if (par == "response") 100 / range else 100
  if (is.null(at)) {
    s <- if (!is.null(est$mediator_summary)) est$mediator_summary[["SD"]] else 0.2
    at <- c(Low = -s, Average = 0, High = s)
  }
  if (is.null(names(at))) names(at) <- format(at, digits = 2)

  ey <- function(cond, x) {
    cols <- which(g$Condition == cond)
    cols <- cols[order(g[[med]][cols])]
    xs <- g[[med]][cols]
    j <- min(max(findInterval(x, xs), 1), length(xs) - 1)
    w <- (x - xs[j]) / (xs[j + 1] - xs[j])
    (1 - w) * P[, cols[j]] + w * P[, cols[j + 1]]
  }
  describe <- function(x) {
    ci <- bayestestR::hdi(x, ci = 0.95)
    data.frame(Median = stats::median(x), CI_low = ci$CI_low, CI_high = ci$CI_high,
               pd = as.numeric(bayestestR::p_direction(x)))
  }

  pairs <- strsplit(contrast_order, " - ", fixed = TRUE)
  gaps <- do.call(rbind, lapply(pairs, function(p) {
    gap <- lapply(at, function(x) k * (ey(p[1], x) - ey(p[2], x)))
    rbind(
      do.call(rbind, lapply(names(at), function(a) {
        cbind(Contrast = paste(p[1], "-", p[2]), At = a, Moderator = unname(at[a]), describe(gap[[a]]))
      })),
      cbind(Contrast = paste(p[1], "-", p[2]), At = "High - Low", Moderator = NA_real_,
            describe(gap[[length(at)]] - gap[[1]]))
    )
  }))

  conds <- levels(g$Condition)
  slope <- lapply(setNames(nm = conds), function(cnd) (ey(cnd, h) - ey(cnd, -h)) / (2 * h) * 0.1 * k)
  slopes <- rbind(
    do.call(rbind, lapply(conds, function(cnd) cbind(Condition = cnd, describe(slope[[cnd]])))),
    do.call(rbind, lapply(pairs, function(p) cbind(Condition = paste(p[1], "-", p[2]), describe(slope[[p[1]]] - slope[[p[2]]]))))
  )
  list(gaps = gaps, slopes = slopes, at = at)
}

# Mediation of the label effect by the mediator, from get_mediation_estimates().
# For a contrast c1 - c0, with E[Y | c, m] the population-level prediction
# (linearly interpolated along the grid) and M_c the mean mediator under c:
#   Total     E[Y | c1, M_c1] - E[Y | c0, M_c0]
#   Direct    E[Y | c1, M_c0] - E[Y | c0, M_c0]   (label, beauty held as under c0)
#   Indirect  E[Y | c1, M_c1] - E[Y | c1, M_c0]   (beauty moved as the label moves it)
#   Proportion  Indirect / Total
# M_c is bootstrapped over participants, one resample per posterior draw, so
# the uncertainty of the label -> mediator path is carried along. Evaluating
# at the mean mediator (rather than averaging over its distribution) is an
# approximation for a non-linear model; the grid step around 0 is 0.005.
# Slopes: dE[Y]/dm at m = 0 per condition, and their differences (the
# interaction on the response scale), per 0.1 of the mediator (10% of the
# beauty slider). Everything is x100, i.e. in % of the belief slider (for
# par = "mu" / "confright" / "confleft": in percentage points of that
# parameter, from est$grid_dpars). The bootstrap of M_c uses the same seed
# for every par, so the parameters share the same mediator draws.
mediation_effects <- function(est, par = "response", seed = 1234, h = 0.005) {
  med <- est$mediator
  g <- est$grid
  P <- if (par == "response") est$grid_draws else est$grid_dpars[[par]]
  if (is.null(P)) stop("no grid predictions for '", par, "' -- re-run ./hpc extract ", est$outcome, call. = FALSE)
  n <- nrow(P)
  conds <- levels(g$Condition)

  ey <- function(cond, mval) {
    cols <- which(g$Condition == cond)
    cols <- cols[order(g[[med]][cols])]
    x <- g[[med]][cols]
    mval <- rep_len(mval, n)
    j <- pmin(pmax(findInterval(mval, x), 1), length(x) - 1)
    w <- (mval - x[j]) / (x[j + 1] - x[j])
    i <- seq_len(n)
    (1 - w) * P[cbind(i, cols[j])] + w * P[cbind(i, cols[j + 1])]
  }

  mm <- est$mediator_means
  wide <- tapply(mm[[med]], list(mm$Participant, mm$Condition), mean)[, conds, drop = FALSE]
  set.seed(seed)
  M <- t(vapply(seq_len(n), function(k) {
    colMeans(wide[sample.int(nrow(wide), replace = TRUE), , drop = FALSE], na.rm = TRUE)
  }, numeric(length(conds))))

  describe <- function(x) {
    ci <- bayestestR::hdi(x, ci = 0.95)
    data.frame(Median = stats::median(x), CI_low = ci$CI_low, CI_high = ci$CI_high,
               pd = as.numeric(bayestestR::p_direction(x)))
  }

  pairs <- strsplit(contrast_order, " - ", fixed = TRUE)
  effects <- do.call(rbind, lapply(pairs, function(p) {
    c1 <- p[1]
    c0 <- p[2]
    total <- ey(c1, M[, c1]) - ey(c0, M[, c0])
    direct <- ey(c1, M[, c0]) - ey(c0, M[, c0])
    indirect <- ey(c1, M[, c1]) - ey(c1, M[, c0])
    a <- M[, c1] - M[, c0]
    rbind(
      cbind(Contrast = paste(c1, "-", c0), Effect = "Mediator (a)", describe(100 * a)),
      cbind(Contrast = paste(c1, "-", c0), Effect = "Total", describe(100 * total)),
      cbind(Contrast = paste(c1, "-", c0), Effect = "Direct", describe(100 * direct)),
      cbind(Contrast = paste(c1, "-", c0), Effect = "Indirect", describe(100 * indirect)),
      cbind(Contrast = paste(c1, "-", c0), Effect = "Proportion mediated", describe(100 * indirect / total))
    )
  }))

  slope <- lapply(setNames(nm = conds), function(cnd) (ey(cnd, h) - ey(cnd, -h)) / (2 * h) * 0.1 * 100)
  slopes <- rbind(
    do.call(rbind, lapply(conds, function(cnd) cbind(Condition = cnd, describe(slope[[cnd]])))),
    do.call(rbind, lapply(pairs, function(p) cbind(Condition = paste(p[1], "-", p[2]), describe(slope[[p[1]]] - slope[[p[2]]]))))
  )

  list(effects = effects, slopes = slopes, mediator_draws = M)
}


# Joint appraisal mediators -------------------------------------------------
# Belief ~ Condition * (Beauty_w + Valence_w + Meaning_w + Worth_w). A grid
# over four mediators is out of the question, so the decomposition uses a
# handful of population-level predictions (re_formula = NA), per draw:
#   base      every condition at every condition's mean mediator vector M_c
#             (the mean over participants of their per-condition means)
#   slope     every condition at M_c0 +/- h on one mediator at a time, for
#             every reference condition c0 (the slope of mediator k under
#             condition c, evaluated where c0 leaves the mediators)
#   cue       every condition at 0 +/- h on one mediator (the slope at the
#             participant's average appraisal, for the "cue strength" tables)
# appraisal_effects() combines them with a participant bootstrap of M_c.

get_appraisal_estimates <- function(m, outcome, verbose = TRUE) {
  info <- appraisal_info[[outcome]]
  meds <- info$mediators
  step <- function(what) if (verbose) cat("**", outcome, "-", what, ":", format(Sys.time()), "\n")

  est <- list(outcome = outcome, label = info$label, family = info$family,
              mediators = meds, by = "Condition", created = Sys.time(),
              ndraws = brms::ndraws(m), nchains = brms::nchains(m))

  step("diagnostics")
  est$diag <- get_diagnostics(m, outcome, family = info$family)
  est$convergence <- get_convergence(m)

  step("marginal means and contrasts (mediators at 0)")
  est$means <- get_means(m)
  rez <- get_contrasts(m, outcome, contrast = "Condition")
  est$contrasts <- rez$dat_con
  est$contrasts_credible <- rez$rez_con

  step("prediction points")
  d <- model_data(m)
  lv <- levels(d$Condition)
  pm <- stats::aggregate(d[meds], by = list(Participant = d$Participant, Condition = d$Condition), FUN = mean)
  est$mediator_means <- pm
  M <- t(sapply(lv, function(cnd) colMeans(pm[pm$Condition == cnd, meds, drop = FALSE])))
  h <- 0.01
  rows <- list()
  add <- function(type, cond, at, ref = NA, med = NA, delta = 0) {
    r <- data.frame(type = type, Condition = cond, ref = ref, med = med, delta = delta)
    for (k in meds) r[[k]] <- at[[k]]
    rows[[length(rows) + 1]] <<- r
  }
  for (cnd in lv) for (c0 in lv) add("base", cnd, as.list(M[c0, ]), ref = c0)
  for (cnd in lv) for (c0 in lv) for (k in meds) for (dl in c(-h, h)) {
    at <- as.list(M[c0, ])
    at[[k]] <- at[[k]] + dl
    add("slope", cnd, at, ref = c0, med = k, delta = dl)
  }
  zero <- as.list(setNames(rep(0, length(meds)), meds))
  for (cnd in lv) for (k in meds) for (dl in c(-h, h)) {
    at <- zero
    at[[k]] <- dl
    add("cue", cnd, at, med = k, delta = dl)
  }
  pts <- do.call(rbind, rows)
  pts$Condition <- factor(pts$Condition, levels = lv)
  est$points <- pts
  est$points_draws <- brms::posterior_epred(m, newdata = pts, re_formula = NA)
  est$points_dpars <- lapply(setNames(nm = info$dpars), function(par) {
    brms::posterior_epred(m, newdata = pts, re_formula = NA, dpar = par)
  })
  est
}

# Decomposition of each contrast c1 - c0, x100 (% of the belief slider, or
# percentage points of a dpar):
#   Direct            E[Y | c1, M_c0] - E[Y | c0, M_c0]
#   Indirect (k)      slope_k(c1 | M_c0) x (M_k,c1 - M_k,c0): mediator k moved
#                     as the label moves it, the others held where c0 leaves them
#   Indirect (joint)  the sum over mediators (first-order; the exact
#                     E[Y | c1, M_c1] - E[Y | c1, M_c0] at the mean M is
#                     returned as "Indirect (joint, exact)" for comparison)
#   Total             Direct + Indirect (joint)
#   Mediator (k)      M_k,c1 - M_k,c0, in % of that rating's scale
# M_c is bootstrapped over participants (one resample per draw), so the label
# -> mediator paths carry their uncertainty. `cues`: slope of each mediator
# under each condition at the participant's average appraisal, per +10% of
# the rating, and the differences between conditions.
appraisal_effects <- function(est, par = "response", seed = 1234) {
  P <- if (par == "response") est$points_draws else est$points_dpars[[par]]
  pts <- est$points
  meds <- est$mediators
  lv <- levels(pts$Condition)
  n <- nrow(P)
  col <- function(...) {
    f <- list(...)
    i <- which(Reduce(`&`, lapply(names(f), function(v) !is.na(pts[[v]]) & pts[[v]] == f[[v]])))
    stopifnot(length(i) == 1)
    P[, i]
  }
  h <- max(pts$delta)

  pm <- est$mediator_means
  set.seed(seed)
  parts <- unique(as.character(pm$Participant))
  boot <- lapply(seq_len(n), function(k) sample(parts, replace = TRUE))
  Mb <- lapply(setNames(nm = lv), function(cnd) {
    sub <- pm[pm$Condition == cnd, ]
    X <- as.matrix(sub[meds])
    rownames(X) <- as.character(sub$Participant)
    # indexing by name keeps the duplicates of a with-replacement resample
    t(vapply(boot, function(b) colMeans(X[b[b %in% rownames(X)], , drop = FALSE]), numeric(length(meds))))
  })

  describe <- function(x) {
    ci <- bayestestR::hdi(x, ci = 0.95)
    data.frame(Median = stats::median(x), CI_low = ci$CI_low, CI_high = ci$CI_high,
               pd = as.numeric(bayestestR::p_direction(x)))
  }
  pairs <- strsplit(contrast_order, " - ", fixed = TRUE)
  effects <- do.call(rbind, lapply(pairs, function(p) {
    c1 <- p[1]
    c0 <- p[2]
    direct <- col(type = "base", Condition = c1, ref = c0) - col(type = "base", Condition = c0, ref = c0)
    exact <- col(type = "base", Condition = c1, ref = c1) - col(type = "base", Condition = c1, ref = c0)
    ind <- lapply(setNames(nm = meds), function(k) {
      slope <- (col(type = "slope", Condition = c1, ref = c0, med = k, delta = h) -
                col(type = "slope", Condition = c1, ref = c0, med = k, delta = -h)) / (2 * h)
      slope * (Mb[[c1]][, k] - Mb[[c0]][, k])
    })
    joint <- Reduce(`+`, ind)
    out <- rbind(
      cbind(Path = "Total", describe(100 * (direct + joint))),
      cbind(Path = "Direct", describe(100 * direct)),
      cbind(Path = "Indirect (joint)", describe(100 * joint)),
      cbind(Path = "Indirect (joint, exact)", describe(100 * exact)),
      do.call(rbind, lapply(meds, function(k) cbind(Path = paste0("Indirect (", sub("_w$", "", k), ")"), describe(100 * ind[[k]])))),
      do.call(rbind, lapply(meds, function(k) cbind(Path = paste0("Mediator (", sub("_w$", "", k), ")"), describe(100 * (Mb[[c1]][, k] - Mb[[c0]][, k])))))
    )
    cbind(Contrast = paste(c1, "-", c0), out)
  }))

  cue <- lapply(setNames(nm = meds), function(k) lapply(setNames(nm = lv), function(cnd) {
    (col(type = "cue", Condition = cnd, med = k, delta = h) - col(type = "cue", Condition = cnd, med = k, delta = -h)) / (2 * h) * 0.1 * 100
  }))
  cues <- do.call(rbind, lapply(meds, function(k) rbind(
    do.call(rbind, lapply(lv, function(cnd) cbind(Mediator = sub("_w$", "", k), Condition = cnd, describe(cue[[k]][[cnd]])))),
    do.call(rbind, lapply(pairs, function(p) cbind(Mediator = sub("_w$", "", k), Condition = paste(p[1], "-", p[2]), describe(cue[[k]][[p[1]]] - cue[[k]][[p[2]]]))))
  )))

  list(effects = effects, cues = cues)
}


# Item-level determinants ----------------------------------------------------
# Belief ~ Condition + Style + z-scored VAPS norms. Per draw, population-level
# predictions averaged over Condition x Style (balanced design): at 0 +/- 0.5
# SD on each norm, the others at 0 (slope per SD), and at 0 per Style (style
# means). Plus the usual diagnostics and Condition contrasts.

get_items_estimates <- function(m, outcome, verbose = TRUE) {
  info <- items_info[[outcome]]
  norms <- info$norms
  step <- function(what) if (verbose) cat("**", outcome, "-", what, ":", format(Sys.time()), "\n")

  est <- list(outcome = outcome, label = info$label, family = info$family,
              norms = norms, created = Sys.time(),
              ndraws = brms::ndraws(m), nchains = brms::nchains(m))

  step("diagnostics")
  est$diag <- get_diagnostics(m, outcome, family = info$family)
  est$convergence <- get_convergence(m)

  step("contrasts (Condition)")
  rez <- get_contrasts(m, outcome, contrast = "Condition")
  est$contrasts <- rez$dat_con

  step("prediction points")
  d <- model_data(m)
  base <- expand.grid(Condition = levels(d$Condition), Style = levels(d$Style))
  for (nm in norms) base[[nm]] <- 0
  rows <- list(cbind(base, type = "style", norm = NA, delta = 0))
  for (nm in norms) for (dl in c(-0.5, 0.5)) {
    b <- base
    b[[nm]] <- dl
    rows[[length(rows) + 1]] <- cbind(b, type = "norm", norm = nm, delta = dl)
  }
  pts <- do.call(rbind, rows)
  pts$Condition <- factor(pts$Condition, levels = levels(d$Condition))
  pts$Style <- factor(pts$Style, levels = levels(d$Style))
  est$points <- pts
  est$points_draws <- brms::posterior_epred(m, newdata = pts, re_formula = NA)
  est$points_dpars <- lapply(setNames(nm = info$dpars), function(par) {
    brms::posterior_epred(m, newdata = pts, re_formula = NA, dpar = par)
  })
  est
}

# Slope per +1 SD of each norm and the mean per Style (both averaged over
# conditions and, for the slopes, styles), and all pairwise Style
# differences, x100 (% of the belief slider, or percentage points of a dpar).
items_effects <- function(est, par = "response") {
  P <- if (par == "response") est$points_draws else est$points_dpars[[par]]
  pts <- est$points
  describe <- function(x) {
    ci <- bayestestR::hdi(x, ci = 0.95)
    data.frame(Median = stats::median(x), CI_low = ci$CI_low, CI_high = ci$CI_high,
               pd = as.numeric(bayestestR::p_direction(x)))
  }
  avg <- function(i) rowMeans(P[, i, drop = FALSE])
  slopes <- do.call(rbind, lapply(est$norms, function(nm) {
    x <- avg(which(pts$type == "norm" & pts$norm %in% nm & pts$delta > 0)) -
      avg(which(pts$type == "norm" & pts$norm %in% nm & pts$delta < 0))
    cbind(Predictor = sub("_z$", "", sub("^Norms_", "", nm)), describe(100 * x))
  }))
  styles <- levels(pts$Style)
  sm <- lapply(setNames(nm = styles), function(st) avg(which(pts$type == "style" & pts$Style == st)))
  means <- do.call(rbind, lapply(styles, function(st) cbind(Style = st, describe(100 * sm[[st]]))))
  pairs <- utils::combn(styles, 2)
  diffs <- do.call(rbind, lapply(seq_len(ncol(pairs)), function(k) {
    cbind(Contrast = paste(pairs[2, k], "-", pairs[1, k]), describe(100 * (sm[[pairs[2, k]]] - sm[[pairs[1, k]]])))
  }))
  list(slopes = slopes, style_means = means, style_contrasts = diffs)
}

# Model comparison ----------------------------------------------------------
# The loo that combine_model.R attached, reduced to what a comparison needs
# (`./hpc loo <model>` -> models/loo/<model>.rds, a few hundred KB): the
# summary and the pointwise elpd / Pareto k, one value per row of the data.
get_loo <- function(m, outcome, verbose = TRUE) {
  l <- m$criteria$loo
  if (is.null(l)) stop("no loo attached to ", outcome, " -- re-run ./hpc combine ", outcome, call. = FALSE)
  list(outcome = outcome, created = Sys.time(), ndraws = brms::ndraws(m),
       estimates = l$estimates, elpd = l$pointwise[, "elpd_loo"],
       pareto_k = l$pointwise[, "influence_pareto_k"])
}

# elpd difference of two get_loo() results on the same rows (b - a > 0: b
# predicts better), with the SE of the paired difference, as loo_compare().
loo_difference <- function(a, b) {
  stopifnot(length(a$elpd) == length(b$elpd))
  d <- b$elpd - a$elpd
  data.frame(Model = b$outcome, Reference = a$outcome, elpd_diff = sum(d),
             se_diff = sqrt(length(d)) * stats::sd(d),
             max_pareto_k = max(c(a$pareto_k, b$pareto_k), na.rm = TRUE))
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
  if (!is.null(mediation_info[[outcome]]$individual)) return(get_mediation_individual(m, outcome, verbose))
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

# Mediation models: each participant's slope of the belief on the mediator
# (Index "Slope"), on the link scale per unit of the mediator (the whole 0-1
# slider), averaged over the labels, from the participant term only. For
# RealityBeauty's mu: how strongly a participant takes beauty as a sign of
# human authorship. The linear predictor is linear in the mediator, so the
# difference between mediator = 1 and 0 is the slope itself.
get_mediation_individual <- function(m, outcome, verbose = TRUE) {
  info <- mediation_info[[outcome]]
  step <- function(what) if (verbose) cat("**", outcome, "-", what, ":", format(Sys.time()), "\n")
  d <- m$data
  participants <- sort(unique(as.character(d$Participant)))
  grid <- expand.grid(Participant = participants, Condition = levels(factor(d$Condition)),
                      .x = c(0, 1), stringsAsFactors = FALSE)
  names(grid)[names(grid) == ".x"] <- info$mediator
  at <- function(cond, x) which(grid$Condition == cond & grid[[info$mediator]] == x) # participant order

  rez <- lapply(info$individual, function(p) {
    step(p)
    eta <- brms::posterior_linpred(m, newdata = grid, dpar = p, transform = FALSE,
                                   re_formula = participant_term(m, p))
    conds <- unique(grid$Condition)
    s <- Reduce(`+`, lapply(conds, function(k) eta[, at(k, 1), drop = FALSE] - eta[, at(k, 0), drop = FALSE])) / length(conds)
    data.frame(Participant = participants, Parameter = p, Index = "Slope",
               Mean = colMeans(s), SD = apply(s, 2, stats::sd),
               SD_rel = apply(s - rowMeans(s), 2, stats::sd))
  })

  list(outcome = outcome, created = Sys.time(), ndraws = brms::ndraws(m), individual = bind_rows(rez))
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
