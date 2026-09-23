#!/bin/bash
#SBATCH --job-name=fakeart_extract
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --partition=general
#SBATCH --output=extract_%j.out
#SBATCH --error=extract_%j.err
#SBATCH --mail-type=END,FAIL

# One job per model (FA_MODEL): runs extract_model.R, reading
# models/combined/<model>.rds and writing models/<FA_WHAT>/<model>.rds.
# 128G because MemoryBelief (marginaleffects, 300 contrasts) OOMed at 64G;
# the emmeans models fit in 64G (`--mem=` to override). No --time: general's 8 h.

PROJECT_DIR="${FA_USERS_DIR:-$SLURM_SUBMIT_DIR}"
export FA_MODELS_DIR="${FA_MODELS_DIR:-$PROJECT_DIR/models}"

cd "$PROJECT_DIR" || exit 1
mkdir -p "$FA_MODELS_DIR/${FA_WHAT:-estimates}"

echo "Running on $(hostname)"
echo "Model: ${FA_MODEL:-<unset>} (${FA_WHAT:-estimates})"
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

Rscript extract_model.R
status=$?

echo "FINISHED at: $(date '+%Y-%m-%d %H:%M:%S') with status $status"
exit $status
