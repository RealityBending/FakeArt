# =========================================================================
# Model registry -- the one place a model is defined
# =========================================================================
# Sourced by fit_model.R (which fits exactly one of these per job) and by
# combine_model.R (which merges that model's shards). `./hpc` reads the model
# *names* straight out of this file, so keep the declaration lines in the form
#
#     <name> = list(
#
# at two-space indent, one per model. `./hpc models` prints what it found.
#
# Each entry:
#   outcome   the column being modelled (used to drop NAs)
#   data      (optional) which cleaned file the model is fitted to:
#               "task"    data_task.csv merged with data_eyetracking.csv, one
#                         row per Phase-1 trial (the default; 324 x 48 rows)
#               "memory"  data_memory_task.csv, one row per follow-up trial
#                         (220 x 96 rows: the 48 old items *and* the 48 new
#                         ones, with the Phase-1/2 data of old items joined on)
#             fit_model.R loads and prepares the file named here
#             (fa_prepare_data() / fa_prepare_memory()).
#   subset    (optional) function(data) data: rows to keep (e.g. old items only)
#   prepare   (optional) function(data) data: derived predictors (e.g. a
#             within-participant centred covariate); both are applied in
#             fit_model.R after the outcome's NA rows are dropped
#   formula   a function returning the brms bf(). A function rather than the
#             object so that sourcing this file costs nothing and only the
#             model actually being fitted is built.
#   priors    (optional) a function(formula, data) returning a brmsprior. The
#             default is fa_priors(), below, which is what every current model
#             uses; the slot exists so one model can deviate without touching
#             the shared helper.
#
# The names are the ones 3_models.qmd reads: `./hpc pull` drops
# combined/<name>.rds into analysis/models/, where the notebook expects
# models/Beauty.rds, models/Reality.rds, etc. Do not rename an entry without
# renaming it there too.
#
# The families come from cogmod (https://github.com/DominiqueMakowski/cogmod).
# These formulas were first fitted in July 2026 with the pre-0.3 API
# (choco(), betadiscrete(), choco_stanvars(), hand-written priors, init = 0);
# the constructors were renamed cogmod_choco(), cogmod_betadiscrete() and the
# stanvars/priors/inits helpers became family-generic (cogmod_stanvars(f),
# cogmod_priors(f, data), cogmod_inits(f, data)), with CHOCO and Discrete-Beta
# support for the last two added on 2026-09-20 (cogmod 0.3.3 dev). The
# distributional-parameter names did NOT change (mu, confright, confleft,
# precright, precleft, pex, bex, pmid; mu, phi, pzero), so fits made with
# either API read the same way in the notebooks.


# Shared right-hand sides ---------------------------------------------------
# The design is 3 label Conditions x 4 stimulus Emotion quadrants, with
# participants and items crossed. Two variants recur:

# full: condition x emotion, both varying by participant, condition by item
fa_rhs_full <- "Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item)"
# slim: as above but only a random intercept per item (precision parameters)
fa_rhs_slim <- "Condition * Emotion + (Condition * Emotion | Participant) + (1 | Item)"
# gaze: the eye-tracking features additionally adjust for sample count
fa_rhs_gaze <- "Condition * Emotion + Gaze_nSamples + (Condition * Emotion | Participant) + (Condition | Item)"

fa_f <- function(lhs, rhs = fa_rhs_full) {
  stats::as.formula(paste(lhs, "~", rhs), env = globalenv())
}

# CHOCO: every distributional parameter modelled. Used for the analog sliders
# (Beauty, Beauty2, Reality, Authenticity, PerceivedArtificiality), which show
# the choice-plus-confidence bimodality with mass at 0, 0.5 and 1.
# The right-hand sides default to the Condition * Emotion design; the
# determinants-of-belief models pass their own.
fa_choco <- function(outcome, rhs = fa_rhs_full, rhs_slim = fa_rhs_slim,
                     rhs_extreme = "Condition + (1 | Participant)") {
  brms::bf(
    fa_f(outcome, rhs),
    fa_f("confright", rhs),
    fa_f("confleft", rhs),
    fa_f("precright", rhs_slim),
    fa_f("precleft", rhs_slim),
    fa_f("pex", rhs_extreme),
    fa_f("bex", rhs_extreme),
    fa_f("pmid", rhs_extreme),
    family = cogmod::cogmod_choco()
  )
}

# Determinants of reality beliefs: the Phase-2 belief on the label and the
# Phase-1 beauty of the same trial (Beauty_w, centred within participant, see
# fa_prepare_beauty()), with their interaction -- does beauty still inform the
# belief once the image carries a "fake" label? Emotion is left out (the design
# is balanced, so the Condition effect stays comparable to the overall
# contrasts of Reality / Authenticity). Beauty_w varies within item as well,
# so the item block gets its slope, without the interaction.
fa_rhs_beauty <- "Condition * Beauty_w + (Condition * Beauty_w | Participant) + (Condition + Beauty_w | Item)"
fa_rhs_beauty_slim <- "Condition * Beauty_w + (Condition * Beauty_w | Participant) + (1 | Item)"
fa_rhs_beauty_extreme <- "Condition * Beauty_w + (1 | Participant)"

fa_choco_beauty <- function(outcome) {
  fa_choco(outcome, fa_rhs_beauty, fa_rhs_beauty_slim, fa_rhs_beauty_extreme)
}

