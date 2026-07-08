library(brms)
library(cmdstanr)
library(cogmod)

task_id <- as.numeric(Sys.getenv("SLURM_ARRAY_TASK_ID", unset = "1"))
total_cores <- as.numeric(Sys.getenv("SLURM_CPUS_PER_TASK", unset = "2"))

cat("================\nNode Info:\n")
cat(paste0("** Task ID: ", task_id, "\n"))
cat(paste0("** Total cores: ", total_cores, "\n"))
cat("** GCC version: \n")
system("g++ --version")

# Hardcode the chains for this node, and calculate threads dynamically
chains_per_node <- 2
threads_per_chain <- total_cores / chains_per_node # 16 cores / 2 chains = 8 threads per chain

warmup <- 5000
iter <- warmup + 800
thin <- 2 # Thinning saves only every n-th draw. If 400 iterations only 200 will be saved.
seed <- 1234 + task_id


path <- "/mnt/lustre/scratch/psych/dmm56/FakeArt/models/"

# Data ----------------------------


dftask <- read.csv("https://raw.githubusercontent.com/RealityBending/FakeArt/refs/heads/main/data/data_task.csv") |>
  merge(read.csv("https://raw.githubusercontent.com/RealityBending/FakeArt/refs/heads/main/data/data_eyetracking.csv"), all.x = TRUE)
dftask$Condition <- factor(dftask$Condition, levels = c("Human Original", "Human Forgery", "AI-Generated"))
dftask$Emotion <- factor(dftask$Emotion, levels = c("Positive - Low intensity", "Negative - Low intensity", "Positive - High intensity", "Negative - High intensity"))
dftask$Valence <- round(dftask$Valence * 6 + 1)
dftask$Meaning <- round(dftask$Meaning * 6)
dftask$Worth <- factor(dftask$Worth, ordered = TRUE)
levels(dftask$Worth) <- c("0", "10", "100", "1000", "10000", "100000")


# PHASE 1 ======================================================================

priors <- c(
  brms::set_prior("normal(0, 3)", class = "Intercept", dpar = ""),
  brms::set_prior("normal(0, 3)", class = "Intercept", dpar = "confright"),
  brms::set_prior("normal(0, 3)", class = "Intercept", dpar = "confleft"),
  brms::set_prior("normal(0, 5)", class = "Intercept", dpar = "precright"),
  brms::set_prior("normal(0, 5)", class = "Intercept", dpar = "precleft"),
  brms::set_prior("normal(0, 5)", class = "Intercept", dpar = "pex"),
  brms::set_prior("normal(0, 5)", class = "Intercept", dpar = "bex"),
  brms::set_prior("normal(0, 5)", class = "Intercept", dpar = "pmid"),
  brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = ""),
  brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = "confright"),
  brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = "confleft"),
  brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = "precright"),
  brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = "precleft"),
  brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = "pex"),
  brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = "bex"),
  brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = "pmid")
)


# # Beauty ----------------------------
#
# formula <- brms::bf(
#   Beauty ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
#   confright ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
#   confleft ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
#   precright ~ Condition * Emotion + (Condition * Emotion | Participant) + (1 | Item),
#   precleft ~ Condition * Emotion + (Condition * Emotion | Participant) + (1 | Item),
#   pex ~ Condition + (1 | Participant),
#   bex ~ Condition + (1 | Participant),
#   pmid ~ Condition + (1 | Participant),
#   family = choco()
# )
#
# # Tighter priors for interactions
# priors_beauty <- priors
# default_priors <- as.data.frame(brms::get_prior(formula, data = dftask))
# interactions <- default_priors[grepl("\\:", default_priors$coef) & default_priors$class == "b", ]
# for (i in 1:nrow(interactions)) {
#   priors_beauty <- rbind(
#     priors_beauty,
#     brms::set_prior("normal(0, 1)", class = interactions$class[i], coef = interactions$coef[i], dpar = interactions$dpar[i])
#   )
# }
#
#
# m_beauty <- brm(formula,
#   data = dftask,
#   family = choco(), stanvars = choco_stanvars(),
#   prior = brms::validate_prior(priors_beauty, formula, data = dftask),
#   init = 0,
#   chains = chains_per_node,
#   cores = chains_per_node,
#   threads = threading(threads_per_chain),
#   iter = iter,
#   warmup = warmup,
#   thin = thin,
#   seed = seed,
#   backend = "cmdstanr",
#   file = paste0(path, "Beauty_task_", task_id)
# )
#
# print("!! BEAUTY DONE !!")

