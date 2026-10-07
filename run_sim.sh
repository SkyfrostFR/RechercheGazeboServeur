#!/usr/bin/env bash
# TIAGo Dual public simulation (ROS 1 Noetic, Gazebo Classic) + rosbridge, in
# Docker. Host networking: roscore on localhost:11311 and rosbridge on
# ws://localhost:9090, which is what the Unity project (ROS#) connects to.
#   WORLD=empty|small_office|...   Gazebo world (pal_gazebo_worlds)
#   GUI=false                      no Gazebo window
set -euo pipefail

IMAGE="stageir/tiago-dual-noetic:latest"
NAME="tiago_dual_noetic"
WORLD="${WORLD:-empty}"
GUI="${GUI:-true}"

if docker ps --format '{{.Names}}' | grep -qx "${NAME}"; then
  echo "The simulation is already running (docker stop ${NAME} to stop it)." >&2
  exit 1
fi
for port in 9090 11311; do
  if ss -ltn | grep -q ":${port} "; then
    echo "Port ${port} already in use (ss -ltnp | grep ${port}): stop the other stack first." >&2
    exit 1
  fi
done

# No NVIDIA container runtime here: Gazebo renders in software (Mesa llvmpipe).
# ROS nodes advertise themselves as localhost: they only talk to each other on
# this machine (rosbridge, on 0.0.0.0:9090, is the only service exposed to the
# network). Using the host name made them unreachable as soon as it stopped
# resolving (DNS/VPN change), e.g. switch_controller failing for Unity.
# Run as the host user: XWayland refuses root clients ("Authorization required"),
# and gzserver needs the display even with GUI=false to render the camera/laser.
exec docker run --rm -it --name "${NAME}" \
  --user "$(id -u):$(id -g)" -e HOME=/tmp \
  --net=host --ipc=host \
  -e ROS_HOSTNAME=localhost -e ROS_MASTER_URI=http://localhost:11311 \
  -e DISPLAY="${DISPLAY:-:0}" -e QT_X11_NO_MITSHM=1 -e LIBGL_ALWAYS_SOFTWARE=1 \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v "$(dirname "$(realpath "$0")")/stageir_sim:/stageir_pkgs/stageir_sim:ro" \
  "${IMAGE}" -c "source devel/setup.bash && \
    export ROS_PACKAGE_PATH=/stageir_pkgs:\$ROS_PACKAGE_PATH && \
    roslaunch stageir_sim sim.launch world:=${WORLD} gui:=${GUI}"
