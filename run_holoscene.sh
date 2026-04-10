#!/bin/bash
# ============================================================
#  SLURM Job Script — HoloScene
#  SLU Libra HPC | Partition: gpu | GPU: L40s (40GB)
#  Runtime: conda environment da3_env
#
#  Pre-requisites:
#    1. DA3 complete   — transforms.json must exist
#    2. SAM3 complete  — instance_mask/ must have 60 masks
#    3. Submit from login node:
#       sbatch run_holoscene.sh
#
#  Pipeline stages run inside this job:
#    0. Marigold priors (normals + depth)
#    1. Initial reconstruction  (base.conf)
#    2. Post-processing         (post.conf)
#    3. Texture refinement      (tex.conf)
#    4. Gaussian on mesh        (tex.conf)
#    5. Export  →  .glb + .usd + gs .usd
#
#  Output:
#    ~/video2sim-conda/data/output/custom/holoscene_plant/
# ============================================================

#SBATCH --job-name=holoscene_plant
#SBATCH --partition=gpu
#SBATCH --gres=gpu:nvidia_l40s:1
#SBATCH --mem=128gb
#SBATCH --time=12:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --output=holoscene_plant_%j.log

echo "============================================"
echo " HoloScene Job Start: $(date)"
echo " Node: $(hostname)"
echo "============================================"

module load cuda12.8/toolkit/12.8.1

nvidia-smi --query-gpu=name,memory.total --format=csv,noheader

# ── Validate inputs ───────────────────────────────────────────────────────────
TRANSFORMS=~/video2sim-conda/data/input/custom/plant/transforms.json
MASK_DIR=~/video2sim-conda/data/input/custom/plant/instance_mask

if [ ! -f "$TRANSFORMS" ]; then
    echo "ERROR: transforms.json not found. Run DA3 first."
    exit 1
fi

MASK_COUNT=$(ls "$MASK_DIR" 2>/dev/null | wc -l)
if [ "$MASK_COUNT" -eq 0 ]; then
    echo "ERROR: No masks found in instance_mask/. Run SAM3 first."
    exit 1
fi

echo "transforms.json : found"
echo "instance masks  : ${MASK_COUNT} files"
echo "frames          : $(ls ~/video2sim-conda/data/input/custom/plant/images/ | wc -l)"

# ── Environment variables (consumed by hs_process.sh + conf envsubst) ────────
export SCENE_NAME=plant
export DATA_ROOT=/home/crajashekhar/video2sim-conda/data/input/custom
export OUTPUT_ROOT=/home/crajashekhar/video2sim-conda/data/output/custom
export IMG_WIDTH=1280
export IMG_HEIGHT=720
export TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0"
export WANDB_MODE=disabled

# Model cache — reuse the same cache root as SAM3
export HF_HOME=/home/crajashekhar/video2sim-conda/data/cache/holoscene
mkdir -p "$HF_HOME"

# Wonder3D+, LaMa, Omnidata caches (hs_process.sh looks for these under /root/.cache
# but we redirect to our home dir to survive across jobs)
export XDG_CACHE_HOME=/home/crajashekhar/video2sim-conda/data/cache/holoscene

# ── Output directory ──────────────────────────────────────────────────────────
mkdir -p "$OUTPUT_ROOT/holoscene_plant"

echo "SCENE_NAME  : ${SCENE_NAME}"
echo "DATA_ROOT   : ${DATA_ROOT}"
echo "OUTPUT_ROOT : ${OUTPUT_ROOT}"
echo "IMG_WIDTH   : ${IMG_WIDTH}"
echo "IMG_HEIGHT  : ${IMG_HEIGHT}"

# ── Activate conda env ────────────────────────────────────────────────────────
source /home/crajashekhar/.conda/etc/profile.d/conda.sh
conda activate da3_env

# ── Install HoloScene dependencies if not already present ────────────────────
PYTHON=/home/crajashekhar/.conda/envs/da3_env/bin/python3
PIP=/home/crajashekhar/.conda/envs/da3_env/bin/pip

echo "--- Checking HoloScene dependencies ---"
$PYTHON -c "import tinycudann" 2>/dev/null || {
    echo "Installing tinycudann..."
    $PIP install tinycudann \
        --extra-index-url https://pypi.nvidia.com \
        -q
}

$PYTHON -c "import omegaconf" 2>/dev/null || {
    echo "Installing holoscene deps..."
    $PIP install omegaconf pyhocon imageio scikit-image trimesh \
        einops lpips kornia open3d -q
}

# ── Run HoloScene ─────────────────────────────────────────────────────────────
HOLOSCENE_DIR=/home/crajashekhar/video2sim-conda/repo/modules/holoscene

echo "--- Changing to HoloScene app directory ---"
cd "$HOLOSCENE_DIR"

echo "--- Starting hs_process.sh ---"
bash hs_process.sh

EXIT_CODE=$?
echo "============================================"
echo " HoloScene Job End: $(date)"
echo " Exit code: ${EXIT_CODE}"
echo "============================================"

if [ $EXIT_CODE -eq 0 ]; then
    echo "SUCCESS: outputs saved to:"
    echo "  ${OUTPUT_ROOT}/holoscene_plant/"
    echo ""
    echo "USD files produced:"
    find "$OUTPUT_ROOT" -name "*.usd" -o -name "*.usdc" -o -name "*.usda" \
        2>/dev/null | head -20
    echo ""
    echo "GLB files produced:"
    find "$OUTPUT_ROOT" -name "*.glb" 2>/dev/null | head -10
else
    echo "FAILED: Check log above for errors."
fi

exit $EXIT_CODE