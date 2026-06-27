library(brms)
library(cmdstanr)
library(rstan)
library(loo)


# Get the number of cores and task ID from the environment variables
options(mc.cores = as.numeric(Sys.getenv("SLURM_CPUS_PER_TASK")))
task_id <- as.numeric(Sys.getenv("SLURM_ARRAY_TASK_ID"))

setwd("/mnt/lustre/users/psych/dmm56/FictionChoco/")

# List of models
model_names <- c("sample1_zoib", "sample1_betagate", "sample1_choco",
                 "sample1_chocoattractiveness", "sample1_chocobeauty",
                 "sample2_chocoattractiveness", "sample2_betagate",
                 "sample2noex_betagate", "sample2noex_chocoattractiveness", "sample2noex_chocobeauty")[4:10]

# Select the model name based on the task ID
model_name <- model_names[task_id]

combine_and_save <- function(name) {
  print(paste0(name, ": ", Sys.time()))
  files <- list.files(".", pattern = paste0(name, '_.*rds$'), full.names = TRUE)
  m <- brms::combine_models(mlist = lapply(files, readRDS))

  # Add criterion and save
  m <- brms::add_criterion(m, "waic", ndraws = 1500, file = name)

  # saveRDS(m, paste0(name, ".rds"))
}

combine_and_save(model_name)
print(paste0("Completed: ", Sys.time()))
