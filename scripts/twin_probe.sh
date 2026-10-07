#!/usr/bin/env bash
# Automated check of the client/server twin: both TIAGo Dual arms in sync, both ways.
# Needs the ROS 1 sim running (pixi run ros1-sim). Builds the Linux client, runs it with
# -twinProbe (TwinSyncProbe.cs), moves Gazebo's arms from ROS during the EXTERNAL phase,
# and prints the PASS/FAIL line. SKIP_BUILD=1 reuses the last build.
set -euo pipefail
# This repo (GazeboRobotServer) sits next to the client checkout in StageIR:
#   StageIR/ros1 (server)   StageIR/unity/TiagoClient (GazeboRobotClient)
# TWIN_CLIENT=<path> points at the client elsewhere.
SERVER="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="${TWIN_CLIENT:-$SERVER/../unity/TiagoClient}"
LIBDIR="$(dirname "$CLIENT")/lib"
UNITY="${UNITY_EDITOR:-$HOME/Unity/Hub/Editor/6000.6.3f1/Editor/Unity}"
LOGDIR="$(mktemp -d)"
NAME="tiago_dual_noetic"

docker ps --format '{{.Names}}' | grep -qx "$NAME" || { echo "Start the sim first: ./run_sim.sh (or pixi run ros1-sim)" >&2; exit 1; }

if [ "${SKIP_BUILD:-0}" != 1 ]; then
  echo "Building the Linux client..."
  # Unity 6 on Arch looks for libdl.so, which glibc only ships as libdl.so.2.
  mkdir -p "$LIBDIR" && ln -sf /usr/lib/libdl.so.2 "$LIBDIR/libdl.so"
  LD_LIBRARY_PATH="$LIBDIR:${LD_LIBRARY_PATH:-}" "$UNITY" -batchmode -quit \
    -projectPath "$CLIENT" -executeMethod TwinClientBuild.BuildLinux -logFile "$LOGDIR/build.log" \
    || { grep -E "error CS|TwinClientBuild" "$LOGDIR/build.log" >&2; exit 1; }
fi

# Gazebo -> Unity: once the probe stops commanding, move both arms from ROS and back.
(
  until grep -q "EXTERNAL waiting" "$LOGDIR/probe.log" 2>/dev/null; do sleep 0.5; done
  docker exec "$NAME" bash -c 'source devel/setup.bash
for side in left right; do
python3 - $side <<PY &
import sys, rospy
from sensor_msgs.msg import JointState
from trajectory_msgs.msg import JointTrajectory, JointTrajectoryPoint
side = sys.argv[1]
rospy.init_node("twin_probe_mover_" + side)
names = ["arm_%s_%d_joint" % (side, i) for i in range(1, 8)]
js = rospy.wait_for_message("/joint_states", JointState)
q0 = [js.position[js.name.index(n)] for n in names]
pub = rospy.Publisher("/arm_%s_controller/command" % side, JointTrajectory, queue_size=1)
rospy.sleep(1.0)
q1 = list(q0); q1[0] += 0.35; q1[3] -= 0.4; q1[5] += 0.3
t = JointTrajectory(joint_names=names)
for k, q in enumerate([q1, q0]):
    t.points.append(JointTrajectoryPoint(positions=q, time_from_start=rospy.Duration(4.0 * (k + 1))))
pub.publish(t)
rospy.sleep(1.0)
PY
done; wait'
) &
MOVER=$!

echo "Running the probe (about 1 min 30)..."
timeout 300 "$CLIENT/Builds/Linux/TiagoClient.x86_64" -batchmode -nographics \
  -twinProbe -twinProbeQuit -logFile "$LOGDIR/probe.log" >/dev/null 2>&1 || true
kill "$MOVER" 2>/dev/null || true
wait 2>/dev/null || true

grep -E "^\[TwinSyncProbe\]" "$LOGDIR/probe.log" || true
echo "Logs: $LOGDIR"
grep -q "RESULT PASS" "$LOGDIR/probe.log"
