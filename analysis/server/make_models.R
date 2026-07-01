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
iter <- warmup + 2000
thin <- 2 # Thinning saves only every n-th draw. If 400 iterations only 200 will be saved.
seed <- 1234 + task_id


path <- "/mnt/lustre/scratch/psych/dmm56/FakeArt/models/"

# ----------------------------
# Data
# ----------------------------


dftask <- read.csv("https://raw.githubusercontent.com/RealityBending/FakeArt/refs/heads/main/data/data_task.csv")
dftask$Condition <- factor(dftask$Condition, levels = c("Human Original", "Human Forgery", "AI-Generated"))


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

# ----------------------------
# Beauty
# ----------------------------

formula <- brms::bf(
  Beauty ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
  confright ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
  confleft ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
  precright ~ Condition * Emotion + (Condition * Emotion | Participant) + (1 | Item),
  precleft ~ Condition * Emotion + (Condition * Emotion | Participant) + (1 | Item),
  pex ~ Condition + (1 | Participant),
  bex ~ Condition + (1 | Participant),
  pmid ~ Condition + (1 | Participant),
  family = choco()
)

# Tighter priors for interactions
priors_beauty <- priors
default_priors <- as.data.frame(brms::get_prior(formula, data = dftask))
interactions <- default_priors[grepl("\\:", default_priors$coef) & default_priors$class == "b", ]
for (i in 1:nrow(interactions)) {
  priors_beauty <- rbind(
    priors_beauty,
    brms::set_prior("normal(0, 1)", class = interactions$class[i], coef = interactions$coef[i], dpar = interactions$dpar[i])
  )
}


m_beauty <- brm(formula,
  data = dftask,
  family = choco(), stanvars = choco_stanvars(),
  prior = brms::validate_prior(priors_beauty, formula, data = dftask),
  init = 0,
  chains = chains_per_node,
  cores = chains_per_node,
  threads = threading(threads_per_chain),
  iter = iter,
  warmup = warmup,
  thin = thin,
  seed = seed,
  backend = "cmdstanr",
  file = paste0(path, "Beauty_task_", task_id)
)

print("!! BEAUTY DONE !!")


# ----------------------------
# Reality
# ----------------------------


formula <- brms::bf(
  Reality ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
  confright ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
  confleft ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
  precright ~ Condition * Emotion + (Condition * Emotion | Participant) + (1 | Item),
  precleft ~ Condition * Emotion + (Condition * Emotion | Participant) + (1 | Item),
  pex ~ Condition + (1 | Participant),
  bex ~ Condition + (1 | Participant),
  pmid ~ Condition + (1 | Participant),
  family = choco()
)

# Tighter priors for interactions
priors_reality <- priors
default_priors <- as.data.frame(brms::get_prior(formula, data = dftask[!is.na(dftask$Reality), ]))
interactions <- default_priors[grepl("\\:", default_priors$coef) & default_priors$class == "b", ]
for (i in 1:nrow(interactions)) {
  priors_reality <- rbind(
    priors_reality,
    brms::set_prior("normal(0, 1)", class = interactions$class[i], coef = interactions$coef[i], dpar = interactions$dpar[i])
  )
}

m_reality <- brm(formula,
  data = dftask[!is.na(dftask$Reality), ],
  family = choco(), stanvars = choco_stanvars(),
  prior = brms::validate_prior(priors_reality, formula, data = dftask[!is.na(dftask$Reality), ]),
  init = 0,
  chains = chains_per_node,
  cores = chains_per_node,
  threads = threading(threads_per_chain),
  iter = iter,
  warmup = warmup,
  thin = thin,
  seed = seed,
  backend = "cmdstanr",
  file = paste0(path, "Reality_task_", task_id)
)

print("!! REALITY DONE !!")


# ----------------------------
# Authenticity
# ----------------------------


formula <- brms::bf(
  Authenticity ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
  confright ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
  confleft ~ Condition * Emotion + (Condition * Emotion | Participant) + (Condition | Item),
  precright ~ Condition * Emotion + (Condition * Emotion | Participant) + (1 | Item),
  precleft ~ Condition * Emotion + (Condition * Emotion | Participant) + (1 | Item),
  pex ~ Condition + (1 | Participant),
  bex ~ Condition + (1 | Participant),
  pmid ~ Condition + (1 | Participant),
  family = choco()
)

# Tighter priors for interaction
priors_auth <- priors
default_priors <- as.data.frame(brms::get_prior(formula, data = dftask[!is.na(dftask$Authenticity), ]))
interactions <- default_priors[grepl("\\:", default_priors$coef) & default_priors$class == "b", ]
for (i in 1:nrow(interactions)) {
  priors_auth <- rbind(
    priors_auth,
    brms::set_prior("normal(0, 1)", class = interactions$class[i], coef = interactions$coef[i], dpar = interactions$dpar[i])
  )
}

m_reality <- brm(formula,
  data = dftask[!is.na(dftask$Authenticity), ],
  family = choco(), stanvars = choco_stanvars(),
  prior = brms::validate_prior(priors_auth, formula, data = dftask[!is.na(dftask$Authenticity), ]),
  init = 0,
  chains = chains_per_node,
  cores = chains_per_node,
  threads = threading(threads_per_chain),
  iter = iter,
  warmup = warmup,
  thin = thin,
  seed = seed,
  backend = "cmdstanr",
  file = paste0(path, "Authenticity_task_", task_id)
)

print("!! Authenticity DONE !!")


# ----------------------------
# Beauty2
# ----------------------------


formula <- brms::bf(
  Beauty2 ~ Condition + (Condition | Participant) + (Condition | Item),
  confright ~ Condition + (Condition | Participant) + (Condition | Item),
  confleft ~ Condition + (Condition | Participant) + (Condition | Item),
  precright ~ Condition + (1 | Participant) + (1 | Item),
  precleft ~ Condition + (1 | Participant) + (1 | Item),
  pex ~ Condition + (1 | Participant),
  bex ~ Condition + (1 | Participant),
  pmid ~ Condition + (1 | Participant),
  family = choco()
)

# Tighter priors for interactions
priors_beauty2 <- priors
# default_priors <- as.data.frame(brms::get_prior(formula, data = dftask[!is.na(dftask$Beauty2), ]))
# interactions <- default_priors[grepl("\\:", default_priors$coef) & default_priors$class == "b", ]
# for (i in 1:nrow(interactions)) {
#   priors_beauty2 <- rbind(
#     priors_beauty2,
#     brms::set_prior("normal(0, 1)", class = interactions$class[i], coef = interactions$coef[i], dpar = interactions$dpar[i])
#   )
# }

m_beauty2 <- brm(formula,
  data = dftask[!is.na(dftask$Beauty2), ],
  family = choco(), stanvars = choco_stanvars(),
  prior = brms::validate_prior(priors_beauty2, formula, data = dftask[!is.na(dftask$Beauty2), ]),
  init = 0,
  chains = chains_per_node,
  cores = chains_per_node,
  threads = threading(threads_per_chain),
  iter = iter,
  warmup = warmup,
  thin = thin,
  seed = seed,
  backend = "cmdstanr",
  file = paste0(path, "Beauty2_task_", task_id)
)

print("!! BEAUTY2 DONE !!")