# Shape check (2026-09-24). Beauty_w enters the models above linearly on
# every dpar. Exploratory lme4 / GAM pilots (5_realitydeterminants.qmd,
# "Exploratory checks") found no U-shape anywhere, but a convex
# authenticity-by-beauty link: flat below the participant's mean beauty,
# steep above it, which the linear CHOCO fit smooths into a straight line.
# The same design with a quadratic term on the label x beauty part; the random
# slopes stay linear, for tractability.
fa_rhs_beauty_quad <- "Condition * (Beauty_w + I(Beauty_w^2)) + (Condition * Beauty_w | Participant) + (Condition + Beauty_w | Item)"
fa_rhs_beauty_quad_slim <- "Condition * (Beauty_w + I(Beauty_w^2)) + (Condition * Beauty_w | Participant) + (1 | Item)"
fa_rhs_beauty_quad_extreme <- "Condition * (Beauty_w + I(Beauty_w^2)) + (1 | Participant)"

# Phase-1 beauty centred within participant, over the trials the model uses,
# so its slope is "this artwork vs. my other artworks" and the participant
# intercepts absorb between-person differences in the beauty level. The label
# is randomised within participant, so the label effect on Beauty_w is the
# label effect on Beauty.
fa_prepare_beauty <- function(d) {
  d <- d[!is.na(d$Beauty), ]
  d$Beauty_w <- d$Beauty - stats::ave(d$Beauty, d$Participant)
  d
}

# Robustness: the same, plus the follow-up beauty of the same artwork
# (Beauty2_w, centred within participant), rated after the debrief and
# unaffected by the label -- a label-free measure of how appealing the work is
# to that person. If the Beauty_w slope and the label effects hold with it in
# the model, the mediation is not "some works are just more appealing".
# Participants who returned for the follow-up only (217 with Phase-2 data).
fa_rhs_beauty_control <- "Condition * Beauty_w + Beauty2_w + (Condition * Beauty_w + Beauty2_w | Participant) + (Condition + Beauty_w | Item)"
fa_rhs_beauty_control_slim <- "Condition * Beauty_w + Beauty2_w + (Condition * Beauty_w + Beauty2_w | Participant) + (1 | Item)"
fa_rhs_beauty_control_extreme <- "Condition * Beauty_w + Beauty2_w + (1 | Participant)"

fa_prepare_beauty_control <- function(d) {
  d <- d[!is.na(d$Beauty) & !is.na(d$Beauty2), ]
  d$Beauty_w <- d$Beauty - stats::ave(d$Beauty, d$Participant)
  d$Beauty2_w <- d$Beauty2 - stats::ave(d$Beauty2, d$Participant)
  d
}

# Perceived artificiality of the items judged "new" in the follow-up, by their
# follow-up beauty (Beauty2_w, centred within participant over those rows),
# for never-seen (New) vs. previously labelled (Old) items: does the "less
# beautiful -> more artificial" inference work without any label?
fa_rhs_artificiality <- "Type * Beauty2_w + (Type * Beauty2_w | Participant) + (Beauty2_w | Item)"
fa_rhs_artificiality_slim <- "Type * Beauty2_w + (Type * Beauty2_w | Participant) + (1 | Item)"
fa_rhs_artificiality_extreme <- "Type * Beauty2_w + (1 | Participant)"

fa_prepare_artificiality <- function(d) {
  d <- d[!is.na(d$Beauty2), ]
  d$Beauty2_w <- d$Beauty2 - stats::ave(d$Beauty2, d$Participant)
  d
}

# Which component of the Phase-1 appraisal carries the label effect on the
# belief? All four ratings of the same trial as joint mediators, each
# rescaled to 0-1 (fa_prepare_data() turned Valence into 1..7, Meaning into
# 0..6 and Worth into an ordered factor) and centred within participant.
# Worth is the divergent test: a downstream valuation, not expected to carry
# a unique route to the belief. Kept tractable: label x rating interactions
# as fixed effects only; random slopes for the label and the four ratings
# over participants, the label only over items; precisions and the extreme /
# midpoint probabilities without the interactions.
fa_appraisal <- c("Beauty_w", "Valence_w", "Meaning_w", "Worth_w")
fa_rhs_appraisal <- paste0(
  "Condition * (", paste(fa_appraisal, collapse = " + "), ")",
  " + (Condition + ", paste(fa_appraisal, collapse = " + "), " | Participant) + (Condition | Item)"
)
fa_rhs_appraisal_slim <- paste0(
  "Condition * (", paste(fa_appraisal, collapse = " + "), ") + (1 | Participant) + (1 | Item)"
)
fa_rhs_appraisal_extreme <- paste0(
  "Condition + ", paste(fa_appraisal, collapse = " + "), " + (1 | Participant)"
)

fa_prepare_appraisal <- function(d) {
  d <- d[!is.na(d$Beauty) & !is.na(d$Valence) & !is.na(d$Meaning) & !is.na(d$Worth), ]
  center <- function(x) x - stats::ave(x, d$Participant)
  d$Beauty_w <- center(d$Beauty)
  d$Valence_w <- center((d$Valence - 1) / 6)
  d$Meaning_w <- center(d$Meaning / 6)
  d$Worth_w <- center((as.numeric(d$Worth) - 1) / 5)
  d
}

# Item-level determinants: style and the VAPS norms (independent norming
# sample, so label- and participant-free), each norm z-scored over the 48
# items. Random label slopes over participants; item intercepts absorb what
# the norms do not explain. Descriptive: 48 items, 8 item-level predictors.
fa_norms <- c("Norms_Liking", "Norms_Valence", "Norms_Arousal", "Norms_Complexity", "Norms_Familiarity")
fa_rhs_items <- paste0(
  "Condition + Style + ", paste0(fa_norms, "_z", collapse = " + "),
  " + (Condition | Participant) + (1 | Item)"
)
fa_rhs_items_slim <- paste0(
  "Condition + Style + ", paste0(fa_norms, "_z", collapse = " + "), " + (1 | Participant) + (1 | Item)"
)