# Valence ----------------------------


formula <- brms::bf(
  Valence | vint(7) ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
  phi ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
  pzero = 0,
  family = cogmod::betadiscrete()
)

# Tighter priors for interactions
priors_valence <- c(
  brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = ""),
  brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = "phi")
)
default_priors <- as.data.frame(brms::get_prior(formula, data = dftask))
interactions <- default_priors[grepl("\\:", default_priors$coef) & default_priors$class == "b", ]
for (i in 1:nrow(interactions)) {
  priors_valence <- rbind(
    priors_valence,
    brms::set_prior("normal(0, 1)", class = interactions$class[i], coef = interactions$coef[i], dpar = interactions$dpar[i])
  )
}

m_valence <- brm(formula,
  data = dftask,
  family = betadiscrete(), stanvars = betadiscrete_stanvars(),
  prior = brms::validate_prior(priors_valence, formula, data = dftask),
  init = 0,
  chains = chains_per_node,
  cores = chains_per_node,
  threads = threading(threads_per_chain),
  iter = iter,
  warmup = warmup,
  thin = thin,
  seed = seed,
  backend = "cmdstanr",
  file = paste0(path, "Valence_task_", task_id)
)

print("!! VALENCE DONE !!")

# Meaning ----------------------------


formula <- brms::bf(
  Meaning | vint(6) ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
  phi ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
  pzero ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
  family = cogmod::betadiscrete()
)

# Tighter priors for interactions
priors_meaning <- c(
  brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = ""),
  brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = "phi"),
  brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = "przero")
)
default_priors <- as.data.frame(brms::get_prior(formula, data = dftask))
interactions <- default_priors[grepl("\\:", default_priors$coef) & default_priors$class == "b", ]
for (i in 1:nrow(interactions)) {
  priors_meaning <- rbind(
    priors_meaning,
    brms::set_prior("normal(0, 1)", class = interactions$class[i], coef = interactions$coef[i], dpar = interactions$dpar[i])
  )
}


m_meaning <- brm(formula,
  data = dftask,
  family = betadiscrete(), stanvars = betadiscrete_stanvars(),
  prior = brms::validate_prior(priors_meaning, formula, data = dftask),
  init = 0,
  chains = chains_per_node,
  cores = chains_per_node,
  threads = threading(threads_per_chain),
  iter = iter,
  warmup = warmup,
  thin = thin,
  seed = seed,
  backend = "cmdstanr",
  file = paste0(path, "Meaning_task_", task_id)
)

print("!! MEANING DONE !!")

# Worth ----------------------------

formula <- brms::bf(
  Worth ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition * Emotion | Item),
  disc ~ 1 + (1 | Participant) + (1 | Item),
  family = cumulative()
)

priors_worth <- c(
  brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = "")
  # brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = "disc")
)
default_priors <- as.data.frame(brms::get_prior(formula, data = dftask[!is.na(dftask$Worth), ]))
interactions <- default_priors[grepl("\\:", default_priors$coef) & default_priors$class == "b", ]
for (i in 1:nrow(interactions)) {
  priors_worth <- rbind(
    priors_worth,
    brms::set_prior("normal(0, 1)", class = interactions$class[i], coef = interactions$coef[i], dpar = interactions$dpar[i])
  )
}


m_worth <- brm(formula,
  data = dftask[!is.na(dftask$Worth), ],
  family = cumulative(),
  prior = brms::validate_prior(priors_worth, formula, data = dftask),
  init = 0,
  chains = chains_per_node,
  cores = chains_per_node,
  threads = threading(threads_per_chain),
  iter = iter,
  warmup = warmup,
  thin = thin,
  seed = seed,
  backend = "cmdstanr",
  file = paste0(path, "Worth_task_", task_id)
)

print("!! WORTH DONE !!")

