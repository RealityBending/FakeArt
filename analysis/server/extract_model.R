# Runs get_estimates() (estimates.R) on FA_MODELS_DIR/combined/<FA_MODEL>.rds
# and writes FA_MODELS_DIR/estimates/<FA_MODEL>.rds. Submitted by
# `./hpc extract <model>`; read-only on the fit, so safe to re-run.
#
#   FA_SEED   RNG seed for the sampled parts (default 1234)

library(brms)
library(cmdstanr)
library(cogmod) # attached: posterior_epred_cogmod_<family>() is resolved from it
library(dplyr)
library(modelbased)

options(mc.cores = as.numeric(Sys.getenv("SLURM_CPUS_PER_TASK", unset = "2")))

source("models.R")
source("estimates.R")

spec <- fa_model(Sys.getenv("FA_MODEL", unset = ""))
name <- spec$name

seed <- as.integer(Sys.getenv("FA_SEED", unset = "1234"))
set.seed(seed)

models_dir <- Sys.getenv("FA_MODELS_DIR", unset = "models")
est_dir <- file.path(models_dir, "estimates")
dir.create(est_dir, recursive = TRUE, showWarnings = FALSE)

cat("**", name, ":", format(Sys.time()), "\n")
cat("** seed:", seed, "\n")

# Combined fit, else a hand-placed <model>.rds (never a shard)
candidates <- c(
  file.path(models_dir, "combined", paste0(name, ".rds")),
  file.path(models_dir, paste0(name, ".rds"))
)
fit_file <- candidates[file.exists(candidates)][1]
if (is.na(fit_file)) {
  stop("no fit found for ", name, " -- looked for ",
       paste(candidates, collapse = " and "), call. = FALSE)
}
cat("** reading", fit_file, "\n")

t0 <- Sys.time()
m <- readRDS(fit_file)
cat(sprintf("** loaded in %.1f min: %d chains x %d draws, %d rows\n",
            as.numeric(difftime(Sys.time(), t0, units = "mins")),
            brms::nchains(m), brms::ndraws(m), nrow(m$data)))

# A combine that lost a shard still looks fine downstream
if (brms::ndraws(m) < 1000) {
  stop("only ", brms::ndraws(m), " draws in ", fit_file,
       " -- combine probably lost a shard; re-run ./hpc combine ", name,
       call. = FALSE)
}

est <- get_estimates(m, outcome = name)
est$fit_file <- basename(fit_file)
est$seed <- seed

out <- file.path(est_dir, paste0(name, ".rds"))
saveRDS(est, out, compress = "xz")

cat("** wrote", out, sprintf("(%.1f MB)\n", file.size(out) / 1024^2))
cat("** components:", paste(names(est), collapse = ", "), "\n")
cat(sprintf("** total %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
cat("** finished:", name, "at", format(Sys.time()), "\n")
