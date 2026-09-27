# Turn Dance motion data

`source/lafan/turndance3.csv` contains the 138-frame, 30 FPS source motion.
`source/sonic/turndance3/` is the corresponding 229-frame, 50 FPS G1/SONIC
motion bundle. It contains joint positions and velocities, body position and
orientation, linear and angular velocities, and source metadata.

The training script expects a generated
`data/motion_lib/turndance3.pkl`. Convert the committed SONIC CSV bundle with
the upstream NVIDIA motion converter before training. Generated PKL files are
not committed here.

Other source-motion directories in this repository belong to archived prior
experiments; they are not inputs to the current Turn Dance training script.
