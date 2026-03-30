# Video-Reconstruction
**Author:** Augustine Kinyanzui
**Repo:** [lostsoul-akk/Video-reconstruction](https://github.com/lostsoul-akk/Video-reconstruction)
**Pipeline reference:** [9LogM/Video2Sim](https://github.com/9LogM/Video2Sim)

---

## Overview

This project develops an object-centric workflow for converting a real-world object into a simulation-ready 3D asset. A white ceramic mug is used as the test subject throughout.

The pipeline takes a monocular video of the object as input and produces a USD asset validated for use in NVIDIA Isaac Sim. It additionally compares two reconstruction approaches — traditional Structure-from-Motion (COLMAP) and a learned monocular depth method (DA3) — across four evaluation metrics: mesh quality, reconstruction completeness, visual fidelity, and simulation stability.

---

## Object

| Property | Value |
|---|---|
| Object | White ceramic café mug |
| Surface | Matte white with horizontal black brushstroke texture and gold CAFE logo print |
| Handle | Standard D-shape, single, fully opaque |
| Finish | Matte / low-gloss |

---

## Pipeline

The reconstruction pipeline chains the following stages in sequence:

```
Video
  └── FFmpeg          → Extracted frames (JPEG)
        └── COLMAP    → Sparse point cloud + camera poses (Path A)
        └── DA3       → transforms.json — camera intrinsics, extrinsics, per-frame poses (Path B)
              └── SAM3      → Per-frame instance masks
                    └── HoloScene → 3D scene reconstruction + USD asset export
                          └── Isaac Sim → Physics validation
```

**Path A (COLMAP)** produces a sparse point cloud and dense mesh for comparison purposes.
**Path B (DA3 → HoloScene)** produces the final simulation-ready USD asset.

---

## Tools & Versions

| Tool | Version | Role |
|---|---|---|
| FFmpeg | Latest stable | Frame extraction from video |
| COLMAP | 4.0.2 (commit d927f7e) | Sparse reconstruction, camera pose estimation |
| DA3 (Depth Anything 3) | Via Video2Sim Docker | Learned depth + camera pose estimation |
| SAM3 (Segment Anything Model 3) | Via Video2Sim Docker | Per-frame object instance masking |
| HoloScene | Via Video2Sim Docker | 3D reconstruction and USD export |
| NVIDIA Isaac Sim | 4.2.0.2 | Physics simulation and USD validation |
| MeshLab | Latest stable | Point cloud inspection and cleanup |
| Blender | 4.0 | Point cloud visualisation and camera path review |
| Python | 3.x | Supporting scripts |

---

## Repository Structure

```
Video-reconstruction/
├── README.md               ← This file
├── UPDATES.md              ← Chronological progress log
├── scripts/
│   └── colmap_pipeline.bat ← Automated FFmpeg + COLMAP batch script (Windows)
└── data/
    └── mug/
        ├── frames/         ← Extracted JPEG frames
        ├── sparse/
        │   └── 0/          ← COLMAP sparse reconstruction output
        │       ├── cameras.bin / cameras.txt
        │       ├── images.bin / images.txt
        │       ├── points3D.bin / points3D.txt
        │       ├── frames.bin
        │       ├── rigs.bin
        │       ├── project.ini
        │       └── points3D.ply  ← Exported sparse point cloud
        └── output/         ← Final USD and HoloScene outputs (pending)
```

---

## Stages

### Stage 1 — Video Capture
A monocular video of the mug is captured using a smartphone camera. Three orbital passes are performed: eye-level (primary), elevated (~30° downward), and low (~20° upward). The mug is kept stationary throughout; only the camera moves. Real-world dimensions are measured before capture for use in scale correction.

### Stage 2 — Frame Extraction (FFmpeg)
Frames are extracted from the video using FFmpeg at a configured rate (2 fps for the current run, producing ~517 frames from a ~4m 18s video). Frames are output as high-quality JPEG files for use in both COLMAP and DA3.

**Command:**
```bash
ffmpeg -i input.mp4 -vf fps=2 -qscale:v 2 frames/frame_%06d.jpg
```

### Stage 3 — Sparse Reconstruction (COLMAP — Path A)
COLMAP performs Structure-from-Motion on the extracted frames. The automated batch script (`colmap_pipeline.bat`) handles feature extraction, sequential matching, and incremental mapping in sequence.

Key parameters:
- `--ImageReader.single_camera 1` — all frames share one camera model (essential for video)
- `--FeatureExtraction.max_image_size 2048` — caps resolution for GPU memory efficiency
- `--SequentialMatching.overlap 50` — wider matching window to compensate for frame gaps
- `--Mapper.min_num_matches 10` — allows sparser frame pairs to still register
- `--Mapper.ba_use_gpu 1` — GPU-accelerated bundle adjustment

Output: `sparse/0/` containing binary and TXT model files, and `points3D.ply` (exported via `model_converter`).

**Registration result:** 517 cameras registered.

### Stage 4 — Point Cloud Cleanup (MeshLab)
The exported `points3D.ply` is opened in MeshLab. Background points (table surface, notebook, surrounding clutter) are manually removed using the selection and delete tools. The cleaned point cloud isolates the mug geometry for evaluation.

### Stage 5 — Learned Depth Reconstruction (DA3 — Path B)
DA3 (Depth Anything 3) runs on the same extracted frames via the Video2Sim Docker pipeline on the SLU Libra HPC cluster. It produces `transforms.json` containing camera intrinsics, extrinsics, and per-frame poses. This is the entry point for the HoloScene path.

*Status: pending HPC access.*

### Stage 6 — Instance Masking (SAM3)
SAM3 processes the extracted frames alongside DA3 outputs to produce per-frame instance masks of the mug. Text prompts in `prompts.txt` specify the target object. Masks isolate the mug from its background across all frames consistently.

*Status: pending HPC access.*

### Stage 7 — 3D Reconstruction and USD Export (HoloScene)
HoloScene uses the extracted frames, camera poses from DA3, and instance masks from SAM3 — along with Marigold-generated depth priors — to reconstruct the full 3D scene and export simulation-ready assets. The output is a USD file representing the mug with geometry, appearance, and estimated physical properties.

*Status: pending Stages 5–6.*

### Stage 8 — Scale Correction and Physical Parameters
The reconstruction operates in arbitrary units. Real-world measurements taken before capture are used to compute a scale factor. The mesh is corrected in Blender. Mass and inertia are estimated from mesh volume and ceramic density, then applied to the USD physics properties.

*Status: pending Stage 7.*

### Stage 9 — Isaac Sim Validation
The USD asset is imported into NVIDIA Isaac Sim 4.2. A ground plane is created and the mug is dropped from a small height. Pass criteria: the mug settles stably without sinking, exploding, or sustained oscillation. Results are documented with screenshots and notes.

*Status: pending Stage 8.*

### Stage 10 — Comparison and Documentation
The two reconstruction paths are compared across four metrics:

| Metric | Description |
|---|---|
| Mesh quality | Polygon count, watertightness, surface smoothness |
| Reconstruction completeness | Surface coverage, presence of holes |
| Visual fidelity | Textured render vs. reference photo comparison |
| Simulation stability | Isaac Sim drop test — pass/fail with notes |

---

## Comparison: COLMAP vs. DA3

| Aspect | COLMAP (Path A) | DA3 (Path B) |
|---|---|---|
| Method | Traditional Structure-from-Motion | Learned monocular depth estimation |
| Input | Multi-view video frames | Multi-view video frames |
| Output | Sparse + dense point cloud, mesh | transforms.json → USD via HoloScene |
| GPU requirement | Optional (CPU workable) | 80 GB VRAM (A100 class) |
| Simulation-ready output | No (requires conversion) | Yes (USD native) |

---

## Evaluation Metrics

Results will be populated upon completion of both reconstruction paths.

| Metric | COLMAP Result | DA3 / HoloScene Result |
|---|---|---|
| Mesh quality | TBD | TBD |
| Reconstruction completeness | TBD | TBD |
| Visual fidelity | TBD | TBD |
| Simulation stability | TBD | TBD |

---

## Hardware

| Component | Spec |
|---|---|
| Local machine (Windows) | NVIDIA Quadro M3000M, 4 GB VRAM |
| HPC cluster | SLU Libra — A100-class GPU (80 GB VRAM, for DA3) |

---

## References

```bibtex
@article{depthanything3,
  title   = {Depth Anything 3: Recovering the visual space from any views},
  author  = {Haotong Lin and Sili Chen and Jun Hao Liew and Donny Y. Chen and Zhenyu Li and Guang Shi and Jiashi Feng and Bingyi Kang},
  journal = {arXiv preprint arXiv:2511.10647},
  year    = {2025}
}

@misc{carion2025sam3,
  title  = {SAM 3: Segment Anything with Concepts},
  author = {Nicolas Carion et al.},
  year   = {2025},
  eprint = {2511.16719},
  url    = {https://arxiv.org/abs/2511.16719}
}

@misc{xia2025holoscene,
  title  = {HoloScene: Simulation-Ready Interactive 3D Worlds from a Single Video},
  author = {Hongchi Xia and Chih-Hao Lin and Hao-Yu Hsu and Quentin Leboutet and Katelyn Gao and Michael Paulitsch and Benjamin Ummenhofer and Shenlong Wang},
  year   = {2025},
  eprint = {2510.05560},
  url    = {https://arxiv.org/abs/2510.05560}
}
```