fa_prepare_items <- function(d) {
  items <- unique(d[c("Item", fa_norms)])
  for (n in fa_norms) {
    z <- (items[[n]] - mean(items[[n]])) / stats::sd(items[[n]])
    d[[paste0(n, "_z")]] <- z[match(d$Item, items$Item)]
  }
  d$Style <- factor(d$Style)
  d
}

# Self-relevance (6_selfrelevance.qmd). Rated in the follow-up (220
# participants), after the debrief and right after Beauty2, and not affected
# by the label (SelfRelevance model): a label-free measure of how much a
# person connects with a work. It therefore enters as a moderator or a
# predictor, never as a mediator of the label (the label -> SR path is null).
# SR is the 0-6 rating on 0-1 (fa_prepare_data() made SelfRelevance an ordered
# factor for the SelfRelevance model; the memory file keeps it numeric),
# centred within participant over the model's rows (SR_w), so a slope reads
# "this artwork vs. my other artworks", per 10% of the scale like Beauty_w.
# `with`: other ratings centred the same way (Beauty -> Beauty_w, Beauty2 ->
# Beauty2_w); rows missing any of them are dropped. Beauty2 is the competing
# predictor wherever SR could stand for liking (within-participant r = .58).
fa_prepare_sr <- function(d, with = character(0)) {
  sr <- d$SelfRelevance
  d$SR <- if (is.factor(sr)) as.numeric(as.character(sr)) / 6 else sr
  vars <- c("SR", with)
  d <- d[stats::complete.cases(d[vars]), ]
  for (v in vars) d[[paste0(v, "_w")]] <- d[[v]] - stats::ave(d[[v]], d$Participant)
  d
}

# (A) Does self-relevance narrow the label gap (RQ3)? Phase-1 rating on the
# label, SR_w and their interaction, laid out as fa_rhs_beauty with SR_w in
# place of Beauty_w (Emotion left out, as in the determinants models).
fa_rhs_sr <- "Condition * SR_w + (Condition * SR_w | Participant) + (Condition + SR_w | Item)"
fa_rhs_sr_slim <- "Condition * SR_w + (Condition * SR_w | Participant) + (1 | Item)"
fa_rhs_sr_extreme <- "Condition * SR_w + (1 | Participant)"

# ...and the same with the follow-up beauty as a competing moderator: is it
# self-relevance or liking that goes with a larger / smaller label gap?
fa_rhs_sr_control <- "Condition * (SR_w + Beauty2_w) + (Condition * (SR_w + Beauty2_w) | Participant) + (Condition + SR_w + Beauty2_w | Item)"
fa_rhs_sr_control_slim <- "Condition * (SR_w + Beauty2_w) + (Condition * (SR_w + Beauty2_w) | Participant) + (1 | Item)"
fa_rhs_sr_control_extreme <- "Condition * (SR_w + Beauty2_w) + (1 | Participant)"

# ...and between persons (2026-09-24). SR_w keeps only the within-person part
# of self-relevance: someone who finds every work self-relevant and someone
# who finds none are alike at SR_w = 0. SR_b adds the participant's own mean
# SR (0-1, over the model's rows, centred on the mean of the participant
# means), so Condition x SR_b asks whether people who find art more
# self-relevant show a smaller label gap, next to the within-person moderation
# (Condition x SR_w) -- a within-between (Mundlak) decomposition, whose SR_w
# terms estimate the same thing as BeautySR's. SR_b is a participant-level
# predictor, so it has no participant slope.
fa_prepare_sr_between <- function(d) {
  d <- fa_prepare_sr(d)
  m <- stats::ave(d$SR, d$Participant)
  d$SR_b <- m - mean(m[!duplicated(d$Participant)])
  d
}
fa_rhs_sr_between <- "Condition * (SR_w + SR_b) + (Condition * SR_w | Participant) + (Condition + SR_w | Item)"
fa_rhs_sr_between_slim <- "Condition * (SR_w + SR_b) + (Condition * SR_w | Participant) + (1 | Item)"
fa_rhs_sr_between_extreme <- "Condition * (SR_w + SR_b) + (1 | Participant)"

# (B) "Self-relevant = human"? The Phase-2 belief on the label x (Phase-1
# beauty, SR, follow-up beauty), laid out as the appraisal models (label x
# rating interactions fixed only) so get_appraisal_estimates() decomposes it:
# the SR and Beauty2 slopes under each label, and indirect effects via SR /
# Beauty2 that should be ~0 since the label moves neither.
fa_sr_beliefs <- c("Beauty_w", "SR_w", "Beauty2_w")
fa_rhs_sr_beliefs <- paste0(
  "Condition * (", paste(fa_sr_beliefs, collapse = " + "), ")",
  " + (Condition + ", paste(fa_sr_beliefs, collapse = " + "), " | Participant) + (Condition | Item)"
)
fa_rhs_sr_beliefs_slim <- paste0(
  "Condition * (", paste(fa_sr_beliefs, collapse = " + "), ") + (1 | Participant) + (1 | Item)"
)
fa_rhs_sr_beliefs_extreme <- paste0(
  "Condition + ", paste(fa_sr_beliefs, collapse = " + "), " + (1 | Participant)"
)

