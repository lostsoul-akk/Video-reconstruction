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
- Capture environment: mug placed on a black notebook on a wooden shelf, against a plain grey-blue wall. Background clutter (bags, desk items) visible to the left of frame. This is a known limitation — background noise is present in the point cloud and requires MeshLab cleanup for Path A. A reshooting session with a cleaner background is planned before running Path B (DA3/HoloScene), where SAM3 masking will handle isolation.
- Lighting was slightly dim with a blue cast at time of capture. Noted as a texture quality concern — does not affect geometry reconstruction.
- Camera orientation was portrait (1440 × 2560 per cameras.txt). Landscape orientation recommended for future reshoots.

---

## 2026-03-28 — FFmpeg Extraction, COLMAP Reconstruction, Point Cloud Export

**What was done:**

### FFmpeg Frame Extraction
- Automated batch script (`colmap_pipeline.bat`) used for frame extraction and full COLMAP pipeline execution.
- Script based on original by polyfjord, modified and verified against COLMAP 4.0.2 (commit d927f7e, 2026-03-18).
- Initial extraction rate: 0.5 fps (~129 frames). Adjusted to 2 fps (~517 frames) for denser coverage.
- Frame output: `frames/frame_000001.jpg` through `frame_000517.jpg`, JPEG quality `-qscale:v 2` (near-lossless).

### Key Script Changes from COLMAP 3.x → 4.0.2
- `--SiftExtraction.use_gpu` → `--FeatureExtraction.use_gpu` (namespace renamed in 4.0)
- `--SiftExtraction.max_image_size` → `--FeatureExtraction.max_image_size`
- `--SequentialMatching.overlap` raised 15 → 50 (compensates for wider frame gaps at 2fps)
- `--Mapper.min_num_matches` lowered 15 → 10 (allows sparser frame pairs to register)
- `--Mapper.ba_use_gpu 1` added (GPU bundle adjustment on M3000M)

### COLMAP Reconstruction
- Feature extraction, sequential matching, and incremental mapping completed successfully.
- **517 cameras registered** out of 517 frames — 100% registration rate.
- Sparse point cloud and camera poses written to `sparse/0/` in binary format.
- Model converted to TXT format via `model_converter` (cameras.txt, images.txt, points3D.txt, frames.txt, rigs.txt).
- Camera model: `SIMPLE_RADIAL`, 1440×2560, focal length 1838.49px, principal point (720, 1280), radial distortion k1=0.020.

### Warnings Encountered
- Repeated `levenberg_marquardt_strategy.cc:123] Linear solver failure. Failed to compute a step: Eigen failure. Unable to perform dense Cholesky factorization.` warnings during bundle adjustment.
- **Assessment:** Non-fatal. Produced during early registration when geometry is underconstrained. LM solver recovers via increased damping. 517/517 registration confirms successful completion.

### PLY Export
- `points3D.ply` exported via:
  ```
  colmap.exe model_converter --input_path sparse\0 --output_path sparse\0\points3D.ply --output_type PLY
  ```
- Earlier attempts failed (`ply.cc:381 Could not open path`) — caused by passing a directory instead of a file path to `--output_path`. Resolved by appending the filename.
- COLMAP batch syntax (`%VAR%`, `^`) is CMD-only — fails in PowerShell. All commands run via CMD.

### Visualisation (Blender 4.0)
- Imported into Blender. Three camera orbit rings visible, corresponding to three capture passes. Mug body clear as dense central column. Background noise present (table, notebook, shelf).

**Blockers:**
- HPC VPN access pending.

---

## 2026-03-29 — Point Cloud Cleanup, COLMAP Path A Sparse Baseline Complete

**What was done:**

### Point Cloud Cleanup (MeshLab)
- `points3D.ply` opened in MeshLab.
- Background scatter removed: notebook surface, blue stool, wooden shelf edges, surrounding clutter deleted using Select Outliers and Delete Selected tools.
- Mug body successfully isolated as a clean central column.
- Thin base scatter (contact geometry directly under mug) retained as surface reference.

### Observations from Cleaned Point Cloud
- **Mug body:** Cylindrical form with correct taper clearly reconstructed.
- **Handle:** Absent from sparse reconstruction — expected. Handle inner arch is a concave surface not well captured by orbiting SfM. Will appear in dense reconstruction and DA3/HoloScene paths.
- **Top rim:** Slightly thin — expected for circular rim geometry in sparse SfM.
- **Camera trajectory:** Three clean elliptical orbit rings confirm good capture coverage.

### Export
- Cleaned point cloud saved as `points3D_clean.ply` in `sparse/0/`.
- This is the **COLMAP Path A sparse baseline** for the final comparison.

### Documentation
- `README.md` written — covers full pipeline end-to-end, all 10 stages, comparison table, evaluation metrics, hardware, repo structure, and references.
- `UPDATES.md` started — this file. Both ready to push to repo.

**Status at end of session:**

| Stage | Status |
|---|---|
| Video capture | ✅ Complete |
| FFmpeg extraction | ✅ Complete (517 frames at 2fps) |
| COLMAP sparse reconstruction | ✅ Complete (517/517 cameras registered) |
| Point cloud cleanup | ✅ Complete (`points3D_clean.ply`) |
| COLMAP dense reconstruction | Pending reshoot |
| DA3 (Path B) | 🔴 Blocked — HPC VPN pending |
| SAM3 + HoloScene | ⬜ Not started |
| Scale correction + physics params | ⬜ Not started |
| Isaac Sim validation | ⬜ Not started |
| Comparison + final docs | ⬜ Not started |

**Next session targets:**
- Reshoot mug (landscape orientation, daylight, clean background)
- Push README.md and UPDATES.md to repo
- Obtain HPC VPN access and Libra documentation
- Prepare DA3 job submission script for HPC

**Blockers:**
- HPC VPN access still pending. If unresolved by 2026-04-03, escalate to professor — April 8 deadline at risk.

---

*This file is updated continuously. Each new working session appends a dated entry below.*