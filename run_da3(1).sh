#!/bin/bash
#SBATCH --job-name=da3_plant
#SBATCH --partition=machinelearning
#SBATCH --gres=gpu:nvidia_h100_nvl:1
#SBATCH --mem=64gb
#SBATCH --time=08:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --output=%x_%j.log

echo "=== DA3 Job Start: $(date) ==="
echo "Node: $(hostname)"
echo "GPU: $(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader)"

module load singularityce/4.1.0-gcc-13.1.0-6uu5j
module load cuda12.8/toolkit/12.8.1

singularity exec --nv \
  --bind ~/video2sim/data:/workspace/data \
  ~/video2sim/da3.sif \
  bash /workspace/data/run_da3_inner.sh

echo "=== DA3 Job End: $(date) ==="