# ...and without any label: perceived artificiality of the items judged new,
# as ArtificialityBeauty plus SR_w.
fa_rhs_sr_artificiality <- "Type * (Beauty2_w + SR_w) + (Type * (Beauty2_w + SR_w) | Participant) + (Beauty2_w + SR_w | Item)"
fa_rhs_sr_artificiality_slim <- "Type * (Beauty2_w + SR_w) + (Type * (Beauty2_w + SR_w) | Participant) + (1 | Item)"
fa_rhs_sr_artificiality_extreme <- "Type * (Beauty2_w + SR_w) + (1 | Participant)"


fa_models <- list(

  # PHASE 1 -- ratings ========================================================

  # Beauty ------------------------------------------------------------------
  # Analog slider, rescaled to [0, 1] in data_task.csv.
  Beauty = list(
    outcome = "Beauty",
    formula = function() fa_choco("Beauty")
  ),

  # Valence -----------------------------------------------------------------
  # 7-point pictorial scale, stored as 1..7 by fa_prepare_data(). Discrete
  # Beta with k = 7 via vint(7); pzero = 0 because the scale has no zero
  # category.
  Valence = list(
    outcome = "Valence",
    formula = function() {
      brms::bf(
        fa_f("Valence | vint(7)"),
        fa_f("phi"),
        pzero = 0,
        family = cogmod::cogmod_betadiscrete()
      )
    }
  ),

  # Meaning -----------------------------------------------------------------
  # 0..6 numeric scale, kept as 0..6. Discrete Beta on 1..6 (vint(6)) with a
  # hurdle at 0 (pzero), because Meaning shows far more exact zeros than a
  # Beta on 0..6 can produce. pzero gets the full design.
  Meaning = list(
    outcome = "Meaning",
    formula = function() {
      brms::bf(
        fa_f("Meaning | vint(6)"),
        fa_f("phi"),
        fa_f("pzero"),
        family = cogmod::cogmod_betadiscrete()
      )
    }
  ),

  # Worth -------------------------------------------------------------------
  # 6-point log-money scale ($0 .. $100,000), an ordered factor. Cumulative
  # ordinal with a participant- and item-varying discrimination. The July fit
  # had (Condition * Emotion | Item); Emotion is a property of the item, so
  # those slopes were not separable from the item intercept and were dropped
  # on 2026-09-21 (fa_rhs_full, like every other model).
  Worth = list(
    outcome = "Worth",
    formula = function() {
      brms::bf(
        fa_f("Worth"),
        disc ~ 1 + (1 | Participant) + (1 | Item),
        family = brms::cumulative()
      )
    }
  ),

  # PHASE 1 -- eye-tracking ===================================================
  # Features from 2_eyetracking.qmd, merged onto the task data; trials
  # without usable gaze are NA and dropped for these models only.

  # Entropy -----------------------------------------------------------------
  # Normalised spatial entropy of gaze, a proportion strictly inside (0, 1).
  Entropy = list(
    outcome = "Gaze_Entropy",
    formula = function() {
      brms::bf(
        fa_f("Gaze_Entropy", fa_rhs_gaze),
        fa_f("phi", fa_rhs_gaze),
        family = brms::Beta()
      )
    }
  ),

  # pLeft -------------------------------------------------------------------
  # Proportion of samples on the left half of the image; exact 0s and 1s
  # occur, hence zero-one-inflated Beta.
  pLeft = list(
    outcome = "Gaze_pLeft",
    formula = function() {
      brms::bf(
        fa_f("Gaze_pLeft", fa_rhs_gaze),
        fa_f("phi", fa_rhs_gaze),
        zoi ~ 1 + (1 | Participant),
        coi ~ 1 + (1 | Participant),
        family = brms::zero_one_inflated_beta()
      )
    }
  ),

  # pCenter -----------------------------------------------------------------
  # Proportion of samples in the central region of the image. Same model as
  # pLeft.
  pCenter = list(
    outcome = "Gaze_pCenter",
    formula = function() {
      brms::bf(
        fa_f("Gaze_pCenter", fa_rhs_gaze),
        fa_f("phi", fa_rhs_gaze),
        zoi ~ 1 + (1 | Participant),
        coi ~ 1 + (1 | Participant),
        family = brms::zero_one_inflated_beta()
      )
    }
  ),

  # Shift -------------------------------------------------------------------
  # Largest centroid relocation within a trial, in stimulus widths; strictly
  # positive and right-skewed.
  Shift = list(
    outcome = "Gaze_Shift",
    formula = function() {
      brms::bf(
        fa_f("Gaze_Shift", fa_rhs_gaze),
        fa_f("sigma", fa_rhs_gaze),
        family = brms::lognormal()
      )
    }
  ),

  # PHASE 2 -- reality beliefs ================================================
  # Both sliders are NA for the 7 participants whose Phase 2 data was dropped
  # in 1_cleaning.qmd; the NA filter handles it.

  # Reality -----------------------------------------------------------------
  # "Syntheticness" in the paper: AI-generated (0) .. Human creation (1).
  Reality = list(
    outcome = "Reality",
    formula = function() fa_choco("Reality")
  ),

  # Authenticity ------------------------------------------------------------
  # Copy / forgery (0) .. Original creation (1).
  Authenticity = list(
    outcome = "Authenticity",
    formula = function() fa_choco("Authenticity")
  ),

  # PHASE 2 -- determinants of reality beliefs ================================
  # Does the label act on the belief directly, or through the lower beauty it
  # induced in Phase 1 (label -> Beauty -> belief)? Beauty is rated before the
  # belief, and the label is randomised, so the decomposition is a mediation:
  # the natural direct and indirect effects are computed from these fits'
  # predictions over a Beauty_w grid (estimates.R, mediation_info and
  # mediation_effects()). Read by the "Determinants of Reality Beliefs"
  # section of the manuscript. The label-free controls (Beauty2) and
  # artificiality of new items are the planned next models.

  # RealityBeauty -----------------------------------------------------------
  RealityBeauty = list(
    outcome = "Reality",
    prepare = fa_prepare_beauty,
    formula = function() fa_choco_beauty("Reality")
  ),

  # AuthenticityBeauty ------------------------------------------------------
  AuthenticityBeauty = list(
    outcome = "Authenticity",
    prepare = fa_prepare_beauty,
    formula = function() fa_choco_beauty("Authenticity")
  ),

  # AuthenticityBeautyQuad ----------------------------------------------------
  # Shape check: AuthenticityBeauty + a quadratic Beauty_w term (see
  # fa_rhs_beauty_quad). AuthenticityBeauty stays the analysed model unless
  # this one fits clearly better *and* changes its numbers.
  AuthenticityBeautyQuad = list(
    outcome = "Authenticity",
    prepare = fa_prepare_beauty,
    formula = function() {
      fa_choco("Authenticity", fa_rhs_beauty_quad, fa_rhs_beauty_quad_slim, fa_rhs_beauty_quad_extreme)
    }
  ),

  # RealityBeautyControl / AuthenticityBeautyControl -------------------------
  # Robustness: + label-free follow-up beauty (fa_prepare_beauty_control()).
  RealityBeautyControl = list(
    outcome = "Reality",
    prepare = fa_prepare_beauty_control,
    formula = function() {
      fa_choco("Reality", fa_rhs_beauty_control, fa_rhs_beauty_control_slim, fa_rhs_beauty_control_extreme)
    }
  ),
  AuthenticityBeautyControl = list(
    outcome = "Authenticity",
    prepare = fa_prepare_beauty_control,
    formula = function() {
      fa_choco("Authenticity", fa_rhs_beauty_control, fa_rhs_beauty_control_slim, fa_rhs_beauty_control_extreme)
    }
  ),

  # RealityAppraisal / AuthenticityAppraisal --------------------------------
  # Beauty, valence, meaning and worth of the same Phase-1 trial as joint
  # mediators (fa_prepare_appraisal()); extracted by get_appraisal_estimates().
  RealityAppraisal = list(
    outcome = "Reality",
    prepare = fa_prepare_appraisal,
    formula = function() {
      fa_choco("Reality", fa_rhs_appraisal, fa_rhs_appraisal_slim, fa_rhs_appraisal_extreme)
    }
  ),
  AuthenticityAppraisal = list(
    outcome = "Authenticity",
    prepare = fa_prepare_appraisal,
    formula = function() {
      fa_choco("Authenticity", fa_rhs_appraisal, fa_rhs_appraisal_slim, fa_rhs_appraisal_extreme)
    }
  ),

  # RealityItems / AuthenticityItems ----------------------------------------
  # Style + VAPS norms (fa_prepare_items()); extracted by get_items_estimates().
  RealityItems = list(
    outcome = "Reality",
    prepare = fa_prepare_items,
    formula = function() fa_choco("Reality", fa_rhs_items, fa_rhs_items_slim)
  ),
  AuthenticityItems = list(
    outcome = "Authenticity",
    prepare = fa_prepare_items,
    formula = function() fa_choco("Authenticity", fa_rhs_items, fa_rhs_items_slim)
  ),

  # ArtificialityBeauty -----------------------------------------------------
  # Follow-up file: every item judged "new" (the only ones asked about
  # artificiality), new items (never labelled) and missed old items.
  ArtificialityBeauty = list(
    outcome = "PerceivedArtificiality",
    data = "memory",
    prepare = fa_prepare_artificiality,
    formula = function() {
      fa_choco("PerceivedArtificiality", fa_rhs_artificiality, fa_rhs_artificiality_slim, fa_rhs_artificiality_extreme)
    }
  ),

  # FOLLOW-UP -- memory session ===============================================
  # Only the 220 participants who returned have these columns; the rest are
  # NA in data_task.csv.

  # Beauty2 -----------------------------------------------------------------
  # Beauty rated again in the follow-up, after the debrief.
  Beauty2 = list(
    outcome = "Beauty2",
    formula = function() fa_choco("Beauty2")
  ),

  # SelfRelevance -----------------------------------------------------------
  # 0..6 rating, treated as ordered like Worth (same 2026-09-21 change to the
  # item term).
  SelfRelevance = list(
    outcome = "SelfRelevance",
    formula = function() {
      brms::bf(
        fa_f("SelfRelevance"),
        disc ~ 1 + (1 | Participant) + (1 | Item),
        family = brms::cumulative()
      )
    }
  ),

  # Artificiality -----------------------------------------------------------
  # Perceived artificiality slider, asked in the follow-up for images judged
  # "new". Registry name kept short to match models/Artificiality.rds.
  Artificiality = list(
    outcome = "PerceivedArtificiality",
    formula = function() fa_choco("PerceivedArtificiality")
  ),

  # SELF-RELEVANCE -- moderator and predictor =================================
  # Follow-up participants only (fa_prepare_sr() drops the rest). Read by
  # 6_selfrelevance.qmd; extracted through mediation_info (A, and
  # ArtificialitySR) and appraisal_info (RealitySR / AuthenticitySR).

  # BeautySR / BeautySRControl / MeaningSR ------------------------------------
  # (A) Phase-1 rating ~ Condition * SR_w (+ Beauty2_w as a competing moderator).
  BeautySR = list(
    outcome = "Beauty",
    prepare = fa_prepare_sr,
    formula = function() fa_choco("Beauty", fa_rhs_sr, fa_rhs_sr_slim, fa_rhs_sr_extreme)
  ),
  BeautySRControl = list(
    outcome = "Beauty",
    prepare = function(d) fa_prepare_sr(d, with = "Beauty2"),
    formula = function() {
      fa_choco("Beauty", fa_rhs_sr_control, fa_rhs_sr_control_slim, fa_rhs_sr_control_extreme)
    }
  ),
  # Within + between persons: Condition * (SR_w + SR_b), see fa_prepare_sr_between().
  BeautySRBetween = list(
    outcome = "Beauty",
    prepare = fa_prepare_sr_between,
    formula = function() {
      fa_choco("Beauty", fa_rhs_sr_between, fa_rhs_sr_between_slim, fa_rhs_sr_between_extreme)
    }
  ),
  # As Meaning (Discrete Beta with a zero hurdle), every dpar on fa_rhs_sr:
  # pzero asks whether a self-relevant work escapes the "not at all
  # meaningful" answer the AI label provokes.
  MeaningSR = list(
    outcome = "Meaning",
    prepare = fa_prepare_sr,
    formula = function() {
      brms::bf(
        fa_f("Meaning | vint(6)", fa_rhs_sr),
        fa_f("phi", fa_rhs_sr),
        fa_f("pzero", fa_rhs_sr),
        family = cogmod::cogmod_betadiscrete()
      )
    }
  ),

  # RealitySR / AuthenticitySR -----------------------------------------------
  # (B) Phase-2 belief ~ Condition * (Beauty_w + SR_w + Beauty2_w); 217
  # participants (follow-up and Phase 2).
  RealitySR = list(
    outcome = "Reality",
    prepare = function(d) fa_prepare_sr(d, with = c("Beauty", "Beauty2")),
    formula = function() {
      fa_choco("Reality", fa_rhs_sr_beliefs, fa_rhs_sr_beliefs_slim, fa_rhs_sr_beliefs_extreme)
    }
  ),
  AuthenticitySR = list(
    outcome = "Authenticity",
    prepare = function(d) fa_prepare_sr(d, with = c("Beauty", "Beauty2")),
    formula = function() {
      fa_choco("Authenticity", fa_rhs_sr_beliefs, fa_rhs_sr_beliefs_slim, fa_rhs_sr_beliefs_extreme)
    }
  ),

  # ArtificialitySR ------------------------------------------------------------
  # (B) Follow-up file, items judged "new" (as ArtificialityBeauty):
  # PerceivedArtificiality ~ Type * (Beauty2_w + SR_w).
  ArtificialitySR = list(
    outcome = "PerceivedArtificiality",
    data = "memory",
    prepare = function(d) fa_prepare_sr(d, with = "Beauty2"),
    formula = function() {
      fa_choco("PerceivedArtificiality", fa_rhs_sr_artificiality, fa_rhs_sr_artificiality_slim, fa_rhs_sr_artificiality_extreme)
    }
  ),

  # FOLLOW-UP -- recognition and source memory ================================
  # These read data_memory_task.csv (data = "memory"), which also holds the 48
  # *new* items per participant, so Condition has a fourth level "New Items".
  # The design is Condition only (no Emotion): the questions are about what
  # was remembered of the label, not about the stimulus. Read by 4_memory.qmd.

  # MemoryCondition -----------------------------------------------------------
  # Which label does the participant say the item had in Phase 1?
  # AnswerCondition is one of Human Original / Human Forgery / AI-Generated,
  # or "Not recognized" when the item was judged new (Recognition == "No"), so
  # one categorical model carries recognition and source memory together: the
  # "Not recognized" category is the miss rate for old items (and the correct
  # rejection rate for new items, whose other three categories are false
  # alarms with a fabricated label). Reference categories are Human Original
  # for both the outcome and Condition, so the mu<category> coefficients on
  # Condition<label> read as log-odds of answering <category> rather than
  # "Human Original" for an item that was presented as <label> rather than as
  # a Human Original. Condition varies by participant and by item: some
  # people/items are better remembered, and some are more readily called AI.
  MemoryCondition = list(
    outcome = "AnswerCondition",
    data = "memory",
    formula = function() {
      brms::bf(
        AnswerCondition ~ Condition + (1 + Condition | Participant) + (1 + Condition | Item),
        family = brms::categorical(link = "logit")
      )
    }
  ),

  # MemoryBelief --------------------------------------------------------------
  # The same question one level up: not what label the item carried, but what
  # the participant *believed* about it in Phase 2, and whether they recall
  # that belief in the follow-up. `Belief` is the Phase-2 judgement (Human
  # Original / Human Forgery / AI Original / AI Copy, crossing the syntheticness
  # and authenticity sliders) and `AnswerBelief` is what they say in the
  # follow-up, with "Not recognized" again standing in for an item judged new.
  #
  # `Belief` has a fifth level, "None": all 10,560 new items plus 144 old
  # trials with no recorded belief. It is the new-item baseline here, as
  # "New Items" is for Condition in MemoryCondition, so the whole file enters
  # the model and the reference category stays Human Original on both sides.
  #
  # Belief varies within item as well as within participant -- different people
  # reached different Phase-2 judgements about the same artwork -- so both
  # grouping factors get the slope, as in MemoryCondition. The rarest level
  # (Human Forgery) is 1,344 trials over 96 items, ~14 per item, and the
  # commonest old-item level (Human Original) ~48; each item carries 220
  # participants against each participant's 96 trials, which is why the item
  # side is the better-informed of the two. MemoryCondition bears that out:
  # its `cor_Item` are the best-mixed parameters in the model (max Rhat 1.008,
  # none above 1.01, min ESS ratio 0.133), while its `cor_Participant` are the
  # worst (1.131, 0.011). brms fits one correlation matrix per mu, so the item
  # side here is 4 mus x 10 correlations = 40 parameters, not a single 20 x 20.
  MemoryBelief = list(
    outcome = "AnswerBelief",
    data = "memory",
    formula = function() {
      brms::bf(
        AnswerBelief ~ Belief + (1 + Belief | Participant) + (1 + Belief | Item),
        family = brms::categorical(link = "logit")
      )
    }
  ),

  # MemoryConditionBelief ------------------------------------------------------
  # Is the recalled label reconstructed from one's own Phase-2 belief? The
  # descriptives say so (recognised items judged "AI Original" are recalled
  # as "AI-Generated" 47% of the time, against 26% for items judged "Human
  # Original") while the actual label predicts nothing (MemoryCondition). This
  # puts both in one model: AnswerCondition on the label actually shown *and*
  # the participant's own belief, so the Belief contrasts are the effect of
  # the belief with the label held constant.
  #
  # Old items only, with a recorded belief (subset below): new items have
  # neither a label nor a belief, and keeping them would make "New Items" and
  # Belief "None" the same 10,560 rows. 220 x 48 - 144 = 10,416 rows.
  # Additive, not Condition * Belief: the 12 cells would leave the rarer
  # label x belief combinations with a handful of trials per participant.
  MemoryConditionBelief = list(
    outcome = "AnswerCondition",
    data = "memory",
    subset = function(d) d[d$Type == "Old" & d$Belief != "None", ],
    formula = function() {
      brms::bf(
        AnswerCondition ~ Condition + Belief +
          (1 + Condition + Belief | Participant) + (1 + Condition + Belief | Item),
        family = brms::categorical(link = "logit")
      )
    }
  ),

  # MemoryAppraisal -------------------------------------------------------------
  # Hypothesis 1 of the follow-up preregistration (memory/ethics/
  # preregistration.md): artworks given extreme Phase-1 appraisals, positive
  # or negative, are better recognised (Lee et al., 2023; Salgues et al.,
  # 2024). The recalled label, with "Not recognized" carrying recognition as in
  # MemoryCondition, on the label shown and on Phase-1 beauty and valence, each
  # centred within participant over the old items and entered with a quadratic
  # term (extremity relative to the participant's own average, which the lme4
  # pilots preferred to extremity around the slider's midpoint). Old items only:
  # new items have no Phase-1 rating, and false alarms are the business of the
  # follow-up ratings (6_selfrelevance.qmd, section C). Beauty and valence
  # correlate ~.76 within participant, so each quadratic term is a unique
  # contribution; get_memory_grid_estimates() also predicts along their joint
  # direction. Random intercepts and linear slopes over participants, random
  # intercepts over items (their memorability). Read by 4_memory.qmd, "Memory
  # by Phase-1 Appraisal", through memory_grid_info (estimates.R).
  MemoryAppraisal = list(
    outcome = "AnswerCondition",
    data = "memory",
    subset = function(d) d[d$Type == "Old", ],
    prepare = function(d) {
      d <- d[!is.na(d$Beauty) & !is.na(d$Valence), ]
      d$Beauty_w <- d$Beauty - stats::ave(d$Beauty, d$Participant)
      d$Valence_w <- d$Valence - stats::ave(d$Valence, d$Participant)
      d
    },
    formula = function() {
      brms::bf(
        AnswerCondition ~ Condition + Beauty_w + I(Beauty_w^2) + Valence_w + I(Valence_w^2) +
          (1 + Beauty_w + Valence_w | Participant) + (1 | Item),
        family = brms::categorical(link = "logit")
      )
    }
  )
)


