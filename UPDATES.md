# UPDATES.md
**Project:** Video-Reconstruction — Mug to USD Pipeline
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
- Selected test object: white ceramic café mug. Rationale — solid opaque geometry, matte surface with distinct printed texture (good feature points for COLMAP), simple topology (easy to validate), low centre of gravity (stable in simulation).
- Decided to use the professor's recommended tools: FFmpeg for frame extraction, COLMAP for traditional reconstruction, DA3 for the learned reconstruction path. Comparison between the two paths is required.
- Added reconstruction completeness as a fourth evaluation metric alongside mesh quality, visual fidelity, and simulation stability.

**Decisions made:**
- Object: white ceramic café mug (not the originally suggested IKEA plant).
- Pipeline: FFmpeg → COLMAP (Path A) AND FFmpeg → DA3 → SAM3 → HoloScene (Path B), with final comparison.
- Final output format: USD, validated in Isaac Sim 4.2.
- HPC: SLU Libra cluster for DA3 (80 GB VRAM step); all other steps run locally on Windows machine.

**Blockers:**
- HPC access requires VPN; documentation not yet available. Awaiting student to share docs.

---

## 2026-03-27 — Video Capture

**What was done:**
- Performed three orbital passes around the mug with a smartphone camera:
  - Pass 1: Eye-level, full 360°
  - Pass 2: Elevated (~30° downward), full 360°
  - Pass 3: Low angle (~20° upward), full 360°
- Mug was kept stationary throughout; only the camera moved.
- Total video duration: approximately 4 minutes 18 seconds (258 seconds).
- Video resolution: 2K (2560 × 1440), portrait orientation, 30 fps.
- Real-world measurements taken before capture (to be used in scale correction, Stage 8).

**Notes:**
- Capture environment: mug placed on a black notebook on a wooden shelf, against a plain grey-blue wall. Background clutter (bags, desk items) visible to the left of frame. This is noted as a known limitation — background noise is present in the point cloud and will require MeshLab cleanup for Path A. A reshooting session with a cleaner background is planned before running Path B (DA3/HoloScene), where SAM3 masking will handle isolation.
- Lighting was slightly dim with a blue cast at time of capture. Noted as a texture quality concern — does not affect geometry reconstruction.
- Camera orientation was portrait (1440 × 2560 per cameras.txt). Landscape orientation recommended for future reshoots to increase horizontal field of view.

---

## 2026-03-28 — FFmpeg Extraction, COLMAP Reconstruction, Point Cloud Export

**What was done:**

### FFmpeg Frame Extraction
- Automated batch script (`colmap_pipeline.bat`) used for frame extraction and COLMAP pipeline execution.
- Script written, modified and verified against COLMAP 4.0.2:w
.
- Initial extraction rate: 0.5 fps (~129 frames). Later adjusted to 2 fps (~517 frames) for denser coverage.
- Frame output: `frames/frame_000001.jpg` through `frame_000517.jpg`, JPEG quality `-qscale:v 2` (near-lossless).

### Key Script Changes from COLMAP 3.x → 4.0.2
- `--SiftExtraction.use_gpu` → `--FeatureExtraction.use_gpu` (namespace renamed in 4.0)
- `--SiftExtraction.max_image_size` → `--FeatureExtraction.max_image_size`
- `--SequentialMatching.overlap` raised from 15 → 50 (compensates for 2s frame gaps)
- `--Mapper.min_num_matches` lowered from 15 → 10 (allows sparser frame pairs to register)
- `--Mapper.ba_use_gpu 1` added (GPU bundle adjustment, M3000M is CUDA-capable)

### COLMAP Reconstruction
- Feature extraction, sequential matching, and incremental mapping completed successfully.
- **517 cameras registered** out of 517 frames — 100% registration rate.
- Sparse point cloud and camera poses written to `sparse/0/` in binary format.
- Model converted to TXT format via `model_converter` (cameras.txt, images.txt, points3D.txt, frames.txt, rigs.txt).
- Camera model confirmed: `SIMPLE_RADIAL`, 1440×2560, focal length 1838.49px, principal point (720, 1280), radial distortion k1=0.020.

### Warnings Encountered During Mapping
- Repeated `levenberg_marquardt_strategy.cc:123] Linear solver failure. Failed to compute a step: Eigen failure. Unable to perform dense Cholesky factorization.` warnings during bundle adjustment.
- **Assessment:** These are non-fatal warnings produced during early incremental registration when the scene geometry is underconstrained. The LM solver falls back to higher damping and recovers. Warnings ceased as more frames registered. 517/517 registration confirms the mapper completed successfully.

### PLY Export
- `points3D.ply` exported from `sparse/0/` using:
  ```
  colmap.exe model_converter --input_path sparse\0 --output_path sparse\0\points3D.ply --output_type PLY
  ```
- Note: `--output_path` for PLY must be a file path (not a directory). Earlier attempts failed with `ply.cc:381 Check failed: (text_file).is_open()` due to passing a directory path — resolved by appending the filename.
- Note: COLMAP batch syntax (`%VAR%`, `^` line continuation) is CMD-specific and fails in PowerShell. All COLMAP commands run via CMD or `.bat` files.

### Point Cloud Visualisation (Blender 4.0)
- `points3D.ply` imported into Blender using the Reconstruction Collection import workflow.
- 517 animated camera positions visible as expected orbit paths (three elliptical rings corresponding to the three capture passes).
- Point cloud visualisation: mug body clearly visible as a dense central column. Background noise present — table surface, notebook, wooden shelf edges reconstructed alongside the mug.
- Vertex shading set to double-sided and colour-by-vertex for clearer visualisation.

### Point Cloud Cleanup (MeshLab — in progress)
- `points3D.ply` opened in MeshLab.
- Background scatter (notebook surface, blue stool, shelf edges) being removed manually using Select Outliers and Delete Selected tools.
- Mug column geometry clearly separable from background noise.
- Cleanup in progress as of end of session.

**Blockers:**
- HPC VPN access still pending. DA3 stage cannot begin until resolved. Escalation recommended if not resolved by 2026-04-03 (to maintain the April 8 deadline).

**Next session targets:**
- Complete MeshLab point cloud cleanup and export clean mug-only `.ply`.
- Plan and execute reshoot with cleaner capture environment (landscape orientation, no background clutter, daylight lighting).
- Await HPC documentation to prepare DA3 job submission scripts.

---

*This file is updated continuously. Each new working session appends a dated entry below.*