# EYETRACKING =================================================================
# # Entropy ----------------------------
#
#
# formula <- brms::bf(
#   Gaze_Entropy ~ Condition * Emotion + Gaze_nSamples + (Condition * Emotion | Participant) + (Condition | Item),
#   phi ~ Condition * Emotion + Gaze_nSamples + (Condition * Emotion | Participant) + (Condition | Item),
#   family = brms::Beta()
# )
#
# priors_entropy <- c(
#   brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = ""),
#   brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = "phi")
# )
# default_priors <- as.data.frame(brms::get_prior(formula, data = dftask[!is.na(dftask$Gaze_Entropy), ]))
# interactions <- default_priors[grepl("\\:", default_priors$coef) & default_priors$class == "b", ]
# for (i in 1:nrow(interactions)) {
#   priors_entropy <- rbind(
#     priors_entropy,
#     brms::set_prior("normal(0, 1)", class = interactions$class[i], coef = interactions$coef[i], dpar = interactions$dpar[i])
#   )
# }
#
# m_entropy <- brm(formula,
#   data = dftask[!is.na(dftask$Gaze_Entropy), ],
#   family = brms::Beta(),
#   prior = brms::validate_prior(priors_entropy, formula, data = dftask[!is.na(dftask$Gaze_Entropy), ]),
#   init = 0,
#   chains = chains_per_node,
#   cores = chains_per_node,
#   threads = threading(threads_per_chain),
#   iter = iter,
#   warmup = warmup,
#   thin = thin,
#   seed = seed,
#   backend = "cmdstanr",
#   file = paste0(path, "Entropy_task_", task_id)
# )
#
# print("!! GAZE ENTROPY DONE !!")


# # pLeft ----------------------------
# formula <- brms::bf(
#   Gaze_pLeft ~ Condition * Emotion + Gaze_nSamples + (Condition * Emotion | Participant) + (Condition | Item),
#   phi ~ Condition * Emotion + Gaze_nSamples + (Condition * Emotion | Participant) + (Condition | Item),
#   zoi ~ 1 + (1 | Participant),
#   coi ~ 1 + (1 | Participant),
#   family = brms::zero_one_inflated_beta()
# )
#
# priors_pleft <- c(
#   brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = ""),
#   brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = "phi")
# )
# default_priors <- as.data.frame(brms::get_prior(formula, data = dftask[!is.na(dftask$Gaze_pLeft), ]))
# interactions <- default_priors[grepl("\\:", default_priors$coef) & default_priors$class == "b", ]
# for (i in 1:nrow(interactions)) {
#   priors_pleft <- rbind(
#     priors_pleft,
#     brms::set_prior("normal(0, 1)", class = interactions$class[i], coef = interactions$coef[i], dpar = interactions$dpar[i])
#   )
# }
#
# m_entropy <- brm(formula,
#   data = dftask[!is.na(dftask$Gaze_pLeft), ],
#   family = brms::Beta(),
#   prior = brms::validate_prior(priors_pleft, formula, data = dftask[!is.na(dftask$Gaze_pLeft), ]),
#   init = 0,
#   chains = chains_per_node,
#   cores = chains_per_node,
#   threads = threading(threads_per_chain),
#   iter = iter,
#   warmup = warmup,
#   thin = thin,
#   seed = seed,
#   backend = "cmdstanr",
#   file = paste0(path, "pLeft_task_", task_id)
# )
#
# print("!! GAZE pLeft DONE !!")
#
#

# # pCentre ----------------------------
# formula <- brms::bf(
#   Gaze_pCenter ~ Condition * Emotion + Gaze_nSamples + (Condition * Emotion | Participant) + (Condition | Item),
#   phi ~ Condition * Emotion + Gaze_nSamples + (Condition * Emotion | Participant) + (Condition | Item),
#   zoi ~ 1 + (1 | Participant),
#   coi ~ 1 + (1 | Participant),
#   family = brms::zero_one_inflated_beta()
# )
#
# m_entropy <- brm(formula,
#   data = dftask[!is.na(dftask$Gaze_pCenter), ],
#   family = brms::Beta(),
#   prior = brms::validate_prior(priors_pleft, formula, data = dftask[!is.na(dftask$Gaze_pCenter), ]),
#   init = 0,
#   chains = chains_per_node,
#   cores = chains_per_node,
#   threads = threading(threads_per_chain),
#   iter = iter,
#   warmup = warmup,
#   thin = thin,
#   seed = seed,
#   backend = "cmdstanr",
#   file = paste0(path, "pCenter_task_", task_id)
# )
#
# print("!! GAZE pCenter DONE !!")