# Data ----------------------------------------------------------------------
# The transformations every model shares, applied once in fit_model.R. They
# mirror the top of 3_models.qmd: the cleaned data stores every outcome on
# [0, 1], and the discrete families want their native integer scales back.
fa_prepare_data <- function(dftask) {
  dftask$Condition <- factor(dftask$Condition,
    levels = c("Human Original", "Human Forgery", "AI-Generated")
  )
  dftask$Emotion <- factor(dftask$Emotion,
    levels = c(
      "Positive - Low intensity", "Negative - Low intensity",
      "Positive - High intensity", "Negative - High intensity"
    )
  )
  dftask$Valence <- round(dftask$Valence * 6 + 1) # 1..7
  dftask$Meaning <- round(dftask$Meaning * 6) # 0..6
  dftask$Worth <- factor(dftask$Worth, ordered = TRUE)
  levels(dftask$Worth) <- c("0", "10", "100", "1000", "10000", "100000")
  dftask$SelfRelevance <- factor(round(dftask$SelfRelevance * 6), ordered = TRUE)
  dftask
}

# The follow-up file (data = "memory"). Mirrors the top of 4_memory.qmd: the
# first level of each factor is the reference category, both for the
# categorical outcomes (brms takes the first level as the baseline of the
# multinomial logit) and for the predictors.
fa_prepare_memory <- function(dfmem) {
  dfmem$Condition <- factor(dfmem$Condition,
    levels = c("Human Original", "Human Forgery", "AI-Generated", "New Items")
  )
  dfmem$AnswerCondition <- factor(dfmem$AnswerCondition,
    levels = c("Human Original", "Human Forgery", "AI-Generated", "Not recognized")
  )
  dfmem$AnswerBelief <- factor(dfmem$AnswerBelief,
    levels = c("Human Original", "Human Forgery", "AI Original", "AI Copy", "Not recognized")
  )
  dfmem$Belief <- factor(dfmem$Belief,
    levels = c("Human Original", "Human Forgery", "AI Original", "AI Copy", "None")
  )
  dfmem$Recognition <- factor(dfmem$Recognition, levels = c("No", "Yes"))
  dfmem$Type <- factor(dfmem$Type, levels = c("Old", "New"))
  dfmem
}


