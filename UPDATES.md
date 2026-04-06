# UPDATES.md
**Project:** Video-Reconstruction — Mug to USD Pipeline (Object: Potted Succulent Plant)
**Author:** Augustine Kinyanzui
**Repo:** [lostsoul-akk/Video-reconstruction](https://github.com/lostsoul-akk/Video-reconstruction)

This file is a chronological log of all work done on the project. Each entry records what was done, what decisions were made, what problems were encountered, and what was resolved. It is updated at the end of each working session.

---

## 2026-03-26 — Project Initiation & Object Selection

**What was done:**
- Reviewed the client-provided pipeline reference: [9LogM/Video2Sim](https://github.com/9LogM/Video2Sim).
- Conducted a feasibility assessment of the full pipeline (FFmpeg → COLMAP → DA3 → SAM3 → HoloScene → Isaac Sim → USD).
- Confirmed pipeline viability: HoloScene's scene graph supports object-level isolation; physical property estimation is built into HoloScene's energy-based optimisation; Isaac Sim 4.2 is the confirmed simulator target; USD is the native output format.
- Identified the primary hardware constraint: DA3 requires 80 GB VRAM, exceeding local GPU capacity (Quadro M3000M, 4 GB). Resolved via SLU Libra HPC cluster access (ticket raised by Chandana Rajashekhar, last modified by Lucas Guffey on 2026-02-04).
- Initial object selection: white ceramic café mug.
- Decided to use the professor's recommended tools: FFmpeg for frame extraction, COLMAP for traditional reconstruction, DA3 for the learned reconstruction path. Comparison between the two paths is required.
- Added reconstruction completeness as a fourth evaluation metric alongside mesh quality, visual fidelity, and simulation stability.

**Decisions made:**
- Pipeline: FFmpeg → COLMAP (Path A) AND FFmpeg → DA3 → SAM3 → HoloScene (Path B), with final comparison.
- Final output format: USD, validated in Isaac Sim 4.2.
- HPC: SLU Libra cluster for DA3 and HoloScene; all other steps run locally on Windows machine.

**Blockers:**
- HPC access requires VPN; documentation not yet available.

---

## 2026-03-27 — Video Capture (Mug)

**What was done:**
- Performed three orbital passes around the mug with a smartphone camera (eye-level, elevated ~30°, low ~20°).
- Total video duration: ~4 minutes 18 seconds. Resolution: 2K (2560×1440), portrait, 30fps.
- Real-world measurements taken before capture for use in scale correction.

**Notes:**
- Capture environment had background clutter — noted as a known limitation for COLMAP path.
- Lighting dim with blue cast — texture quality concern, does not affect geometry.
- Portrait orientation noted; landscape recommended for future shoots.

---

## 2026-03-28 — FFmpeg Extraction, COLMAP Reconstruction, Point Cloud Export

**What was done:**

### FFmpeg Frame Extraction
- Automated batch script (`colmap_pipeline.bat`) used, modified from polyfjord's original, verified against COLMAP 4.0.2 (commit d927f7e).
- Extraction rate adjusted from 0.5fps to 2fps → ~517 frames extracted.

### Key COLMAP 4.0.2 Flag Changes
- `--SiftExtraction.*` → `--FeatureExtraction.*` (namespace renamed in 4.0)
- `--SequentialMatching.overlap` raised 15 → 50
- `--Mapper.min_num_matches` lowered 15 → 10
- `--Mapper.ba_use_gpu 1` added

### COLMAP Reconstruction
- **517/517 cameras registered** — 100% registration rate.
- Sparse point cloud and camera poses written to `sparse/0/`.
- Camera model: `SIMPLE_RADIAL`, 1440×2560, focal length 1838.49px.
- Non-fatal Levenberg-Marquardt Cholesky warnings during early bundle adjustment — resolved automatically as frames registered.

### PLY Export
- `points3D.ply` exported via `model_converter`.
- Error encountered: `--output_path` must be a file path, not a directory — resolved by appending filename.
- COLMAP batch syntax is CMD-only — fails in PowerShell.

### Visualisation
- Imported into Blender 4.0. Three clean camera orbit rings visible. Mug body clear as dense central column. Background noise present.

---

## 2026-03-29 — Point Cloud Cleanup, COLMAP Path A Sparse Baseline Complete

**What was done:**

### Point Cloud Cleanup (MeshLab)
- Background scatter removed — notebook, stool, shelf edges deleted.
- Mug body isolated as clean central column.
- Handle absent from sparse reconstruction — expected limitation of SfM on concave surfaces.
- Top rim slightly thin — expected for sparse SfM.
- Cleaned point cloud exported as `points3D_clean.ply`.

### Documentation
- `README.md` and `UPDATES.md` written and ready to push to repo.

**Status at end of session:**

| Stage | Status |
|---|---|
| Video capture (mug) | ✅ Complete |
| FFmpeg extraction | ✅ Complete (517 frames at 2fps) |
| COLMAP sparse reconstruction | ✅ Complete (517/517 cameras) |
| Point cloud cleanup | ✅ Complete (`points3D_clean.ply`) |
| COLMAP dense reconstruction | Pending reshoot |
| DA3 (Path B) | 🔴 Blocked — HPC VPN pending |

---

## 2026-04-05 — Object Change, HPC Access, Environment Setup, DA3 Attempt

**What was done:**

### Object Change
- Object changed from white ceramic mug to a small potted succulent plant. Decision made by project team.
- COLMAP sparse reconstruction of plant completed locally. Point cloud imported into Blender — pot body and succulent leaves clearly reconstructed. Bottom of pot absent due to no downward-angled capture pass — noted as known limitation.

### HPC Access
- VPN access obtained. SLU Libra HPC documentation reviewed (onboarding slides).
- Cluster specs confirmed: ML nodes have 4× Nvidia H100 NVL (80GB VRAM each) — target for DA3. GPU nodes have 2× Nvidia L40s (40GB) — target for SAM3 and HoloScene.
- Singularity CE 4.1.0 and CUDA 12.8 toolkit available as modules.
- Home directory quota: 247TB total, 145TB available — no storage concerns.

### Environment Setup
- Singularity build attempted for DA3 Docker image — failed. `fakeroot` not enabled for user account; admin ticket submitted.
- Sandbox build also failed — requires root or proot.
- **Resolution:** Switched to conda-based approach. Created `~/video2sim-conda/` as working directory (separate from `~/video2sim/` which is preserved for future Singularity attempt).
- Conda environment `da3_env` created with Python 3.11.
- DA3 (Depth Anything 3) cloned into `~/video2sim-conda/da3_src/` and installed into `da3_env`.
- Video2Sim repo cloned into `~/video2sim-conda/repo/`.
- 120 frames uploaded to `~/video2sim-conda/data/input/custom/plant/images/` via Open OnDemand.
- Directory structure configured to match `.env` expectations: `DATA_ROOT=/data/input/custom`, `SCENE_NAME=plant`.

### DA3 Job Attempts (Multiple)
- **Job 104302:** Failed — `ModuleNotFoundError: No module named 'torch'`. `source activate` does not propagate into SLURM batch jobs. Fixed by calling conda env Python directly via full path.
- **Job 104303:** Failed — `cuDNN Frontend error: No valid execution plans built`. Root cause: PyTorch 2.7.0+cu126 installed on system running CUDA 12.8 — cuDNN version mismatch.
- **Jobs 104304–104394:** Multiple failed attempts patching `attention.py` in the installed DA3 package. Approaches tried: `fused_attn=False` (caused OOM — 334GB needed for naive attention on 120 frames), `sdp_kernel` wrapper (caused syntax errors from accumulated patch attempts, then NameError), direct file replacement (missing class parameters). Each fix introduced new issues.
- **Resolution:** Reinstalled PyTorch for correct CUDA version: `torch==2.7.0+cu128`. Reinstalled DA3 from source. Added `import torch` to `attention.py` top (one-line fix). Added `torch.backends.cuda.enable_cudnn_sdp(False)` to `da3_process.py`.

---

## 2026-04-06 — DA3 Complete, SAM3 Setup and Submission

**What was done:**

### DA3 — Final Resolution and Completion
- `torchvision` reinstalled for cu128 to resolve `operator torchvision::nms does not exist` error after PyTorch upgrade.
- numpy downgraded to `<2` to satisfy DA3 dependency.
- **Job 104406: DA3 COMPLETED SUCCESSFULLY.**
  - Node: `ml01` (H100 NVL, 95,830 MiB VRAM)
  - Inference time: ~10 seconds for 120 frames
  - Output: `transforms.json` (101KB) written to `~/video2sim-conda/data/input/custom/plant/`
  - Bonus output: `scene.glb` (16MB) and `scene.jpg` (47KB) in `da3_out/`

### SAM3 Setup
- SAM3 dependencies installed into `da3_env`: `einops`, `decord`, `pycocotools`, `psutil`, `accelerate`, `kernels`, `transformers` (from HuggingFace main).
- SAM3 source cloned into `~/video2sim-conda/sam3_src/` and installed.
- `prompts.txt` created at `~/video2sim-conda/data/input/custom/plant/prompts.txt`:
  ```
  potted plant
  succulent plant
  plant pot
  ```
- SLURM job script `run_sam3.sh` written targeting `gpu` partition (L40s, 40GB VRAM).
- **Job 104409: SAM3 submitted — pending in queue (Priority).**

**Current environment state:**

| Component | Location |
|---|---|
| Working directory | `~/video2sim-conda/` |
| Conda env | `~/.conda/envs/da3_env/` (Python 3.11, torch 2.7.0+cu128) |
| Video2Sim repo | `~/video2sim-conda/repo/` |
| DA3 source | `~/video2sim-conda/da3_src/` |
| SAM3 source | `~/video2sim-conda/sam3_src/` |
| Input frames | `~/video2sim-conda/data/input/custom/plant/images/` (120 frames) |
| transforms.json | `~/video2sim-conda/data/input/custom/plant/transforms.json` ✅ |
| Instance masks | `~/video2sim-conda/data/input/custom/plant/instance_mask/` (pending SAM3) |

**Status at end of session:**

| Stage | Status |
|---|---|
| Video capture (plant) | ✅ Complete |
| FFmpeg extraction | ✅ Complete (120 frames) |
| COLMAP sparse reconstruction | ✅ Complete |
| Point cloud cleanup | ✅ Complete |
| DA3 inference | ✅ Complete (Job 104406) |
| SAM3 masking | 🔄 Submitted, pending queue |
| HoloScene reconstruction | ⬜ Not started |
| Scale correction + physics | ⬜ Not started |
| Isaac Sim validation | ⬜ Not started |
| Comparison + documentation | ⬜ Not started |

**Next session targets:**
- Confirm SAM3 job 104409 result
- If SAM3 successful: submit HoloScene job
- If SAM3 failed: debug and resubmit
- Begin HoloScene configuration (`base.conf`, `post.conf`, `tex.conf`)

---

*This file is updated continuously. Each new working session appends a dated entry below.*