# # Shift ----------------------------
# formula <- brms::bf(
#   Gaze_Shift ~ Condition * Emotion + Gaze_nSamples + (Condition * Emotion | Participant) + (Condition | Item),
#   sigma ~ Condition * Emotion + Gaze_nSamples + (Condition * Emotion | Participant) + (Condition | Item),
#   family = brms::lognormal()
# )
#
# priors_shift <- c(
#   brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = ""),
#   brms::set_prior("normal(0, 2)", class = "b", coef = "", dpar = "sigma")
# )
# default_priors <- as.data.frame(brms::get_prior(formula, data = dftask[!is.na(dftask$Gaze_Shift), ]))
# interactions <- default_priors[grepl("\\:", default_priors$coef) & default_priors$class == "b", ]
# for (i in 1:nrow(interactions)) {
#   priors_pleft <- rbind(
#     priors_shift,
#     brms::set_prior("normal(0, 1)", class = interactions$class[i], coef = interactions$coef[i], dpar = interactions$dpar[i])
#   )
# }
#
#
# m_shift <- brm(formula,
#   data = dftask[!is.na(dftask$Gaze_Shift), ],
#   family = brms::lognormal(),
#   prior = brms::validate_prior(priors_shift, formula, data = dftask[!is.na(dftask$Gaze_Shift), ]),
#   init = 0,
#   chains = chains_per_node,
#   cores = chains_per_node,
#   threads = threading(threads_per_chain),
#   iter = iter,
#   warmup = warmup,
#   thin = thin,
#   seed = seed,
#   backend = "cmdstanr",
#   file = paste0(path, "Shift_task_", task_id)
# )
#
# print("!! GAZE Gaze_Shift DONE !!")


# PHASE 2 ======================================================================
# Reality ----------------------------


# formula <- brms::bf(
#   Reality ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
#   confright ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
#   confleft ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
#   precright ~ Condition * Emotion + (Condition * Emotion | Participant) + (1 | Item),
#   precleft ~ Condition * Emotion + (Condition * Emotion | Participant) + (1 | Item),
#   pex ~ Condition + (1 | Participant),
#   bex ~ Condition + (1 | Participant),
#   pmid ~ Condition + (1 | Participant),
#   family = choco()
# )
#
# # Tighter priors for interactions
# priors_reality <- priors
# default_priors <- as.data.frame(brms::get_prior(formula, data = dftask[!is.na(dftask$Reality), ]))
# interactions <- default_priors[grepl("\\:", default_priors$coef) & default_priors$class == "b", ]
# for (i in 1:nrow(interactions)) {
#   priors_reality <- rbind(
#     priors_reality,
#     brms::set_prior("normal(0, 1)", class = interactions$class[i], coef = interactions$coef[i], dpar = interactions$dpar[i])
#   )
# }
#
# m_reality <- brm(formula,
#   data = dftask[!is.na(dftask$Reality), ],
#   family = choco(), stanvars = choco_stanvars(),
#   prior = brms::validate_prior(priors_reality, formula, data = dftask[!is.na(dftask$Reality), ]),
#   init = 0,
#   chains = chains_per_node,
#   cores = chains_per_node,
#   threads = threading(threads_per_chain),
#   iter = iter,
#   warmup = warmup,
#   thin = thin,
#   seed = seed,
#   backend = "cmdstanr",
#   file = paste0(path, "Reality_task_", task_id)
# )
#
# print("!! REALITY DONE !!")


# Authenticity ----------------------------

