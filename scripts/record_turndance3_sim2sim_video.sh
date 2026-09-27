#!/usr/bin/env bash
set -uo pipefail

# Record one closed-loop Isaac<->MuJoCo cross-validation run for turndance3 as
# an MP4, using the same deploy binary/tmux choreography as
# run_turndance3_sim2sim_matrix.sh but with offscreen video capture instead of
# the lightweight headless loop.
INIT_TIMEOUT="${INIT_TIMEOUT:-180}"
PROJECT="${PROJECT:-/srv/sonic/ultimate-bots-G1}"
OFFICIAL="${OFFICIAL:-/srv/sonic/GR00T-WholeBodyControl}"
OUT="${OUT:-$PROJECT/exports/turndance3/final/mujoco_video}"
MODEL_DIR="${MODEL_DIR:-$PROJECT/exports/turndance3/final/onnx}"
MODEL_STEP="${MODEL_STEP:-002000}"
REFERENCE="${REFERENCE:-reference/turndance3}"
DEPLOY="$OFFICIAL/gear_sonic_deploy/target/release/g1_deploy_onnx_ref"
ORT_LIB="${ORT_LIB:-/opt/onnxruntime/lib}"
TRT_LIB="${TRT_LIB:-}"

mkdir -p "$OUT"
release_file="$OUT/release_band"
rm -f "$release_file"
: >"$OUT/sim.log"
: >"$OUT/deploy.log"

cleanup_children() {
  tmux send-keys -t g1_deploy_vid C-c 2>/dev/null || true
  tmux send-keys -t sim_loop_vid C-c 2>/dev/null || true
  sleep 1
  tmux kill-session -t g1_deploy_vid 2>/dev/null || true
  tmux kill-session -t sim_loop_vid 2>/dev/null || true
  pkill -f '[g]1_deploy_onnx_ref.*turndance3' 2>/dev/null || true
  pkill -f '[r]un_mujoco_headless_capture.py' 2>/dev/null || true
  sleep 2
}
trap cleanup_children EXIT
cleanup_children

tmux new-session -d -s sim_loop_vid \
  "bash -lc 'cd $OFFICIAL; source .venv_sim/bin/activate; export PYTHONPATH=\$PWD; export MUJOCO_GL=egl; exec python $PROJECT/scripts/run_mujoco_headless_capture.py --output $OUT/turndance3_sim2sim.mp4 --release-after 60 --release-file $release_file --max-seconds 90 > $OUT/sim.log 2>&1'"
sleep 6
if ! tmux has-session -t sim_loop_vid 2>/dev/null; then
  echo "sim_init_failed" | tee -a "$OUT/progress.log"
  exit 1
fi

tmux new-session -d -s g1_deploy_vid \
  "bash -lc 'export LD_LIBRARY_PATH=$TRT_LIB:$ORT_LIB:\$LD_LIBRARY_PATH; cd $OFFICIAL/gear_sonic_deploy; exec $DEPLOY lo $MODEL_DIR/model_step_${MODEL_STEP}_decoder.onnx $REFERENCE --obs-config $MODEL_DIR/observation_config.yaml --encoder-file $MODEL_DIR/model_step_${MODEL_STEP}_encoder.onnx --input-type keyboard --output-type zmq --disable-crc-check > $OUT/deploy.log 2>&1'"

ready=0
for _ in $(seq 1 "$INIT_TIMEOUT"); do
  if grep -q "Init Done" "$OUT/deploy.log"; then ready=1; break; fi
  tmux has-session -t g1_deploy_vid 2>/dev/null || break
  sleep 1
done
if [[ "$ready" != 1 ]]; then
  echo "init_failed" | tee -a "$OUT/progress.log"
  exit 1
fi

tmux send-keys -t g1_deploy_vid "]"
touch "$release_file"
for _ in $(seq 1 10); do
  grep -q "AUTO_RELEASE" "$OUT/sim.log" && break
  sleep 0.1
done
sleep 3

tmux send-keys -t g1_deploy_vid "T"
completed=0
for _ in $(seq 1 30); do
  if grep -q "completed\." "$OUT/deploy.log"; then completed=1; break; fi
  tmux has-session -t g1_deploy_vid 2>/dev/null || break
  sleep 1
done
sleep 3
echo "completed=$completed" | tee -a "$OUT/progress.log"

for _ in $(seq 1 15); do
  grep -q "CAPTURE_DONE" "$OUT/sim.log" 2>/dev/null && break
  sleep 1
done

cleanup_children
ls -la "$OUT/turndance3_sim2sim.mp4" 2>&1
