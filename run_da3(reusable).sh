#!/bin/bash
#SBATCH --job-name=da3_plant
#SBATCH --partition=machinelearning
#SBATCH --gres=gpu:nvidia_h100_nvl:1
#SBATCH --mem=64gb
#SBATCH --time=08:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --output=da3_plant_%j.log

module load cuda12.8/toolkit/12.8.1

nvidia-smi --query-gpu=name,memory.total --format=csv,noheader

mkdir -p ~/video2sim-tree1/data/output/custom/plant/da3_out
mkdir -p ~/video2sim-tree1/data/cache/da3

export SCENE_NAME=plant
export DATA_ROOT=/home/$USER/video2sim-tree1/data/input/custom
export OUTPUT_ROOT=/home/$USER/video2sim-tree1/data/output/custom
export TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0"
export HF_HOME=/home/$USER/video2sim-tree1/data/cache/da3
export HF_TOKEN="${HF_TOKEN}"

echo "HF_TOKEN set: $([ -n "$HF_TOKEN" ] && echo YES || echo NO)"
echo "Starting DA3 inference..."

/home/$USER/.conda/envs/da3_env/bin/python3 \
  /home/$USER/video2sim-tree1/repo/modules/da3/da3_process.py

EXIT_CODE=$?
[ $EXIT_CODE -eq 0 ] && echo "SUCCESS: transforms.json written." || echo "FAILED."
exit $EXIT_CODE