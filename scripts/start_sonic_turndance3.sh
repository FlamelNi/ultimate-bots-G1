#!/usr/bin/env bash
set -euo pipefail

# Baseline (V1-style) fine-tune for the turndance3 motion: no phase-specific
# rewards yet, just the standard full-body tracking objective. Run this on the
# Nebius GPU VM after data/motion_lib/turndance3.pkl has been generated.
SONIC_ROOT="${SONIC_ROOT:-/srv/sonic/GR00T-WholeBodyControl}"
PROJECT_ROOT="${PROJECT_ROOT:-/srv/sonic/ultimate-bots-G1}"
PYTHON="${PYTHON:-/srv/sonic/env_isaaclab/bin/python}"
MOTION_FILE="${MOTION_FILE:-${PROJECT_ROOT}/data/motion_lib/turndance3.pkl}"
NUM_ENVS="${NUM_ENVS:-256}"
ITERATIONS="${ITERATIONS:-200}"
SAVE_INTERVAL="${SAVE_INTERVAL:-50}"
EXPERIMENT_NAME="${EXPERIMENT_NAME:-turndance3_baseline}"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/exports/turndance3/train}"

mkdir -p "${OUTPUT_DIR}"
cd "${SONIC_ROOT}"
export ACCEPT_EULA=Y OMNI_KIT_ACCEPT_EULA=YES PYTHONUNBUFFERED=1
export PYTHONPATH="${PROJECT_ROOT}${PYTHONPATH:+:${PYTHONPATH}}"

"${PYTHON}" gear_sonic/train_agent_trl.py \
  +exp=manager/universal_token/all_modes/sonic_release \
  +checkpoint=sonic_release/last.pt \
  num_envs="${NUM_ENVS}" headless=True \
  ++experiment_name="${EXPERIMENT_NAME}" \
  ++algo.config.num_learning_iterations="${ITERATIONS}" \
  ++algo.config.save_interval="${SAVE_INTERVAL}" \
  ++callbacks.model_save.save_dir="${OUTPUT_DIR}/checkpoints" \
  ++callbacks.model_save.save_frequency="${SAVE_INTERVAL}" \
  ++manager_env.commands.motion.motion_lib_cfg.motion_file="${MOTION_FILE}" \
  ++manager_env.commands.motion.motion_lib_cfg.smpl_motion_file=dummy \
  use_wandb=false \
  2>&1 | tee "${OUTPUT_DIR}/train.log"