# Priors --------------------------------------------------------------------
# Start from the family's own priors -- cogmod_priors(f, data) for cogmod
# families (since cogmod 0.3.3 dev of 2026-09-20 it covers cogmod_choco and
# cogmod_betadiscrete: normal(0, 0.5) slopes and informed intercepts on every
# auxiliary dpar, exponential(1) group SDs), brms::get_prior() for native
# ones -- and fill ONLY what is left flat:
#
#   flat blanket slope (class b) of a dpar   normal(0, 2)
#     ...and that dpar's interaction terms    normal(0, 1)  -- tighter; the
#                                                 design has 6 interaction cells
#   flat intercept of a cogmod dpar           normal(0, 3) for mu / confright /
#                                             confleft, normal(0, 5) otherwise
#
# Rows the family helper set are never overwritten (IGC's lesson, their
# AGENT.md 5.7: cogmod's slope priors are tighter than ours on purpose, and a
# blanket override widened them). In practice, for CHOCO that leaves us
# filling the main (mu) slopes and nothing else; the July 2026 fits used
# normal(0, 2) / normal(0, 1) on every dpar, so the auxiliary dpars are now
# more tightly regularised than they were. Everything goes through
# validate_prior(), so a prior matching no parameter errors here rather than
# inside brm().
fa_is_cogmod <- function(f) {
  fam <- f$family
  inherits(fam, "customfamily") && startsWith(fam$name, "cogmod")
}

