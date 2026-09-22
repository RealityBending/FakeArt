# =========================================================================
# Fit ONE model, as one shard of an array job
# =========================================================================
# Which model is FA_MODEL (see models.R); which shard is SLURM_ARRAY_TASK_ID.
# Each shard writes <model>_<shard>.rds into FA_MODELS_DIR and combine_model.R
# merges them into combined/<model>.rds. Submitted by `./hpc fit <model>`.
#
# Run-shaping variables (all forwarded by ./hpc when set):
#   FA_WARMUP          warmup iterations per chain          (default 1000)
#   FA_SAMPLES         post-warmup iterations per chain     (default 500)
#   FA_THIN            keep every n-th draw                 (default 1)
#   FA_CHAINS          chains per array task                (default 2)
#   FA_NPARTICIPANTS   subset for smoke tests, or "all"     (default all)
#   FA_FILE_REFIT      "never" (resume) or "always"         (default never)
#   FA_DATA            "github" or a local directory        (default github)
#
# The defaults match IllusionGameComputational: 4 shards x 2 chains x 500 =
# 8 chains and 4,000 draws per model, unthinned. They replace the July 2026
# settings (warmup 5,000, 800 samples, thin 2, 8 shards -> 6,400 draws), whose
# measured wall times are in AGENT.md 3.2. Warmup was 88-94% of every chain's
# time there, and IGC 4.4.1 measured ESS per draw to be flat from warmup 200 to
# 1000, so the extra 4,000 warmup iterations bought nothing.

library(brms)
library(cogmod) # remotes::install_github("DominiqueMakowski/cogmod")

# The formulas use the cogmod_*() constructors introduced in 0.3, and
# fa_priors()/fa_inits() rely on cogmod_priors()/cogmod_inits() covering
# cogmod_choco and cogmod_betadiscrete, which landed on the dev branch on
# 2026-09-20 at version 0.3.3 (commit d04c7f8). An older 0.3.3 build passes
# this version check but fails in fa_inits() with "has nothing to offer for
# family"; the fix for both is `./hpc install cogmod`.
cogmod_min <- Sys.getenv("FA_COGMOD_MIN", unset = "0.3.3")
if (utils::packageVersion("cogmod") < cogmod_min) {
  stop("cogmod ", utils::packageVersion("cogmod"), " is too old; need >= ", cogmod_min,
       ". Run  ./hpc install cogmod", call. = FALSE)
}

source("models.R")

spec <- fa_model(Sys.getenv("FA_MODEL", unset = ""))

task_id <- as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID", unset = "1"))
total_cores <- as.numeric(Sys.getenv("SLURM_CPUS_PER_TASK", unset = "2"))

# Chains per array task. Each chain is a separate process with its own copy of
# the data and AD stack, so this drives per-task memory; threading takes the
# remaining cores. 16 cores / 2 chains = 8 threads per chain.
chains_per_task <- as.integer(Sys.getenv("FA_CHAINS", unset = "2"))
threads_per_chain <- total_cores / chains_per_task

models_dir <- Sys.getenv("FA_MODELS_DIR", unset = "models")
dir.create(models_dir, recursive = TRUE, showWarnings = FALSE)

# "never" makes a resubmitted array skip shards whose .rds already exists, so a
# job killed at the wall resumes instead of restarting. The catch is that a
# stale shard is reused silently even if the formula or data changed -- give a
# changed model its own FA_MODELS_DIR, or force a clean refit with
#   FA_FILE_REFIT=always ./hpc fit <model>
file_refit <- Sys.getenv("FA_FILE_REFIT", unset = "never")

warmup <- as.integer(Sys.getenv("FA_WARMUP", unset = "1000"))
samples <- as.integer(Sys.getenv("FA_SAMPLES", unset = "500"))
thin <- as.integer(Sys.getenv("FA_THIN", unset = "1"))
iter <- warmup + samples
seed <- 1234 + task_id # distinct per shard, reproducible per shard

cat(sprintf(
  "config: model=%s outcome=%s data=%s shard=%d warmup=%d samples=%d thin=%d chains=%d threads/chain=%g refit=%s\n",
  spec$name, spec$outcome, spec$data, task_id, warmup, samples, thin,
  chains_per_task, threads_per_chain, file_refit
))