#
# formula <- brms::bf(
#   Authenticity ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
#   confright ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
#   confleft ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
#   precright ~ Condition * Emotion + (Condition * Emotion | Participant) + (1 | Item),
#   precleft ~ Condition * Emotion + (Condition * Emotion | Participant) + (1 | Item),
#   pex ~ Condition + (1 | Participant),
#   bex ~ Condition + (1 | Participant),
#   pmid ~ Condition + (1 | Participant),
#   family = choco()
# )
#
# # Tighter priors for interaction
# priors_auth <- priors
# default_priors <- as.data.frame(brms::get_prior(formula, data = dftask[!is.na(dftask$Authenticity), ]))
# interactions <- default_priors[grepl("\\:", default_priors$coef) & default_priors$class == "b", ]
# for (i in 1:nrow(interactions)) {
#   priors_auth <- rbind(
#     priors_auth,
#     brms::set_prior("normal(0, 1)", class = interactions$class[i], coef = interactions$coef[i], dpar = interactions$dpar[i])
#   )
# }
#
# m_reality <- brm(formula,
#   data = dftask[!is.na(dftask$Authenticity), ],
#   family = choco(), stanvars = choco_stanvars(),
#   prior = brms::validate_prior(priors_auth, formula, data = dftask[!is.na(dftask$Authenticity), ]),
#   init = 0,
#   chains = chains_per_node,
#   cores = chains_per_node,
#   threads = threading(threads_per_chain),
#   iter = iter,
#   warmup = warmup,
#   thin = thin,
#   seed = seed,
#   backend = "cmdstanr",
#   file = paste0(path, "Authenticity_task_", task_id)
# )
#
# print("!! Authenticity DONE !!")

# FOLLOWUP ======================================================================
# Beauty2 ----------------------------


# formula <- brms::bf(
#   Beauty2 ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
#   confright ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
#   confleft ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
#   precright ~ Condition * Emotion + (Condition * Emotion | Participant) + (1 | Item),
#   precleft ~ Condition * Emotion + (Condition * Emotion | Participant) + (1 | Item),
#   pex ~ Condition + (1 | Participant),
#   bex ~ Condition + (1 | Participant),
#   pmid ~ Condition + (1 | Participant),
#   family = choco()
# )
#
# # Tighter priors for interactions
# priors_beauty2 <- priors
# default_priors <- as.data.frame(brms::get_prior(formula, data = dftask[!is.na(dftask$Beauty2), ]))
# interactions <- default_priors[grepl("\\:", default_priors$coef) & default_priors$class == "b", ]
# for (i in 1:nrow(interactions)) {
#   priors_beauty2 <- rbind(
#     priors_beauty2,
#     brms::set_prior("normal(0, 1)", class = interactions$class[i], coef = interactions$coef[i], dpar = interactions$dpar[i])
#   )
# }
#
# m_beauty2 <- brm(formula,
#   data = dftask[!is.na(dftask$Beauty2), ],
#   family = choco(), stanvars = choco_stanvars(),
#   prior = brms::validate_prior(priors_beauty2, formula, data = dftask[!is.na(dftask$Beauty2), ]),
#   init = 0,
#   chains = chains_per_node,
#   cores = chains_per_node,
#   threads = threading(threads_per_chain),
#   iter = iter,
#   warmup = warmup,
#   thin = thin,
#   seed = seed,
#   backend = "cmdstanr",
#   file = paste0(path, "Beauty2_task_", task_id)
# )
#
# print("!! BEAUTY2 DONE !!")


# Meaning ----------------------------


# # Predict both the monetary tier choice and the probability of paying $0
# formula_3 <- bf(
#   y ~ x1 + x2, # Predicts which monetary bucket they fall into (if > $0)
#   # hu ~ x1 + x2 # Predicts the probability of choosing exactly $0
# )
#
# fit_3 <- brm(
#   formula = formula_3,
#   data = your_data,
#   family = hurdle_cumulative(link = "logit", link_hu = "logit"),
#   cores = 4
# )


# # Option 2 (Recommended): Predict BOTH mean and precision (agreement)
# # Outcome must be 0–6 scale
# formula_1_dist <- bf(
#   y | trials(6) ~ x1 + x2,
#   phi ~ x1 + x2
# )
#
# fit_1 <- brm(
#   formula = formula_1_dist,
#   data = your_data,
#   family = beta_binomial(link = "logit", link_phi = "log"),
#   cores = 4
# )
#
# # Predict the mean, precision, AND the probability of a zero response
# formula_2 <- bf(
#   y | trials(6) ~ x1 + x2, # Predicts intensity (1-6)
#   phi ~ x1 + x2, # Predicts agreement
#   zi ~ x1 + x2 # Predicts the hurdle (probability of answering 0)
# )
#
# fit_2 <- brm(
#   formula = formula_2,
#   data = your_data,
#   family = zero_inflated_beta_binomial(link = "logit", link_phi = "log", link_zi = "logit"),
#   cores = 4
# )
