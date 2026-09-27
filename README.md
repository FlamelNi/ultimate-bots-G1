# Unitree G1 Turn Dance — NVIDIA SONIC

This repository contains the motion data, training scripts, and simulation
videos for **Turn Dance** (`turndance3`), a turning dance sequence for the
Unitree G1 humanoid. The current experiment fine-tunes NVIDIA SONIC from its
release checkpoint to track a G1 motion reference. It is a simulation project,
not a physical-robot deployment package.

## Watch the motion

| Run | Video |
| --- | --- |
| Untrained SONIC baseline | [Isaac Sim](exports/evaluations/turndance3_untrained/video/000000.mp4) |
| Recorded step 200 | [Isaac Sim](exports/evaluations/turndance3_step200/video/000000.mp4) |
| Recorded step 2000 | [Isaac Sim](exports/evaluations/turndance3_step2000/video/000000.mp4) |
| Cross-simulator capture | [MuJoCo](exports/turndance3/final/mujoco_video/turndance3_sim2sim.mp4) |

These are visual records, not evidence of a deployment-ready policy or a
statistically validated success rate. The released repository does not include
a Turn Dance ONNX policy or checkpoint for these recorded runs.

## Motion data and code

- [`data/source/lafan/turndance3.csv`](data/source/lafan/turndance3.csv):
  138-frame source motion at 30 FPS.
- [`data/source/sonic/turndance3/`](data/source/sonic/turndance3/):
  229-frame, 50 FPS SONIC/G1 motion bundle with joint positions and velocities,
  body position and orientation, body velocities, and metadata.
- [`scripts/start_sonic_turndance3.sh`](scripts/start_sonic_turndance3.sh):
  baseline SONIC fine-tuning from `sonic_release/last.pt`. Its defaults are
  256 environments, 200 iterations, and a checkpoint every 50 iterations.
- [`scripts/run_turndance3_sim2sim_matrix.sh`](scripts/run_turndance3_sim2sim_matrix.sh)
  and [`scripts/record_turndance3_sim2sim_video.sh`](scripts/record_turndance3_sim2sim_video.sh):
  MuJoCo cross-simulation evaluation and video capture for an exported policy.

The NVIDIA source checkout is kept separately from this repository. On the
Nebius setup used by the scripts, it lives at
`/srv/sonic/GR00T-WholeBodyControl`; this repository lives at
`/srv/sonic/ultimate-bots-G1`.

## Train

Install the NVIDIA/Isaac dependencies, then convert the committed SONIC CSV
bundle into `data/motion_lib/turndance3.pkl` using the upstream motion
converter. The generated PKL is not committed. With the upstream SONIC release
checkpoint available, run:

```bash
bash scripts/start_sonic_turndance3.sh
```

Set `SONIC_ROOT`, `PROJECT_ROOT`, `PYTHON`, `MOTION_FILE`, `NUM_ENVS`,
`ITERATIONS`, `SAVE_INTERVAL`, or `OUTPUT_DIR` to override the script defaults.
The linked step-2000 video is a recorded artifact; it is not produced by the
script's default 200-iteration run.

## Scope and safety

The repository also retains files from earlier experiments for provenance.
Those older checkpoints and reports are not Turn Dance results. The videos
above show simulation behavior only; actuator safety, robustness across
conditions, and physical G1 deployment have not been established here.