fa_priors <- function(f, data) {
  priors <- if (fa_is_cogmod(f)) {
    cogmod::cogmod_priors(f, data)
  } else {
    brms::get_prior(f, data)
  }
  flat <- !nzchar(priors$prior)

  # Flat intercepts of a cogmod family (the main one keeps brms's default if
  # cogmod left it, which it does).
  if (fa_is_cogmod(f)) {
    is_int <- priors$class == "Intercept" & flat
    wide <- priors$dpar %in% c("", "mu", "confright", "confleft")
    priors$prior[is_int & wide] <- "normal(0, 3)"
    priors$prior[is_int & !wide] <- "normal(0, 5)"
  }

  # Slopes, per dpar: only where the blanket `b` row (no coef, no group) is
  # flat do we set it, and only then do we tighten that dpar's interactions.
  is_b <- priors$class == "b" & !nzchar(priors$group)
  for (par in unique(priors$dpar[is_b])) {
    blanket <- is_b & priors$dpar == par & !nzchar(priors$coef)
    if (!any(blanket & flat)) next # the family helper set it; leave the dpar alone
    priors$prior[blanket] <- "normal(0, 2)"
    interaction <- is_b & priors$dpar == par & grepl(":", priors$coef, fixed = TRUE)
    priors$prior[interaction] <- "normal(0, 1)"
  }

  brms::validate_prior(priors, f, data)
}


