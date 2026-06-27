library(brms)
library(cmdstanr)
library(cogmod)

task_id <- as.numeric(Sys.getenv("SLURM_ARRAY_TASK_ID", unset = "1"))
chains_per_task <- as.numeric(Sys.getenv("SLURM_CPUS_PER_TASK", unset = "2"))
start_chain <- (task_id - 1) * chains_per_task + 1
iter <- 600
warmup <- iter / 2
seed <- 1234 + start_chain


path <- "/mnt/lustre/scratch/psych/dmm56/FakeArt/models/"

# ----------------------------
# Data
# ----------------------------


dftask <- read.csv("https://raw.githubusercontent.com/RealityBending/FakeArt/refs/heads/main/data/data_task.csv")
dftask$Condition <- factor(dftask$Condition, levels = c("Human Original", "Human Forgery", "AI-Generated"))

# ----------------------------
# Beauty
# ----------------------------


formula <- brms::bf(
  paste0("Beauty ~ Condition + (1|Participant)"),
  confright ~ Condition,
  confleft ~ Condition,
  precright ~ 1,
  precleft ~ 1,
  pex ~ 1,
  bex ~ 1,
  pmid ~ 1,
  family = choco()
)

priors <- c(
  brms::set_prior("normal(0, 3)", class = "Intercept", dpar = ""),
  brms::set_prior("normal(0, 3)", class = "Intercept", dpar = "confright"),
  brms::set_prior("normal(0, 3)", class = "Intercept", dpar = "confleft"),
  brms::set_prior("normal(0, 3)", class = "Intercept", dpar = "precright"),
  brms::set_prior("normal(0, 3)", class = "Intercept", dpar = "precleft"),
  brms::set_prior("normal(0, 3)", class = "Intercept", dpar = "pex"),
  brms::set_prior("normal(0, 3)", class = "Intercept", dpar = "bex"),
  brms::set_prior("normal(0, 3)", class = "Intercept", dpar = "pmid")
) |>
  brms::validate_prior(formula, data = dftask)

m_choco <- brm(formula,
  data = dftask, family = choco(), stanvars = choco_stanvars(),
  prior = priors, init = 0,
  chains = chains_per_task,
  cores = chains_per_task,
  iter = iter,
  warmup = warmup,
  seed = 1234 + start_chain,
  backend = "cmdstanr",
  file = paste0(path, "Beauty_task_", task_id)
)
