#!/bin/bash
#SBATCH --job-name=fakeart_combine
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --partition=general
#SBATCH --output=combine_%j.out
#SBATCH --error=combine_%j.err
#SBATCH --mail-type=END,FAIL

# One job = one model (FA_MODEL): merge its shards, add loo, keep the shards.
# Not an array.
#
# Memory, not CPU, is the constraint: every shard is read into RAM at once,
# and add_criterion() builds a pointwise log-likelihood matrix of
# draws x responses (6,400 x ~15,500 = ~0.8 GB here) through an R-level
# log_lik for the cogmod families. The custom family's log_lik is not
# parallelised, so extra cores buy nothing and a slim request dispatches
# sooner. 64G is generous for this dataset; the largest shards (Beauty,
# Reality, ~1 GB each on disk) are what it is sized for. No --time: the job
# gets general's 8 h maximum.

PROJECT_DIR="${FA_USERS_DIR:-$SLURM_SUBMIT_DIR}"
export FA_MODELS_DIR="${FA_MODELS_DIR:-$PROJECT_DIR/models}"

cd "$PROJECT_DIR" || exit 1
mkdir -p "$FA_MODELS_DIR/combined"

echo "Running on $(hostname)"
echo "Model: ${FA_MODEL:-<unset>}"
echo "Models directory: $FA_MODELS_DIR"
echo "Job started at: $(date '+%Y-%m-%d %H:%M:%S')"

# SLURM runs this non-interactively, where 'module' is not yet a function.
[ -n "${LMOD_CMD:-}" ] || [ ! -f /etc/profile.d/lmod.sh ] || . /etc/profile.d/lmod.sh

# Compute nodes only get /opt/ohpc/pub/modulefiles; the EasyBuild tree that
# actually holds R/CmdStanR is on the login node's MODULEPATH only.
module use "${FA_EB_MODULES:-/mnt/shared/easybuild/modules/all}"

module load "${FA_R_MODULE:-CmdStanR/0.7.1-foss-2023a-R-4.3.2}"

if [ -n "${FA_R_LIBS:-}" ]; then
  export R_LIBS="${FA_R_LIBS}${R_LIBS:+:$R_LIBS}"
fi

echo "Rscript: $(command -v Rscript)"

Rscript combine_model.R
status=$?

echo "FINISHED at: $(date '+%Y-%m-%d %H:%M:%S') with status $status"
exit $status
