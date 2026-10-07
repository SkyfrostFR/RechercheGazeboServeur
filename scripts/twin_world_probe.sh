#!/usr/bin/env bash
# Automated check of the Gazebo world features of the client: test objects drawn, base
# driven from the (scripted) sticks with the twin following it, and cylinder_red grasped
# and lifted by the left arm (TwinWorldProbe.cs, -twinWorldProbe).
# Needs a FRESH sim (pixi run ros1-sim; objects untouched, robot at the origin).
# SKIP_BUILD=1 reuses the last build; SHOTS=<dir> saves side/top views at each phase.
set -euo pipefail
# This repo (GazeboRobotServer) sits next to the client checkout in StageIR:
#   StageIR/ros1 (server)   StageIR/unity/TiagoClient (GazeboRobotClient)
# TWIN_CLIENT=<path> points at the client elsewhere.
SERVER="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="${TWIN_CLIENT:-$SERVER/../unity/TiagoClient}"
LIBDIR="$(dirname "$CLIENT")/lib"
UNITY="${UNITY_EDITOR:-$HOME/Unity/Hub/Editor/6000.6.3f1/Editor/Unity}"
LOGDIR="$(mktemp -d)"

docker ps --format '{{.Names}}' | grep -qx tiago_dual_noetic || { echo "Start the sim first: ./run_sim.sh (or pixi run ros1-sim)" >&2; exit 1; }

if [ "${SKIP_BUILD:-0}" != 1 ]; then
  echo "Building the Linux client..."
  # Unity 6 on Arch looks for libdl.so, which glibc only ships as libdl.so.2.
  mkdir -p "$LIBDIR" && ln -sf /usr/lib/libdl.so.2 "$LIBDIR/libdl.so"
  LD_LIBRARY_PATH="$LIBDIR:${LD_LIBRARY_PATH:-}" "$UNITY" -batchmode -quit \
    -projectPath "$CLIENT" -executeMethod TwinClientBuild.BuildLinux -logFile "$LOGDIR/build.log" \
    || { grep -E "error CS|TwinClientBuild" "$LOGDIR/build.log" >&2; exit 1; }
fi

ARGS=(-batchmode -twinWorldProbe -twinProbeQuit -logFile "$LOGDIR/probe.log")
[ -n "${SHOTS:-}" ] && ARGS+=(-twinProbeShots "$SHOTS")
echo "Running the probe (about 1 min 30)..."
timeout 300 "$CLIENT/Builds/Linux/TiagoClient.x86_64" "${ARGS[@]}" >/dev/null 2>&1 || true

grep -E "^\[TwinWorldProbe\] (phase|RESULT)" "$LOGDIR/probe.log" || true
echo "Logs: $LOGDIR"
grep -q "RESULT PASS" "$LOGDIR/probe.log"
