#!/bin/bash
#SBATCH --job-name=fakeart_models
#SBATCH --array=1-8
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --output=/mnt/lustre/scratch/psych/dmm56/FakeArt/models_%A_%a.out
#SBATCH --error=/mnt/lustre/scratch/psych/dmm56/FakeArt/models_%A_%a.err
#SBATCH --partition=long

# Have slurm email your SUSSEX email
#SBATCH --mail-user=dmm56@sussex.ac.uk
#SBATCH --mail-type=END,FAIL


# Set working directory
# cd /mnt/lustre/users/psych/dmm56/FakeArt || exit 1

echo "Running on $(hostname)"
echo "Current directory: $(/bin/pwd)"
echo "Job started at: $(date '+%Y-%m-%d %H:%M:%S')"

module load R/4.4.1-gfbf-2023b
Rscript make_models.R $SLURM_ARRAY_TASK_ID

echo "COMPLETED at: $(date '+%Y-%m-%d %H:%M:%S')"