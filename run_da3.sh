#!/bin/bash
# ============================================================
#  SLURM Job Script — DA3 (Depth Anything 3)
#  SLU Libra HPC | Partition: machinelearning | GPU: H100 NVL
#  Runtime: conda environment (no Singularity)
#
#  Pre-requisites:
#    1. conda env 'da3' created and DA3 installed (see README)
#    2. HF_TOKEN exported in shell before sbatch:
#       export HF_TOKEN=hf_xxx && sbatch run_da3.sh
#
#  Monitor:
#    squeue -u $USER
#    tail -f da3_plant_<jobid>.log
#
#  Output:
#    ~/video2sim/data/input/custom/plant/transforms.json
# ============================================================

#SBATCH --job-name=da3_plant
#SBATCH --partition=machinelearning
#SBATCH --gres=gpu:nvidia_h100_nvl:1
#SBATCH --mem=64gb
#SBATCH --time=08:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --output=da3_plant_%j.log

echo "============================================"
echo " DA3 Job Start: $(date)"
echo " Node: $(hostname)"
echo "============================================"

# Load modules
module load anaconda/3
module load cuda12.8/toolkit/12.8.1

# Activate conda environment
source activate da3

# Confirm GPU visibility
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader

# Confirm frames exist
FRAME_COUNT=$(ls ~/video2sim/data/input/custom/plant/images/ | wc -l)
echo "Frames found: ${FRAME_COUNT}"
if [ "$FRAME_COUNT" -eq 0 ]; then
    echo "ERROR: No frames found. Exiting."
    exit 1
fi

# Create output directories
mkdir -p ~/video2sim/data/output/custom/plant/da3_out
mkdir -p ~/video2sim/data/cache/da3

# Set environment variables
export SCENE_NAME=plant
export DATA_ROOT=~/video2sim/data/input/custom
export OUTPUT_ROOT=~/video2sim/data/output/custom
export TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0"
export HF_HOME=~/video2sim/data/cache/da3

# Run DA3
echo "Starting DA3 inference..."
python3 ~/video2sim/repo/modules/da3/da3_process.py

EXIT_CODE=$?
echo "============================================"
echo " DA3 Job End: $(date)"
echo " Exit code: ${EXIT_CODE}"
echo "============================================"

if [ $EXIT_CODE -eq 0 ]; then
    echo "SUCCESS: transforms.json written to:"
    echo "  ~/video2sim/data/input/custom/plant/transforms.json"
else
    echo "FAILED: Check log above for errors."
fi

exit $EXIT_CODE