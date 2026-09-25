# Runs one estimates.R driver on FA_MODELS_DIR/combined/<FA_MODEL>.rds and
# writes FA_MODELS_DIR/<FA_WHAT>/<FA_MODEL>.rds. Read-only on the fit.
#
#   FA_WHAT   estimates (get_estimates(), `./hpc extract`),
#             individual (get_individual(), `./hpc individual`) or
#             loo (get_loo(), `./hpc loo`: the pointwise elpd that combine
#             attached, for comparing two fits of the same rows)
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

what <- Sys.getenv("FA_WHAT", unset = "estimates")
driver <- switch(what, estimates = get_estimates, individual = get_individual, loo = get_loo,
                 stop("FA_WHAT must be 'estimates', 'individual' or 'loo', not '", what, "'", call. = FALSE))

models_dir <- Sys.getenv("FA_MODELS_DIR", unset = "models")
est_dir <- file.path(models_dir, what)
dir.create(est_dir, recursive = TRUE, showWarnings = FALSE)

cat("**", name, "-", what, ":", format(Sys.time()), "\n")
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

est <- driver(m, outcome = name)
est$fit_file <- basename(fit_file)
est$seed <- seed

out <- file.path(est_dir, paste0(name, ".rds"))
saveRDS(est, out, compress = "xz")

cat("** wrote", out, sprintf("(%.1f MB)\n", file.size(out) / 1024^2))
cat("** components:", paste(names(est), collapse = ", "), "\n")
cat(sprintf("** total %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
cat("** finished:", name, "at", format(Sys.time()), "\n")
