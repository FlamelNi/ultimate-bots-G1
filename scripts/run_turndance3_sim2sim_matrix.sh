#!/usr/bin/env bash
set -uo pipefail

# Closed-loop Isaac<->MuJoCo cross-validation for the turndance3 motion, using
# the official C++ deployment binary (TRT/ONNXRuntime) driving the official
# MuJoCo sim loop. Modeled on run_v8_sim2sim_matrix.sh.
RUNS="${RUNS:-10}"
INIT_TIMEOUT="${INIT_TIMEOUT:-180}"
PROJECT="${PROJECT:-/srv/sonic/ultimate-bots-G1}"
OFFICIAL="${OFFICIAL:-/srv/sonic/GR00T-WholeBodyControl}"
OUT="${OUT:-$PROJECT/exports/turndance3/final/mujoco_matrix}"
MODEL_DIR="${MODEL_DIR:-$PROJECT/exports/turndance3/final/onnx}"
MODEL_STEP="${MODEL_STEP:-002000}"
REFERENCE="${REFERENCE:-reference/turndance3}"
DEPLOY="$OFFICIAL/gear_sonic_deploy/target/release/g1_deploy_onnx_ref"
ORT_LIB="${ORT_LIB:-/opt/onnxruntime/lib}"
TRT_LIB="${TRT_LIB:-}"
PYTHON="${PYTHON:-$OFFICIAL/.venv_sim/bin/python}"
REFERENCE_ROOT="$OFFICIAL/gear_sonic_deploy/$REFERENCE"
REFERENCE_MOTION="$REFERENCE_ROOT/turndance3_sonic"
SOURCE_MOTION="$PROJECT/data/source/sonic/turndance3"

mkdir -p "$OUT"
if [[ ! -f "$REFERENCE_MOTION/joint_pos.csv" ]]; then
  mkdir -p "$REFERENCE_MOTION"
  cp -a "$SOURCE_MOTION/." "$REFERENCE_MOTION/"
fi
if [[ ! -f "$REFERENCE_MOTION/joint_pos.csv" ]]; then
  echo "Missing deploy reference motion: $REFERENCE_MOTION" >&2
  exit 2
fi

cleanup_children() {
  tmux send-keys -t g1_deploy C-c 2>/dev/null || true
  tmux send-keys -t sim_loop C-c 2>/dev/null || true
  sleep 1
  tmux kill-session -t g1_deploy 2>/dev/null || true
  tmux kill-session -t sim_loop 2>/dev/null || true
  pkill -f '[g]1_deploy_onnx_ref.*turndance3' 2>/dev/null || true
  pkill -f '[r]un_mujoco_headless_release.py' 2>/dev/null || true
  sleep 2
}
trap cleanup_children EXIT

for run in $(seq -w 1 "$RUNS"); do
  run_dir="$OUT/run_$run"
  mkdir -p "$run_dir/logs"
  : >"$run_dir/sim.log"
  : >"$run_dir/deploy.log"
  release_file="$run_dir/release_band"
  rm -f "$release_file"
  cleanup_children

  tmux new-session -d -s sim_loop \
    "bash -lc 'cd $OFFICIAL; source .venv_sim/bin/activate; export PYTHONPATH=\$PWD; exec python $PROJECT/scripts/run_mujoco_headless_release.py --release-after 60 --release-file $release_file > $run_dir/sim.log 2>&1'"
  sleep 6
  if ! tmux has-session -t sim_loop 2>/dev/null; then
    echo "run_$run sim_init_failed" | tee -a "$OUT/progress.log"
    cleanup_children
    continue
  fi
  tmux new-session -d -s g1_deploy \
    "bash -lc 'export LD_LIBRARY_PATH=$TRT_LIB:$ORT_LIB:\$LD_LIBRARY_PATH; cd $OFFICIAL/gear_sonic_deploy; exec $DEPLOY lo $MODEL_DIR/model_step_${MODEL_STEP}_decoder.onnx $REFERENCE --obs-config $MODEL_DIR/observation_config.yaml --encoder-file $MODEL_DIR/model_step_${MODEL_STEP}_encoder.onnx --input-type keyboard --output-type zmq --disable-crc-check --enable-csv-logs --logs-dir $run_dir/logs > $run_dir/deploy.log 2>&1'"

  ready=0
  for _ in $(seq 1 "$INIT_TIMEOUT"); do
    if grep -q "Init Done" "$run_dir/deploy.log"; then ready=1; break; fi
    tmux has-session -t g1_deploy 2>/dev/null || break
    sleep 1
  done
  if [[ "$ready" != 1 ]]; then
    echo "run_$run init_failed" | tee -a "$OUT/progress.log"
    cleanup_children
    continue
  fi

  tmux send-keys -t g1_deploy "]"
  touch "$release_file"
  for _ in $(seq 1 10); do
    grep -q "AUTO_RELEASE" "$run_dir/sim.log" && break
    sleep 0.1
  done
  if ! "$PYTHON" "$PROJECT/scripts/wait_for_sim2sim_settle.py" "$run_dir/logs" \
      --timeout 25 --consecutive 25 --min-upright 0.95 \
      --max-joint-speed 2.5 --max-base-angular-speed 0.6 \
      --output "$run_dir/initial_settle.json"; then
    echo "run_$run initial_settle_failed" | tee -a "$OUT/progress.log"
    cleanup_children
    continue
  fi

  tmux send-keys -t g1_deploy "T"
  completed=0
  for _ in $(seq 1 30); do
    if grep -q "completed\." "$run_dir/deploy.log"; then completed=1; break; fi
    tmux has-session -t g1_deploy 2>/dev/null || break
    sleep 1
  done
  sleep 2
  "$PYTHON" "$PROJECT/scripts/summarize_turndance3_sim2sim_matrix.py" "$OUT" >/dev/null 2>&1 || true
  echo "run_$run completed=$completed" | tee -a "$OUT/progress.log"
done

cleanup_children
"$PYTHON" "$PROJECT/scripts/summarize_turndance3_sim2sim_matrix.py" "$OUT"