# Data --------------------------------------------------------------------
# Default is straight from GitHub (the compute nodes have outbound internet, so
# nothing but code needs pushing) -- which means the cluster fits whatever is
# on `main`, not the local working copy. Commit and push the data first.
# FA_DATA=<dir> reads the CSVs from a local directory instead (smoke tests on
# a laptop).
#
# Which file depends on the model's `data` slot (models.R): "task" is the
# Phase-1 trial file with the gaze features merged on; "memory" is the
# follow-up file, one row per old *or new* item shown in the memory session.

data_src <- Sys.getenv("FA_DATA", unset = "github")
if (identical(tolower(data_src), "github")) {
  base <- "https://raw.githubusercontent.com/RealityBending/FakeArt/refs/heads/main/data/"
} else {
  base <- paste0(sub("/+$", "", data_src), "/")
}
if (identical(spec$data, "memory")) {
  dftask <- fa_prepare_memory(read.csv(paste0(base, "data_memory_task.csv")))
} else {
  dftask <- merge(
    read.csv(paste0(base, "data_task.csv")),
    read.csv(paste0(base, "data_eyetracking.csv")),
    all.x = TRUE
  )
  dftask <- fa_prepare_data(dftask)
}

# Subset size. Production is "all"; FA_NPARTICIPANTS=20 for a smoke test.
n_participants <- Sys.getenv("FA_NPARTICIPANTS", unset = "all")
if (!identical(tolower(n_participants), "all")) {
  keep <- unique(dftask$Participant)[seq_len(as.integer(n_participants))]
  dftask <- dftask[dftask$Participant %in% keep, ]
}

# Each model uses the rows where its outcome is observed (Phase 2 dropped for
# 7 participants, follow-up only for 220, gaze only for QC-passing trials;
# the memory file has no NA in its categorical outcomes, so it is kept whole).
data <- dftask[!is.na(dftask[[spec$outcome]]), ]
cat("participants:", length(unique(data$Participant)), " items:", length(unique(data$Item)),
    " rows:", nrow(data), "\n")


# Fit ---------------------------------------------------------------------

f <- spec$formula()
priors <- spec$priors(f, data)

# cogmod families need their Stan functions (stanvars) and take cogmod's
# data-informed starting values; native families keep init = 0 -- see
# fa_stanvars() / fa_inits() in models.R.
stanvars <- fa_stanvars(f)
init <- fa_inits(f, data)

# One-line summary per shard so runs can be compared from the .out logs alone
# (grep REPORT). See README.md, "How to check job status".
report_fit <- function(m, name, wall_min) {
  np <- brms::nuts_params(m) # post-warmup draws only
  stat <- vapply(split(np$Value, np$Parameter), mean, numeric(1))
  rh <- brms::rhat(m)
  ne <- brms::neff_ratio(m)
  cat(sprintf(
    "REPORT %s | wall %.1f min | n_leapfrog %.0f | treedepth %.2f | stepsize %.3g | divergent %.3f | accept %.2f | max Rhat %.3f | min neff_ratio %.3f | n params %d\n",
    name, wall_min, stat[["n_leapfrog__"]], stat[["treedepth__"]], stat[["stepsize__"]],
    stat[["divergent__"]], stat[["accept_stat__"]], max(rh, na.rm = TRUE),
    min(ne, na.rm = TRUE), length(rh)
  ))
  md <- attr(m$fit, "metadata")
  if (!is.null(md$time)) {
    cat("REPORT time per chain (s):\n")
    print(md$time)
  }
  invisible(stat)
}

t0 <- Sys.time()
m <- brm(f,
  data = data,
  prior = priors,
  init = init,
  stanvars = stanvars,
  backend = "cmdstanr",
  warmup = warmup,
  iter = iter,
  thin = thin,
  chains = chains_per_task,
  cores = chains_per_task,
  threads = threading(threads_per_chain),
  control = list(adapt_delta = 0.90),
  seed = seed,
  # Must match precompile.R's cpp_options exactly, or a cold array races to
  # build a second precompiled-header variant (see README, "Precompile").
  stan_model_args = list(
    stanc_options = list("O1"),
    cpp_options = list(STAN_CPP_OPTIMS = TRUE, STAN_NO_RANGE_CHECKS = TRUE)
  ),
  file = file.path(models_dir, sprintf("%s_%d.rds", spec$name, task_id)),
  file_refit = file_refit
)
wall_min <- as.numeric(difftime(Sys.time(), t0, units = "mins"))

cat(spec$name, "shard", task_id, ": SUCCESSFUL.\n")
tryCatch(report_fit(m, spec$name, wall_min),
  error = function(e) cat("REPORT failed:", conditionMessage(e), "\n")
)