# Stan functions and starting values ---------------------------------------
# cogmod families carry their Stan code in stanvars and take cogmod_inits(),
# which returns an init *function* (brms calls it once per chain) with data-
# informed starting values for every dpar and jittered group-level terms.
# cogmod covers cogmod_choco and cogmod_betadiscrete since 0.3.3 dev
# (2026-09-20); an older library errors here with "has nothing to offer for
# family ...", and the fix is `./hpc install cogmod`, not a fallback -- the
# July 2026 fits ran from init = 0, but that is not what these scripts do now.
# Native brms families need neither and keep init = 0.
fa_stanvars <- function(f) {
  if (fa_is_cogmod(f)) cogmod::cogmod_stanvars(f) else NULL
}

fa_inits <- function(f, data) {
  if (!fa_is_cogmod(f)) return(0)
  cogmod::cogmod_inits(f, data)
}


# Look one up, with an error that says what the alternatives are rather than
# "subscript out of bounds" three hours into a job.
fa_model <- function(name) {
  if (!nzchar(name)) {
    stop("no model requested: set FA_MODEL to one of ",
         paste(names(fa_models), collapse = ", "), call. = FALSE)
  }
  if (!name %in% names(fa_models)) {
    stop("unknown model '", name, "'. Known models: ",
         paste(names(fa_models), collapse = ", "), call. = FALSE)
  }
  spec <- c(list(name = name), fa_models[[name]])
  if (is.null(spec$priors)) spec$priors <- fa_priors
  if (is.null(spec$data)) spec$data <- "task"
  if (!spec$data %in% c("task", "memory")) {
    stop("model '", name, "' has data = '", spec$data, "'; must be 'task' or 'memory'",
         call. = FALSE)
  }
  spec
}
