# =========================================================================
# Combine the shards of ONE model into a single fit
# =========================================================================
# fit_model.R runs as an array; shard N writes <model>_N.rds into
# FA_MODELS_DIR. This merges all of one model's shards into
# FA_MODELS_DIR/combined/<model>.rds and adds a criterion. Which model is
# FA_MODEL. Submitted by `./hpc combine <model>`.
#
#   FA_CRITERION         "loo" (default), "waic", or "none"
#   FA_CRITERION_NDRAWS  a draw count, or unset / "all" (default) for all
#   FA_DELETE_SHARDS     set to 1 to remove the shards once combined
#
# Shards are kept by default: a combined fit is minutes to rebuild from them
# (a different criterion, a re-run after a cogmod change) and each shard is
# hours of compute. The hazard that keeping them opens: fit_model.R uses
# file_refit = "never", so a shard left on disk is silently reused even when
# the formula or the data changed. Give a changed parametrisation its own
# FA_MODELS_DIR, or pass FA_FILE_REFIT=always.
#
# The combined file lands in analysis/models/<model>.rds after `./hpc pull`,
# which is where 3_models.qmd reads it.

library(brms)
library(cmdstanr)
# cogmod is needed here too, not just to fit: add_criterion() calls log_lik(),
# which for a custom family resolves log_lik_cogmod_<family>().
library(cogmod)
library(loo)

options(mc.cores = as.numeric(Sys.getenv("SLURM_CPUS_PER_TASK", unset = "2")))

source("models.R")

spec <- fa_model(Sys.getenv("FA_MODEL", unset = ""))
name <- spec$name

models_dir <- Sys.getenv("FA_MODELS_DIR", unset = "models")
combined_dir <- file.path(models_dir, "combined")
dir.create(combined_dir, recursive = TRUE, showWarnings = FALSE)

cat("**", name, ":", format(Sys.time()), "\n")

# Shards are named <model>_<shard>.rds, e.g. Beauty_3.rds. The anchor matters:
# "Beauty" must not also collect "Beauty2".
pattern <- paste0("^", name, "_[0-9]+[.]rds$")
files <- list.files(models_dir, pattern = pattern, full.names = TRUE)
cat("** found", length(files), "shards in", models_dir, "\n")
if (length(files) == 0) {
  stop("no shards matching ", pattern, " in ", models_dir)
}

# A shard was written by brm(file = ...), so it carries that path in $file --
# and add_criterion() writes the fit back there when it does. combine_models()
# keeps the first shard's $file, so without this the combined fit would be
# silently saved *over shard 1*. Drop the slot on the way in.
read_shard <- function(f) {
  fit <- readRDS(f)
  fit$file <- NULL
  fit
}

criterion <- tolower(Sys.getenv("FA_CRITERION", unset = "loo"))
crit_ndraws <- Sys.getenv("FA_CRITERION_NDRAWS", unset = "")

out <- file.path(combined_dir, paste0(name, ".rds"))
m <- brms::combine_models(mlist = lapply(files, read_shard))
m$file <- NULL
if (identical(criterion, "none")) {
  cat("** FA_CRITERION=none, no criterion added\n")
} else {
  t0 <- Sys.time()
  if (nzchar(crit_ndraws) && !identical(tolower(crit_ndraws), "all")) {
    # Subsampling: cap at what the fit has. add_criterion() errors outright
    # above it, which a short test run or a part-finished array would hit.
    nd <- max(1L, min(as.integer(crit_ndraws), brms::ndraws(m)))
    m <- brms::add_criterion(m, criterion, ndraws = nd)
  } else {
    # No ndraws argument at all: that keeps the draws in their chains, which
    # is what loo's r_eff needs to discount autocorrelation.
    nd <- brms::ndraws(m)
    m <- brms::add_criterion(m, criterion)
  }
  cat(sprintf("** %s over %d draws in %.1f min\n", criterion, nd,
              as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
saveRDS(m, out)
cat("** wrote", out, "with", brms::ndraws(m), "draws\n")


# Shards are kept unless deletion is asked for, and then only once the
# combined fit is on disk and reads back.
if (!nzchar(Sys.getenv("FA_DELETE_SHARDS", unset = ""))) {
  cat("** keeping", length(files), "shards (set FA_DELETE_SHARDS=1 to drop)\n")
} else {
  readable <- tryCatch(
    {
      chk <- readRDS(out)
      inherits(chk, "brmsfit") && brms::ndraws(chk) > 0
    },
    error = function(e) FALSE
  )
  if (isTRUE(readable)) {
    removed <- file.remove(files)
    cat("** removed", sum(removed), "of", length(files), "shards\n")
  } else {
    warning("combined fit at ", out, " did not read back; keeping shards")
  }
}

cat("** finished:", name, "at", format(Sys.time()), "\n")
